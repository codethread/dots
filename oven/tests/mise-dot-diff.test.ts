import {afterEach, describe, expect, test} from "bun:test";
import {mkdtemp, rm} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join} from "node:path";
import {$} from "bun";
import {
	type DiffRuntime,
	mergeObjects,
	miseDotDiffLib,
	normalizeJson,
	overlayChanges,
	parseStatus,
	selectEntries,
} from "../bin/mise-dot-diff";

const cleanup: string[] = [];
const ok = {exitCode: 0, stdout: "", stderr: ""};

afterEach(async () => {
	await Promise.all(cleanup.splice(0).map((dir) => rm(dir, {recursive: true, force: true})));
});

async function runtime(): Promise<DiffRuntime> {
	const root = await mkdtemp(join(tmpdir(), "mise-diff-test-"));
	cleanup.push(root);
	return {root, home: join(root, "home with spaces"), run: async () => ok};
}

function mergeStatus(state = "differs") {
	return JSON.stringify({
		files: [],
		edits: [
			{
				path: "~/.config/codex/config.toml",
				edit: "merge:shared",
				state,
				origin: {source: "templates/codex-config.toml"},
			},
		],
	});
}

describe("native merge previews", () => {
	test("discovers edits, resolves source/destination/edit-id, and deduplicates selections", async () => {
		const rt = await runtime();
		const entries = parseStatus(mergeStatus());
		expect(selectEntries(entries, [], rt)).toEqual(entries);
		for (const target of [
			"templates/codex-config.toml",
			"~/.config/codex/config.toml",
			join(rt.home, ".config/codex/config.toml/shared"),
		]) {
			expect(selectEntries(entries, [target], rt)).toEqual(entries);
		}
		expect(selectEntries(entries, [entries[0]!.target, entries[0]!.source!], rt)).toHaveLength(1);
		expect(selectEntries(parseStatus(mergeStatus("applied")), [], rt)).toEqual([]);
	});

	test("destination selects every edit; edit-id selects only that edit", async () => {
		const rt = await runtime();
		const entries = parseStatus(
			JSON.stringify({
				files: [],
				edits: [
					{
						path: "~/.config/app.toml",
						edit: "merge:shared",
						state: "differs",
						origin: {source: "shared.toml"},
					},
					{path: "~/.config/app.toml", edit: "merge:local", state: "applied", origin: {source: "local.toml"}},
				],
			}),
		);
		expect(selectEntries(entries, ["~/.config/app.toml"], rt)).toHaveLength(2);
		expect(selectEntries(entries, ["~/.config/app.toml/local"], rt).map((entry) => entry.mode)).toEqual([
			"merge:local",
		]);
	});

	test("shows a native merge diff and prints only its scoped apply command", async () => {
		const rt = await runtime();
		const patch =
			'edit differs: config.toml (merge:shared)\n--- current\n+++ desired\n@@ -1 +1 @@\n-model = "old"\n+model = "new"\n';
		const calls: string[][] = [];
		rt.run = async (args) => {
			calls.push(args);
			return {...ok, stdout: args[2] === "status" ? mergeStatus() : patch};
		};
		const result = await miseDotDiffLib({targets: ["templates/codex-config.toml"]}, rt);
		expect(result.failed).toBe(false);
		expect(result.output).toContain(patch.trimEnd());
		expect(result.output).toContain(
			`mise dot apply ${JSON.stringify(join(rt.home, ".config/codex/config.toml/shared"))}`,
		);
		expect(calls).toEqual([
			["mise", "dot", "status", "-J"],
			["mise", "dot", "diff", "~/.config/codex/config.toml/shared"],
		]);
	});

	test.each([
		"pull",
		"missing source",
		"bad TOML",
	])("reports %s failure without suggesting apply", async (scenario) => {
		const rt = await runtime();
		rt.run = async (args) =>
			args[2] === "status"
				? {...ok, stdout: mergeStatus(scenario === "missing source" ? "source_missing" : "differs")}
				: {exitCode: 1, stdout: "", stderr: "invalid TOML"};
		const result = await miseDotDiffLib(
			{targets: ["templates/codex-config.toml"], pull: scenario === "pull"},
			rt,
		);
		expect(result.failed).toBe(true);
		expect(result.output).toContain("ERROR:");
		expect(result.output).not.toContain("mise dot apply");
	});
});

describe("JSON template overlays", () => {
	test("pulls changed/live-only keys, keeps existing overlay keys, replaces arrays, and reports deletions", () => {
		const live = {plugins: {shared: false, local: true}, allow: ["local"], count: 0, disabled: false};
		const desired = {
			plugins: {shared: true, missing: true},
			allow: ["shared"],
			count: 1,
			disabled: true,
			removed: true,
		};
		const {patch, missing} = overlayChanges(live, desired);
		expect(patch).toEqual(live);
		expect(missing).toEqual(["removed", "plugins.missing"]);
		expect(mergeObjects({plugins: {earlier: true}, allow: ["earlier"]}, patch)).toEqual({
			...live,
			plugins: {...live.plugins, earlier: true},
		});
		expect(overlayChanges(live, live)).toEqual({patch: {}, missing: []});
	});

	test("JSON normalization ignores object order but preserves array order and non-JSON", () => {
		expect(normalizeJson('{"b":2, "a":{"d":4,"c":3}}')).toBe(normalizeJson('{"a":{"c":3,"d":4},"b":2}'));
		expect(normalizeJson("[1,2]")).not.toBe(normalizeJson("[2,1]"));
		expect(normalizeJson('model = "x"\n')).toBe('model = "x"\n');
	});

	test("preview is read-only; explicit pull writes only the overlay", async () => {
		const rt = await runtime();
		const target = join(rt.home, "settings.json");
		const source = join(rt.root, "templates/settings.json.tera");
		const overlay = join(rt.home, "overlay.json");
		const live = '{"shared":false,"local":42}\n';
		const desired = '{"shared":true}\n';
		await Bun.write(target, live);
		await Bun.write(source, desired);
		const nativeDiff = await $`diff -u ${target} ${source}`.quiet().nothrow();
		const status = JSON.stringify({files: [{target, source, mode: "template", state: "differs"}], edits: []});
		rt.run = async (args) => {
			if (args[0] === "mise") return {...ok, stdout: args[2] === "status" ? status : nativeDiff.text()};
			const command = await $`${args}`.quiet().nothrow();
			return {exitCode: command.exitCode, stdout: command.text(), stderr: command.stderr.toString()};
		};
		const options = {targets: [source], pull: true, into: overlay};
		const preview = await miseDotDiffLib(options, rt);
		expect(preview.failed).toBe(false);
		expect(preview.output).toContain("overlay would become");
		expect(await Bun.file(overlay).exists()).toBe(false);
		const saved = await miseDotDiffLib({...options, write: true}, rt);
		expect(saved.failed).toBe(false);
		expect(await Bun.file(overlay).json()).toEqual({shared: false, local: 42});
		expect(await Bun.file(target).text()).toBe(live);
		expect(await Bun.file(source).text()).toBe(desired);
	});
});
