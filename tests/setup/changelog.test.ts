import {expect, test} from "bun:test";
import {tmpdir} from "node:os";
import {fileURLToPath} from "node:url";
import {type FormatConfig, format} from "oxfmt";
import config from "../../.oxfmtrc.json";
import history from "../../changelog.json";
import {markdown} from "../../scripts/changelog.ts";

const entrypoint = fileURLToPath(new URL("../../scripts/changelog.ts", import.meta.url));

test("the generated changelog matches its recorded history", async () => {
	expect(await Bun.file(new URL("../../CHANGELOG.md", import.meta.url)).text()).toBe(await markdown(history));
});

test("generated bodies and adoption notes survive format-on-commit unchanged", async () => {
	const generated = await markdown([
		{
			version: "1.0.0",
			changes: [
				{
					commit: "abcdef0",
					summary: "Recorded change",
					body: "A paragraph.\n\n```sh\necho example\n```",
					breaking: ["A breaking note"],
					adoption: [{requirement: "required", text: "Update your configuration."}],
				},
			],
		},
	]);
	const formatted = await format("CHANGELOG.md", generated, config as FormatConfig);
	expect(formatted.errors).toEqual([]);
	expect(formatted.code).toBe(generated);
});

test("changelog commands work outside the checkout and reject conflicting modes", async () => {
	for (const args of [[], ["--check"], ["--write", "--check"], ["--unknown"]]) {
		const child = Bun.spawn([process.execPath, entrypoint, ...args], {
			cwd: tmpdir(),
			stdout: "pipe",
			stderr: "pipe",
		});
		const [code, stdout, stderr] = await Promise.all([
			child.exited,
			new Response(child.stdout).text(),
			new Response(child.stderr).text(),
		]);
		if (args.includes("--write") || args.includes("--unknown")) {
			expect(code).not.toBe(0);
			expect(stderr).not.toBe("");
		} else {
			expect(code).toBe(0);
			expect(stderr).toBe("");
			expect(stdout).toBe(args.length === 0 ? await markdown(history) : "");
		}
	}
});
