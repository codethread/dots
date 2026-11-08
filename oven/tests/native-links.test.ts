import {afterAll, beforeAll, expect, test} from "bun:test";
import {lstat, mkdtemp, readdir, readlink, rm} from "node:fs/promises";
import {tmpdir} from "node:os";
import {delimiter, dirname, join} from "node:path";

const commandNames = [
	"bra",
	"cc-hook--context-injector",
	"cc-hook--npm-redirect",
	"cc-statusline",
	"cindex",
	"ghub",
	"git-cleanup",
	"git-pipeline--await",
	"gitlab-pipeline-watcher",
	"mise-dot-diff",
	"notif",
	"prepend-comment",
	"strip-markdown",
	"theme",
	"tts",
];
const ovenDir = join(import.meta.dir, "..");
const repositoryRoot = join(ovenDir, "..");
const binDir = join(ovenDir, "bin");
const temporaryHome = await mkdtemp(join(tmpdir(), "oven-native-links-"));
const linksDirectory = join(temporaryHome, ".local", "bin");
const xdgConfigHome = join(temporaryHome, ".config");
const xdgDataHome = join(temporaryHome, ".local", "share");
const xdgCacheHome = join(temporaryHome, ".cache");
const xdgStateHome = join(temporaryHome, ".local", "state");
const gitCommonDirectory = Bun.spawnSync(
	["git", "-C", repositoryRoot, "rev-parse", "--path-format=absolute", "--git-common-dir"],
	{stdout: "pipe", stderr: "pipe"},
);
if (gitCommonDirectory.exitCode !== 0) {
	throw new Error(`Failed to locate the shared Git directory: ${gitCommonDirectory.stderr}`);
}
const durableRepositoryRoot = dirname(gitCommonDirectory.stdout.toString().trim());

const miseEnvironment = {
	...process.env,
	HOME: temporaryHome,
	XDG_CACHE_HOME: xdgCacheHome,
	XDG_CONFIG_HOME: xdgConfigHome,
	XDG_DATA_HOME: xdgDataHome,
	XDG_STATE_HOME: xdgStateHome,
	MISE_CACHE_DIR: join(xdgCacheHome, "mise"),
	MISE_CONFIG_DIR: join(xdgConfigHome, "mise"),
	MISE_DATA_DIR: join(xdgDataHome, "mise"),
	MISE_STATE_DIR: join(xdgStateHome, "mise"),
	MISE_TRUSTED_CONFIG_PATHS: [repositoryRoot, durableRepositoryRoot].join(delimiter),
};

let apply: ReturnType<typeof Bun.spawnSync>;

beforeAll(() => {
	const targets = commandNames.map((commandName) => join(linksDirectory, commandName));
	apply = Bun.spawnSync(["mise", "dot", "apply", ...targets], {
		cwd: repositoryRoot,
		env: miseEnvironment,
		stdout: "pipe",
		stderr: "pipe",
	});
});

afterAll(async () => {
	await rm(temporaryHome, {recursive: true, force: true});
});

test("all public commands are executable Bun entrypoints", async () => {
	const entrypoints = (await readdir(binDir))
		.filter((name) => name.endsWith(".ts"))
		.map((name) => name.slice(0, -3))
		.toSorted();
	expect(entrypoints).toEqual(commandNames);
});

test("mise deploys every extensionless command link into an isolated home", async () => {
	expect(apply.exitCode, apply.stderr?.toString() ?? "").toBe(0);

	for (const commandName of commandNames) {
		const link = join(linksDirectory, commandName);
		expect((await lstat(link)).isSymbolicLink(), commandName).toBe(true);
		expect(await readlink(link), commandName).toBe(join(binDir, `${commandName}.ts`));
	}
});

test("deployed commands load dependencies and satisfy successful CLI contracts", async () => {
	for (const commandName of commandNames) {
		const help = Bun.spawnSync([join(linksDirectory, commandName), "--help"], {
			cwd: temporaryHome,
			env: miseEnvironment,
			stdout: "pipe",
			stderr: "pipe",
		});
		const output = `${help.stdout?.toString() ?? ""}${help.stderr?.toString() ?? ""}`;
		expect(help.exitCode, `${commandName}: ${output}`).toBe(0);
		expect(output, commandName).toContain(commandName);
	}

	const stripMarkdown = Bun.spawnSync([join(linksDirectory, "strip-markdown"), "--format", "plain"], {
		cwd: temporaryHome,
		env: miseEnvironment,
		stdin: Buffer.from("Hello **linked dependencies**.\n"),
		stdout: "pipe",
		stderr: "pipe",
	});
	expect(stripMarkdown.exitCode, stripMarkdown.stderr?.toString() ?? "").toBe(0);
	expect(stripMarkdown.stdout?.toString()).toBe("Hello linked dependencies.\n");
});
