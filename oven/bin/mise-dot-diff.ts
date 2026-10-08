// :module: Preview mise dotfiles and pull JSON template edits into local overlays

import {mkdtemp, rm} from "node:fs/promises";
import {homedir, tmpdir} from "node:os";
import {join, resolve} from "node:path";
import {isDeepStrictEqual, parseArgs} from "node:util";
import {$} from "bun";
import {report, reportError} from "../shared/report";

const HELP = `mise-dot-diff - Preview mise dotfiles and pull JSON template edits into local overlays

Usage: mise-dot-diff [--pull [--write] [--into FILE]] [TARGET ...]

TARGET is a destination, destination/edit-id, or configured source path.
Without TARGET, preview all drifting whole-file and edit entries.
Merge entries use mise's native diff: unrelated live keys are preserved.
--pull   Preview live JSON template changes merged into a local overlay.
--write  Save that overlay (requires --pull).
--into   Choose the overlay file (Claude's template has a default).
-h, --help  Show help.
`;

interface Entry {
	target: string;
	selector: string;
	source: string | null;
	mode: string;
	state: string;
	edit: boolean;
}
interface Options {
	targets: string[];
	pull?: boolean;
	write?: boolean;
	into?: string;
	help?: boolean;
}
interface CommandResult {
	exitCode: number;
	stdout: string;
	stderr: string;
}
export interface DiffRuntime {
	root: string;
	home: string;
	run(args: string[]): Promise<CommandResult>;
}

async function main() {
	const {values, positionals} = parseArgs({
		args: Bun.argv.slice(2),
		allowPositionals: true,
		options: {
			pull: {type: "boolean"},
			write: {type: "boolean"},
			into: {type: "string"},
			help: {type: "boolean", short: "h"},
		},
	});
	const root = resolve(import.meta.dir, "../..");
	const result = await miseDotDiffLib(
		{targets: positionals, ...values},
		{
			root,
			home: homedir(),
			async run(args) {
				const result = await $`${args}`
					.cwd(root)
					.env({...process.env, NO_COLOR: "1"})
					.quiet()
					.nothrow();
				return {exitCode: result.exitCode, stdout: result.text(), stderr: result.stderr.toString()};
			},
		},
	);
	report(result.output);
	process.exitCode = result.failed ? 1 : 0;
}

export async function miseDotDiffLib(options: Options, runtime: DiffRuntime) {
	if (options.help) return {output: HELP, failed: false};
	if (!options.pull && (options.write || options.into !== undefined)) {
		throw new Error("--write and --into require --pull");
	}
	const status = await command(runtime, ["mise", "dot", "status", "-J"]);
	const entries = selectEntries(parseStatus(status.stdout), options.targets, runtime);
	if (options.pull && entries.length !== 1) throw new Error("--pull handles one target at a time");
	if (!entries.length)
		return {output: "All configured dotfiles are applied; nothing to change.", failed: false};

	const output: string[] = [];
	const changed: string[] = [];
	let failed = false;
	for (const entry of entries) {
		output.push(`\n== ${entry.target} (${entry.mode})`, `   source: ${entry.source ?? "inline"}`);
		try {
			if (options.pull && (entry.edit || entry.mode !== "template")) {
				throw new Error(
					"--pull supports whole-file JSON templates only; merge entries already preserve unrelated live keys. Edit their source to retain changes to managed keys.",
				);
			}
			if (entry.state === "source_missing") throw new Error(`source missing: ${entry.source}`);
			const diff = await command(runtime, ["mise", "dot", "diff", entry.selector]);
			const patchStart = diff.stdout.search(/^--- /m);
			if (entry.edit || patchStart < 0) {
				output.push(diff.stdout.trimEnd() || "   already applied; nothing to change");
				if (diff.stdout.trim()) changed.push(entry.selector);
				continue;
			}
			const preview = await previewFile({entry, patch: diff.stdout.slice(patchStart), options}, runtime);
			output.push(preview.output);
			if (preview.changed) changed.push(entry.selector);
		} catch (error) {
			failed = true;
			output.push(`   ERROR: ${error instanceof Error ? error.message : String(error)}`);
		}
	}
	if (changed.length) {
		output.push(
			"\nApply (not run; review first):",
			...changed.map((target) => `  mise dot apply ${quotePath(target, runtime)}`),
		);
	}
	return {output: output.join("\n"), failed};
}

export function parseStatus(text: string): Entry[] {
	const status = object(JSON.parse(text), "mise status");
	if (!Array.isArray(status.files) || !Array.isArray(status.edits)) {
		throw new Error("mise status must contain files and edits arrays");
	}
	return [
		...status.files.map((value) => {
			const file = object(value, "file entry");
			const target = string(file.target, "target");
			return {
				target,
				selector: target,
				source: nullableString(file.source),
				mode: string(file.mode, "mode"),
				state: string(file.state, "state"),
				edit: false,
			};
		}),
		...status.edits.map((value) => {
			const edit = object(value, "edit entry");
			const target = string(edit.path, "path");
			const label = string(edit.edit, "edit");
			const match = /^(merge|block|line):(.+)$/.exec(label);
			if (!match) throw new Error(`Unrecognized mise edit: ${label}`);
			return {
				target,
				selector: `${target}/${match[2]}`,
				source: nullableString(object(edit.origin, "edit origin").source),
				mode: label,
				state: string(edit.state, "state"),
				edit: true,
			};
		}),
	];
}

export function selectEntries(
	entries: Entry[],
	targets: string[],
	runtime: Pick<DiffRuntime, "root" | "home">,
): Entry[] {
	if (!targets.length) return entries.filter((entry) => !["applied", "tracked"].includes(entry.state));
	const selected = new Map<string, Entry>();
	for (const target of targets) {
		const wanted = expandPath(target, runtime);
		const matches = entries.filter((entry) =>
			[entry.target, entry.selector, entry.source].some(
				(path) => path !== null && expandPath(path, runtime) === wanted,
			),
		);
		if (!matches.length) throw new Error(`No [dotfiles] entry matches '${target}' (try: mise dot status)`);
		for (const entry of matches) selected.set(entry.selector, entry);
	}
	return [...selected.values()];
}

async function previewFile(
	{entry, patch, options}: {entry: Entry; patch: string; options: Options},
	runtime: DiffRuntime,
) {
	const file = Bun.file(expandPath(entry.target, runtime));
	const exists = await file.exists();
	const current = exists ? await file.text() : "";
	const dir = await mkdtemp(join(tmpdir(), "mise-dot-diff-"));
	try {
		const before = join(dir, "current");
		const after = join(dir, "desired");
		const patchFile = join(dir, "diff");
		await Bun.write(before, current);
		await Bun.write(patchFile, patch);
		await command(runtime, ["patch", "--batch", "-s", "-o", after, before, patchFile]);
		const desired = await Bun.file(after).text();
		if (options.pull) {
			if (!exists) throw new Error(`--pull requires the live target to exist (${entry.target})`);
			return await pullOverlay({entry, current, desired, options}, runtime);
		}
		const normalizedCurrent = normalizeJson(current);
		const normalizedDesired = normalizeJson(desired);
		if (normalizedCurrent === normalizedDesired)
			return {output: "   no change after normalization", changed: false};
		await Bun.write(before, normalizedCurrent);
		await Bun.write(after, normalizedDesired);
		const diff = await command(
			runtime,
			[
				"diff",
				"-u",
				"--label",
				exists ? "current" : "current (missing)",
				"--label",
				"desired",
				before,
				after,
			],
			[0, 1],
		);
		return {output: diff.stdout.trimEnd(), changed: true};
	} finally {
		await rm(dir, {recursive: true, force: true});
	}
}

async function pullOverlay(
	{entry, current, desired, options}: {entry: Entry; current: string; desired: string; options: Options},
	runtime: DiffRuntime,
) {
	const live = object(JSON.parse(current), "--pull live JSON");
	const rendered = object(JSON.parse(desired), "--pull desired JSON");
	const destination =
		options.into ??
		(entry.source?.endsWith("/templates/claude-settings.json.tera")
			? "~/.config/claude/settings-overlay.json"
			: undefined);
	if (!destination) throw new Error("--pull needs --into <overlay-file> for this template");
	const path = expandPath(destination, runtime);
	const {patch, missing} = overlayChanges(live, rendered);
	const output: string[] = [];
	const changed = Object.keys(patch).length > 0;
	if (changed) {
		output.push("   live-only changes:", canonical(patch));
		const file = Bun.file(path);
		const existing = (await file.exists()) ? object(await file.json(), "overlay JSON") : {};
		const overlay = canonical(mergeObjects(existing, patch));
		if (options.write) {
			await Bun.write(path, overlay);
			output.push(`   wrote overlay: ${path}`);
		} else output.push(`   overlay would become (${path}):`, overlay);
	} else output.push("   no live-only changes to pull");
	if (missing.length)
		output.push(
			"   template-owned keys absent from live (apply restores them; edit the template to remove them):",
			...missing.map((key) => `   - ${key}`),
		);
	return {output: output.join("\n"), changed: changed || missing.length > 0};
}

// Pull is explicit and one-way; arrays are values, not identity-keyed records.
export function overlayChanges(live: Record<string, unknown>, desired: Record<string, unknown>) {
	const changes: [string, unknown][] = [];
	const missing = Object.keys(desired).filter((key) => !Object.hasOwn(live, key));
	for (const [key, value] of Object.entries(live)) {
		if (isObject(value) && isObject(desired[key])) {
			const nested = overlayChanges(value, desired[key]);
			if (Object.keys(nested.patch).length) changes.push([key, nested.patch]);
			missing.push(...nested.missing.map((path) => `${key}.${path}`));
		} else if (!Object.hasOwn(desired, key) || !isDeepStrictEqual(value, desired[key]))
			changes.push([key, value]);
	}
	return {patch: Object.fromEntries(changes), missing};
}

export function mergeObjects(
	base: Record<string, unknown>,
	patch: Record<string, unknown>,
): Record<string, unknown> {
	return Object.fromEntries(
		[...new Set([...Object.keys(base), ...Object.keys(patch)])].map((key) => {
			if (!Object.hasOwn(patch, key)) return [key, base[key]];
			return [
				key,
				isObject(base[key]) && isObject(patch[key]) ? mergeObjects(base[key], patch[key]) : patch[key],
			];
		}),
	);
}

export function normalizeJson(text: string) {
	try {
		return canonical(JSON.parse(text));
	} catch {
		return text;
	}
}
function canonical(value: unknown) {
	return `${JSON.stringify(value, (_key, item) => (isObject(item) ? Object.fromEntries(Object.entries(item).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))) : item), 2)}\n`;
}
function isObject(value: unknown): value is Record<string, unknown> {
	return value !== null && typeof value === "object" && !Array.isArray(value);
}
function object(value: unknown, label: string) {
	if (!isObject(value)) throw new Error(`${label} must be a JSON object`);
	return value;
}
function string(value: unknown, label: string) {
	if (typeof value !== "string") throw new Error(`mise status ${label} must be a string`);
	return value;
}
function nullableString(value: unknown) {
	return value == null ? null : string(value, "source");
}
function expandPath(path: string, runtime: Pick<DiffRuntime, "root" | "home">) {
	return path.startsWith("~/") ? join(runtime.home, path.slice(2)) : resolve(runtime.root, path);
}
function quotePath(path: string, runtime: DiffRuntime) {
	// JSON quoting is valid for these paths in Nushell; expand ~ before quoting.
	return JSON.stringify(expandPath(path, runtime));
}
async function command(runtime: DiffRuntime, args: string[], allowed = [0]) {
	const result = await runtime.run(args);
	if (!allowed.includes(result.exitCode))
		throw new Error(
			`${args[0]} failed (${result.exitCode}): ${result.stderr.trim() || result.stdout.trim()}`,
		);
	return result;
}

if (import.meta.main) {
	main().catch((error) => {
		reportError(error);
		process.exitCode = 1;
	});
}
