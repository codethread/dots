import {afterEach, expect, test} from "bun:test";
import {lstat, mkdir, mkdtemp, rm, symlink} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join} from "node:path";

const cleanupPaths: string[] = [];

afterEach(async () => {
	await Promise.all(cleanupPaths.splice(0).map((path) => rm(path, {recursive: true, force: true})));
});

test.each([
	false,
	true,
])("build replaces old tool symlinks without writing through them (dangling=%s)", async (dangling) => {
	const home = await mkdtemp(join(tmpdir(), "oven-build-test-"));
	cleanupPaths.push(home);
	const oldSource = join(home, "old-theme");
	const installed = join(home, ".local", "bin", "theme");
	await mkdir(join(home, ".local", "bin"), {recursive: true});
	if (!dangling) await Bun.write(oldSource, "original Bash source\n");
	await symlink(oldSource, installed);

	const build = Bun.spawn([process.execPath, join(import.meta.dir, "../scripts/build-bin.ts")], {
		env: {...process.env, HOME: home},
		stdout: "pipe",
		stderr: "pipe",
	});
	const [exitCode, stdout, stderr] = await Promise.all([
		build.exited,
		new Response(build.stdout).text(),
		new Response(build.stderr).text(),
	]);
	expect({exitCode, stdout, stderr}).toEqual({exitCode: 0, stdout: "", stderr: ""});
	expect((await lstat(installed)).isSymbolicLink()).toBe(false);
	expect((await lstat(installed)).mode & 0o111).toBe(0o111);
	expect(await Bun.file(installed).text()).toContain("/bin/theme.ts");
	expect(await Bun.file(oldSource).exists()).toBe(!dangling);
	const source = await Bun.file(oldSource)
		.text()
		.catch(() => "");
	expect(source).toBe(dangling ? "" : "original Bash source\n");
});
