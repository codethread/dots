import {afterAll, afterEach, beforeEach, describe, expect, test} from "bun:test";
import {
	cpSync,
	existsSync,
	mkdirSync,
	mkdtempSync,
	readFileSync,
	realpathSync,
	rmSync,
	writeFileSync,
} from "node:fs";
import {tmpdir} from "node:os";
import {dirname, join, resolve} from "node:path";

const repoRoot = resolve(import.meta.dir, "../..");
const scriptsRoot = join(repoRoot, "config/nushell/scripts");
const ovenRoot = join(repoRoot, "oven");

describe("wk nushell smoke", () => {
	let tmp: string;
	let env: Record<string, string>;

	beforeEach(() => {
		tmp = mkdtempSync(join(tmpdir(), "wk-smoke-"));
		const binDir = join(tmp, "bin");
		mkdirSync(binDir, {recursive: true});
		writeFileSync(
			join(binDir, "wktree"),
			`#!/usr/bin/env bash\nexec bun ${shellQuote(join(ovenRoot, "bin/wktree.ts"))} "$@"\n`,
			{mode: 0o755},
		);
		const smokeEnv = {...process.env};
		delete smokeEnv.TMUX;
		delete smokeEnv.TMUX_PANE;
		env = {
			...smokeEnv,
			HOME: tmp,
			XDG_CONFIG_HOME: join(tmp, "xdg-config"),
			PATH: `${binDir}:${process.env.PATH ?? ""}`,
		};
	});

	afterEach(() => {
		rmSync(tmp, {recursive: true, force: true});
	});

	test("non-pool wk add runs project command and wk remove deletes cleanly", async () => {
		const {root} = await initRepoWithOrigin(join(tmp, "nonpool"));
		writeConfig({
			configHome: env.XDG_CONFIG_HOME,
			root,
			command: `printf 'sentinel\\n' > "$WK_CREATED/nonpool-sentinel"`,
		});

		await runNu(`cd ${nuString(root)}; wk add feature/nonpool`, env);

		const worktreePath = await worktreePathForBranch(root, "feature/nonpool");
		expect(readFileSync(join(worktreePath, "nonpool-sentinel"), "utf8")).toBe("sentinel\n");
		writeFileSync(join(worktreePath, "self-base.txt"), "self base\n");
		await run(["git", "-C", worktreePath, "add", "self-base.txt"]);
		await run(["git", "-C", worktreePath, "commit", "-m", "self base"]);

		await runNu(`cd ${nuString(worktreePath)}; wk add feature/self-child --self`, env);
		const childPath = await worktreePathForBranch(root, "feature/self-child");
		expect(readFileSync(join(childPath, "self-base.txt"), "utf8")).toBe("self base\n");

		await runNu(`cd ${nuString(root)}; wk remove feature/self-child --force`, env);
		await runNu(`cd ${nuString(root)}; wk remove feature/nonpool --force`, env);

		expect(existsSync(worktreePath)).toBe(false);
	});

	test("pooled wk add initializes slots, recycles, and reallocates non-interactively", async () => {
		const {root} = await initRepoWithOrigin(join(tmp, "pool"));
		writeFileSync(join(root, ".gitignore"), "pool-sentinel\n");
		await run(["git", "-C", root, "add", ".gitignore"]);
		await run(["git", "-C", root, "commit", "-m", "ignore smoke sentinel"]);
		await run(["git", "-C", root, "push", "origin", "main"]);
		writeConfig({
			configHome: env.XDG_CONFIG_HOME,
			root,
			command: `printf 'pooled\\n' > "$WK_CREATED/pool-sentinel"`,
			poolSize: 2,
		});

		const firstAdd = await runNu(`cd ${nuString(root)}; wk add feat1`, env);

		expect(firstAdd.stderr + firstAdd.stdout).toContain("[wk-pool] initializing feat1");
		expect(firstAdd.stderr + firstAdd.stdout).toContain("[wk-pool] initializing feat2");
		const slot1 = await worktreePathForBranch(root, "feat1");
		const slot2 = await worktreePathForBranch(root, "wk-pool/feat2");
		expect(readFileSync(join(slot1, "pool-sentinel"), "utf8")).toBe("pooled\n");
		expect(readFileSync(join(slot2, "pool-sentinel"), "utf8")).toBe("pooled\n");
		expect((await run(["git", "-C", slot1, "branch", "--show-current"])).stdout.trim()).toBe("feat1");

		await run(["git", "-C", slot1, "branch", "--set-upstream-to", "origin/main", "feat1"]);
		await runNu(`cd ${nuString(root)}; wk remove feat1`, env);

		const recycledSlot1 = existingWorktreePath(root, "__feat1");
		expect(existsSync(recycledSlot1)).toBe(true);
		expect((await run(["git", "-C", recycledSlot1, "branch", "--show-current"])).stdout.trim()).toBe(
			"wk-pool/feat1",
		);

		await runNu(`cd ${nuString(root)}; wk add feat2`, env);

		// Pool allocation intentionally uses the lowest initialized free slot after recycle.
		expect((await run(["git", "-C", recycledSlot1, "branch", "--show-current"])).stdout.trim()).toBe("feat2");
		expect((await run(["git", "-C", slot2, "branch", "--show-current"])).stdout.trim()).toBe("wk-pool/feat2");
	}, 30_000);
});

function writeConfig(spec: {configHome: string; root: string; command: string; poolSize?: number}) {
	mkdirSync(join(spec.configHome, "ct-worktrees"), {recursive: true});
	writeFileSync(
		join(spec.configHome, "ct-worktrees/trees.toml"),
		`[[project]]\nroot = ${JSON.stringify(spec.root)}\ncommand = '''\n${spec.command}\n'''\n${spec.poolSize ? `pool_size = ${spec.poolSize}\n` : ""}`,
	);
}

let baseOriginFixture: {root: string; remote: string; tmp: string} | null = null;

afterAll(() => {
	if (baseOriginFixture) rmSync(baseOriginFixture.tmp, {recursive: true, force: true});
});

async function initRepoWithOrigin(parent: string) {
	mkdirSync(parent, {recursive: true});
	const fixture = await ensureBaseOriginFixture();
	let root = join(parent, "repo");
	const remote = join(parent, "origin.git");
	cpSync(fixture.root, root, {recursive: true});
	cpSync(fixture.remote, remote, {recursive: true});
	root = realpathSync(root);
	await run(["git", "-C", root, "remote", "set-url", "origin", remote]);
	return {root, remote};
}

async function ensureBaseOriginFixture() {
	if (baseOriginFixture) return baseOriginFixture;
	const tmp = mkdtempSync(join(tmpdir(), "wk-smoke-origin-fixture-"));
	let root = join(tmp, "repo");
	await initRepo(root);
	root = realpathSync(root);
	const remote = join(tmp, "origin.git");
	await run(["git", "init", "--bare", remote]);
	await run(["git", "-C", root, "remote", "add", "origin", remote]);
	await run(["git", "-C", root, "push", "-u", "origin", "main"]);
	await run(["git", "-C", remote, "symbolic-ref", "HEAD", "refs/heads/main"]);
	await run(["git", "-C", root, "remote", "set-head", "origin", "-a"]);
	baseOriginFixture = {root, remote, tmp};
	return baseOriginFixture;
}

async function initRepo(root: string) {
	mkdirSync(dirname(root), {recursive: true});
	await run(["git", "init", "-b", "main", root]);
	await run(["git", "-C", root, "config", "user.email", "test@example.test"]);
	await run(["git", "-C", root, "config", "user.name", "Test User"]);
	writeFileSync(join(root, "README.md"), "hello\n");
	await run(["git", "-C", root, "add", "README.md"]);
	await run(["git", "-C", root, "commit", "-m", "initial"]);
}

async function runNu(command: string, env: Record<string, string>) {
	return run(["nu", "-I", scriptsRoot, "-c", `use ct/git/worktree/mod.nu *; ${command}`], env);
}

async function run(cmd: string[], env?: Record<string, string>) {
	const result = await runRaw(cmd, env);
	if (result.exitCode !== 0) throw new Error(`${cmd.join(" ")} failed\n${result.stdout}\n${result.stderr}`);
	return result;
}

async function runRaw(cmd: string[], env?: Record<string, string>) {
	const proc = Bun.spawn(cmd, {stdout: "pipe", stderr: "pipe", env: env ?? process.env});
	const [stdout, stderr, exitCode] = await Promise.all([
		new Response(proc.stdout).text(),
		new Response(proc.stderr).text(),
		proc.exited,
	]);
	return {stdout, stderr, exitCode};
}

async function worktreePathForBranch(root: string, branch: string) {
	const list = (await run(["git", "-C", root, "worktree", "list", "--porcelain"])).stdout;
	const entries = list.trim().split(/\n\n+/);
	for (const entry of entries) {
		const lines = entry.split("\n");
		const path = lines.find((line) => line.startsWith("worktree "))?.slice("worktree ".length);
		const branchRef = lines.find((line) => line.startsWith("branch "))?.slice("branch refs/heads/".length);
		if (path && branchRef === branch) return path;
	}
	throw new Error(`missing worktree for ${branch}\n${list}`);
}

function existingWorktreePath(root: string, suffix: string) {
	const primary = `${root}${suffix}`;
	if (existsSync(primary)) return primary;
	const macAlias = root.startsWith("/private/") ? `${root.slice("/private".length)}${suffix}` : primary;
	if (existsSync(macAlias)) return macAlias;
	return primary;
}

function nuString(value: string) {
	return JSON.stringify(value);
}

function shellQuote(value: string) {
	return `'${value.replaceAll("'", "'\\''")}'`;
}
