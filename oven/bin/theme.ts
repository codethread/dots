// :module: Switch macOS and terminal color theme

import {mkdir} from "node:fs/promises";
import {homedir} from "node:os";
import {dirname, join} from "node:path";
import {parseArgs} from "node:util";
import {report, reportError} from "../shared/report";

const HELP = `theme - Switch macOS and terminal color theme

Usage: theme [--family tokyonight|rose-pine] [light|dark|toggle]
       theme                         # show current theme
       theme --family rose-pine      # switch family, keep current mode

Options:
  --family <family>  Select tokyonight or rose-pine
  --help, -h         Show this help`;

type Mode = "light" | "dark";
type Family = "tokyonight" | "rose-pine";
interface ThemeOptions {
	mode?: Mode | "toggle";
	family?: Family;
	help?: boolean;
}

interface CommandResult {
	exitCode: number;
	stdout: string;
	stderr: string;
}

type RunCommand = (args: string[], stdin?: string) => Promise<CommandResult>;

export interface ThemeRuntime {
	platform: string;
	stateDir: string;
	configDir: string;
	backgroundsDir: string;
	run: RunCommand;
}

const THEMES = {
	tokyonight: {
		light: {kitty: "tokyonight-day", ghostty: "TokyoNight Day"},
		dark: {kitty: "tokyonight-moon", ghostty: "TokyoNight Moon"},
	},
	"rose-pine": {
		light: {kitty: "rose-pine-dawn", ghostty: "Rose Pine Dawn"},
		dark: {kitty: "rose-pine", ghostty: "Rose Pine Moon"},
	},
};

const WALLPAPER_SCRIPT = `on run argv
  set wallpaperPath to item 1 of argv
  tell application "System Events"
    repeat with currentDesktop in desktops
      set picture of currentDesktop to wallpaperPath
    end repeat
  end tell
end run`;

async function main() {
	try {
		const options = parseThemeArgs(Bun.argv.slice(2));
		report(await themeLib(options));
	} catch (error) {
		reportError(error);
		process.exitCode = 1;
	}
}

export function parseThemeArgs(args: string[]): ThemeOptions {
	const {values, positionals} = parseArgs({
		args,
		options: {family: {type: "string"}, help: {type: "boolean", short: "h"}},
		allowPositionals: true,
	});
	if (values.help) return {help: true};
	if (positionals.length > 1) throw new Error("Only one mode may be provided");
	const mode = positionals[0];
	if (mode !== undefined && mode !== "light" && mode !== "dark" && mode !== "toggle") {
		throw new Error(`Unsupported theme mode: ${mode}`);
	}
	const family = values.family;
	if (family !== undefined && family !== "tokyonight" && family !== "rose-pine") {
		throw new Error(`Unsupported theme family: ${family}`);
	}
	return {mode, family};
}

export async function themeLib(options: ThemeOptions, runtime = defaultRuntime()): Promise<string> {
	if (options.help) return HELP;
	const [family, current] = await Promise.all([
		options.family ?? currentFamily(runtime),
		options.mode === "light" || options.mode === "dark" ? options.mode : currentMode(runtime),
	]);
	if (!options.mode && !options.family) return `Current: ${family} ${current}\n${HELP}`;
	const mode = options.mode === "toggle" ? (current === "dark" ? "light" : "dark") : current;
	const theme = THEMES[family][mode];
	const kittySource = join(runtime.configDir, "kitty", "themes", `${theme.kitty}.conf`);
	// Preflight all required assets before changing anything. Read the Kitty source once.
	const [kittyConfig, wallpaper] = await Promise.all([
		Bun.file(kittySource)
			.text()
			.catch((error) => {
				throw new Error(`Cannot read kitty theme: ${kittySource}: ${error}`);
			}),
		runtime.platform === "darwin" ? findWallpaper(runtime.backgroundsDir, theme.kitty) : undefined,
	]);

	// Each branch starts immediately; only a terminal's own config write gates its reload.
	// Drain every branch on failure too, so no work outlives the reported result.
	const jobs = [
		writeConfig(join(runtime.stateDir, "color-theme"), `${mode}\n`),
		writeConfig(join(runtime.stateDir, "color-theme-family"), `${family}\n`),
		updateKitty(runtime, kittyConfig),
		updateGhostty(runtime, theme.ghostty),
	];
	if (wallpaper !== undefined) {
		jobs.push(
			runRequired(runtime, [
				"osascript",
				"-e",
				`tell app "System Events" to tell appearance preferences to set dark mode to ${mode === "dark"}`,
			]),
			runRequired(runtime, ["osascript", "-", wallpaper], WALLPAPER_SCRIPT),
		);
	}
	const results = await Promise.allSettled(jobs);
	const errors = results.flatMap((result) => (result.status === "rejected" ? [result.reason] : []));
	if (errors.length) {
		throw new AggregateError(errors, `Theme switch failed: ${errors.map(String).join("; ")}`);
	}
	return `Theme: ${family} ${mode}`;
}

function defaultRuntime(): ThemeRuntime {
	const home = homedir();
	return {
		platform: process.platform,
		stateDir: process.env.XDG_STATE_HOME || join(home, ".local", "state"),
		configDir: process.env.XDG_CONFIG_HOME || join(home, ".config"),
		backgroundsDir: process.env.CT_BACKGROUNDS_DIR || join(home, "sync", "images", "backgrounds"),
		run: runCommand,
	};
}

async function currentFamily(runtime: ThemeRuntime): Promise<Family> {
	const family = await readState(join(runtime.stateDir, "color-theme-family"));
	return family === "rose-pine" ? family : "tokyonight";
}

async function currentMode(runtime: ThemeRuntime): Promise<Mode> {
	const [system, state] = await Promise.all([
		runtime.platform === "darwin"
			? runtime.run([
					"osascript",
					"-e",
					'tell app "System Events" to tell appearance preferences to get dark mode',
				])
			: undefined,
		readState(join(runtime.stateDir, "color-theme")),
	]);
	if (system?.exitCode === 0) {
		if (system.stdout.trim() === "true") return "dark";
		if (system.stdout.trim() === "false") return "light";
	}
	return state === "light" ? "light" : "dark";
}

async function readState(path: string): Promise<string> {
	// Missing, unreadable or invalid state falls back to the documented defaults.
	return Bun.file(path)
		.text()
		.then((text) => text.replace(/\s/g, ""))
		.catch(() => "");
}

async function findWallpaper(directory: string, name: string): Promise<string> {
	const candidates = [`${name}.jpg`, `${name}.png`, "default.jpg", "default.png"].map((file) =>
		join(directory, file),
	);
	const exists = await Promise.all(candidates.map((file) => Bun.file(file).exists()));
	const wallpaper = candidates.find((_, index) => exists[index]);
	if (!wallpaper) throw new Error(`Missing wallpaper for: ${name} in ${directory}`);
	return wallpaper;
}

async function writeConfig(path: string, content: string): Promise<void> {
	await mkdir(dirname(path), {recursive: true});
	await Bun.write(path, content);
}

async function updateKitty(runtime: ThemeRuntime, config: string): Promise<void> {
	await writeConfig(join(runtime.configDir, "kitty", "themes", "active.conf"), config);
	const result = await runtime.run(["kitty", "@", "--to", "unix:/tmp/mykitty", "load-config"]);
	if (result.exitCode !== 0 && result.exitCode !== 127) {
		await runtime.run(["kitty", "@", "load-config"]);
	}
}

async function updateGhostty(runtime: ThemeRuntime, theme: string): Promise<void> {
	await writeConfig(join(runtime.configDir, "ghostty", "active-theme.conf"), `theme = ${theme}\n`);
	await runtime.run(["pkill", "-USR2", "-x", "ghostty"]);
}

async function runRequired(runtime: ThemeRuntime, args: string[], stdin?: string): Promise<void> {
	const result = await runtime.run(args, stdin);
	if (result.exitCode !== 0) {
		throw new Error(`${args.join(" ")} exited ${result.exitCode}: ${result.stderr.trim()}`);
	}
}

async function runCommand(args: string[], stdin?: string): Promise<CommandResult> {
	const executable = Bun.which(args[0]);
	if (!executable) return {exitCode: 127, stdout: "", stderr: `${args[0]} not found`};
	const child = Bun.spawn([executable, ...args.slice(1)], {
		stdin: stdin === undefined ? "ignore" : new Blob([stdin]),
		stdout: "pipe",
		stderr: "pipe",
	});
	const [exitCode, stdout, stderr] = await Promise.all([
		child.exited,
		new Response(child.stdout).text(),
		new Response(child.stderr).text(),
	]);
	return {exitCode, stdout, stderr};
}

if (import.meta.main) {
	void main();
}
