import {afterAll, afterEach, beforeEach, describe, expect, test} from "bun:test";
import {
	chmodSync,
	cpSync,
	existsSync,
	mkdirSync,
	mkdtempSync,
	readFileSync,
	realpathSync,
	rmSync,
	writeFileSync,
} from "node:fs";
import {homedir, tmpdir} from "node:os";
import {join, resolve} from "node:path";
import type {Deps} from "../bin/wktree";
import {
	buildPoolState,
	ConfigError,
	dispatch,
	generateRunnerScript,
	HookError,
	LiveHookRunner,
	PickerCancelled,
	parseConfig,
} from "../bin/wktree";
import {LiveGitRunner} from "../shared/git/executor";
import {
	branchExistsInList,
	parseTrunkFromRemoteShow,
	parseTrunkFromSymbolicRef,
	parseWorktreeList,
} from "../shared/git/worktrees";

const integrationDescribe = process.env.WKTREE_SKIP_INTEGRATION === "1" ? describe.skip : describe;

const deps: Deps = {
	git: new LiveGitRunner(),
	hooks: {runInline: async () => undefined},
	picker: {
		pick: async () => ({key: "", display: "", preview: ""}),
		confirm: async () => true,
	},
	progress: {
		banner: () => undefined,
		stream: () => undefined,
		error: () => undefined,
	},
};

describe("wktree dispatch", () => {
	test("prints help with exit code 0", async () => {
		const result = await dispatch("--help", [], deps);
		expect(result.exitCode).toBe(0);
		expect(result.stdout).toContain("Usage: wktree <subcommand>");
	});

	test("prints usage with exit code 1 for unknown subcommands", async () => {
		const result = await dispatch("somebogus", [], deps);
		expect(result.exitCode).toBe(1);
		expect(result.stderr).toContain("Usage: wktree <subcommand>");
	});
});

describe("parseConfig", () => {
	test("parses a valid pooled project", () => {
		const config = parseConfig(`
[[project]]
name = "app"
root = "~/work/app"
command = "yarn install"
pool_size = 5
`);

		expect(config.projects).toEqual([
			{name: "app", root: resolve(homedir(), "work/app"), command: "yarn install", poolSize: 5},
		]);
	});

	test("parses a valid non-pooled project with default name", () => {
		const config = parseConfig(`
[[project]]
root = "./relative/repo"
command = "echo ready"
`);

		expect(config.projects).toEqual([
			{name: "repo", root: resolve("./relative/repo"), command: "echo ready", poolSize: null},
		]);
	});

	test("parses mixed pooled and non-pooled projects", () => {
		const config = parseConfig(`
[[project]]
root = "/tmp/one"
command = "echo one"

[[project]]
root = "/tmp/two"
command = "echo two"
pool_size = 2
`);

		expect(config.projects).toHaveLength(2);
		expect(config.projects[0]?.poolSize).toBeNull();
		expect(config.projects[1]?.poolSize).toBe(2);
	});

	test("ignores unknown fields on project entries", () => {
		const config = parseConfig(`
[[project]]
root = "/tmp/unknown"
command = "echo ok"
future_field = "ignored"
`);

		expect(config.projects[0]).toEqual({
			name: "unknown",
			root: "/tmp/unknown",
			command: "echo ok",
			poolSize: null,
		});
	});

	test.each([
		{name: "missing root", toml: '[[project]]\ncommand = "echo ok"', message: "root"},
		{name: "missing command", toml: '[[project]]\nroot = "/tmp/repo"', message: "command"},
		{
			name: "pool_size zero",
			toml: '[[project]]\nroot = "/tmp/repo"\ncommand = "x"\npool_size = 0',
			message: "pool_size",
		},
		{
			name: "pool_size negative",
			toml: '[[project]]\nroot = "/tmp/repo"\ncommand = "x"\npool_size = -1',
			message: "pool_size",
		},
		{
			name: "pool_size non-integer",
			toml: '[[project]]\nroot = "/tmp/repo"\ncommand = "x"\npool_size = 1.5',
			message: "pool_size",
		},
	])("throws ConfigError for $name", ({toml, message}) => {
		expect(() => parseConfig(toml)).toThrow(ConfigError);
		expect(() => parseConfig(toml)).toThrow(message);
	});

	test("rejects duplicate expanded roots", () => {
		expect(() =>
			parseConfig(`
[[project]]
root = "~/same"
command = "echo one"

[[project]]
root = "${resolve(homedir(), "same")}"
command = "echo two"
`),
		).toThrow(ConfigError);
	});

	test("rejects legacy post_create entries with migration hint", () => {
		expect(() =>
			parseConfig(`
[[post_create]]
root = "/tmp/repo"
command = "echo old"
`),
		).toThrow("rename [[post_create]] to [[project]]");
	});

	test("rejects shell field with bash-only hint", () => {
		expect(() =>
			parseConfig(`
[[project]]
root = "/tmp/repo"
command = "echo ok"
shell = "nu"
`),
		).toThrow("command always runs under bash");
	});
});

describe("git worktree parsers", () => {
	test("parses a canonical-only worktree", () => {
		const worktrees = parseWorktreeList(`worktree /repo\nHEAD abc123\nbranch refs/heads/main\n`);

		expect(worktrees).toEqual([
			{
				path: "/repo",
				head: "abc123",
				branch: "main",
				branchRef: "refs/heads/main",
				detached: false,
				bare: false,
				canonical: true,
				pool: null,
			},
		]);
	});

	test("annotates free and taken pool slots", () => {
		const worktrees = parseWorktreeList(
			`worktree /repo\nHEAD aaa\nbranch refs/heads/main\n\nworktree /repo__feat1\nHEAD bbb\nbranch refs/heads/wk-pool/feat1\n\nworktree /repo__feat2\nHEAD ccc\nbranch refs/heads/my-feature\n`,
		);

		expect(worktrees[1]?.pool).toEqual({index: 1, placeholder: true});
		expect(worktrees[1]?.branch).toBe("wk-pool/feat1");
		expect(worktrees[2]?.pool).toEqual({index: 2, placeholder: false});
		expect(worktrees[2]?.branch).toBe("my-feature");
	});

	test("parses detached HEAD without a branch", () => {
		const worktrees = parseWorktreeList(`worktree /repo\nHEAD abc123\ndetached\n`);

		expect(worktrees[0]?.detached).toBe(true);
		expect(worktrees[0]?.branch).toBeNull();
		expect(worktrees[0]?.branchRef).toBeNull();
	});

	test("parses bare repositories", () => {
		const worktrees = parseWorktreeList(`worktree /repo.git\nbare\n`);

		expect(worktrees[0]?.bare).toBe(true);
		expect(worktrees[0]?.head).toBeNull();
	});

	test("parses symbolic-ref trunk names", () => {
		expect(parseTrunkFromSymbolicRef("refs/remotes/origin/main\n")).toBe("main");
		expect(parseTrunkFromSymbolicRef("refs/remotes/origin/develop\n")).toBe("develop");
		expect(parseTrunkFromSymbolicRef("\n")).toBeNull();
	});

	test("parses remote show default branch", () => {
		expect(
			parseTrunkFromRemoteShow(
				"* remote origin\n  Fetch URL: git@example.test/repo\n  HEAD branch: develop\n",
			),
		).toBe("develop");
		expect(parseTrunkFromRemoteShow("* remote origin\n  Fetch URL: git@example.test/repo\n")).toBeNull();
		expect(parseTrunkFromRemoteShow("* remote origin\n  HEAD branch: (unknown)\n")).toBeNull();
	});

	test("checks exact branch existence from branch list output", () => {
		expect(branchExistsInList("* main\n  feature\n  feature-extra\n", "feature")).toBe(true);
		expect(branchExistsInList("* main\n+ checked-out-elsewhere\n", "checked-out-elsewhere")).toBe(true);
		expect(branchExistsInList("* main\n  feature-extra\n", "feature")).toBe(false);
	});
});

describe("runner scripts", () => {
	test("generates non-pooled runner script", () => {
		expect(
			generateRunnerScript({
				projectName: "app",
				root: "/tmp/repo",
				created: "/tmp/repo__feature",
				hookBodyPath: "/tmp/app.hook.sh",
				pooled: false,
			}),
		).toMatchSnapshot();
	});

	test("generates pooled runner script with marker tail", () => {
		expect(
			generateRunnerScript({
				projectName: "app",
				root: "/tmp/repo",
				created: "/tmp/repo__feat1",
				hookBodyPath: "/tmp/app.hook.sh",
				pooled: true,
			}),
		).toMatchSnapshot();
	});

	test("single-quotes paths with spaces and embedded quotes", () => {
		const script = generateRunnerScript({
			projectName: "quoted",
			root: "/tmp/root with spaces",
			created: "/tmp/root with spaces__feat1",
			hookBodyPath: "/tmp/hooks/it'works.hook.sh",
			pooled: false,
		});

		expect(script).toContain("export WK_ROOT='/tmp/root with spaces'");
		expect(script).toContain("bash '/tmp/hooks/it'\\''works.hook.sh'");
	});
});

describe("LiveHookRunner", () => {
	let tmp: string;

	beforeEach(() => {
		tmp = mkdtempSync(join(tmpdir(), "wktree-hook-test-"));
	});

	afterEach(() => {
		rmSync(tmp, {recursive: true, force: true});
	});

	test("streams output before process exit", async () => {
		const script = join(tmp, "hook.sh");
		writeFileSync(script, "echo first\nsleep 0.05\necho second\n");
		chmodSync(script, 0o755);
		const seen: string[] = [];
		const runner = new LiveHookRunner();

		const promise = runner.runInline(script, tmp, {}, (stream, line) => seen.push(`${stream}:${line}`));
		await Bun.sleep(25);
		expect(seen).toEqual(["stdout:first"]);
		await promise;
		expect(seen).toEqual(["stdout:first", "stdout:second"]);
	});

	test("throws HookError with exit code and slot path on failure", async () => {
		const script = join(tmp, "hook.sh");
		writeFileSync(script, "echo bad >&2\nexit 7\n");
		chmodSync(script, 0o755);
		const runner = new LiveHookRunner();

		try {
			await runner.runInline(script, tmp, {}, () => undefined);
			throw new Error("expected hook to fail");
		} catch (error) {
			expect(error).toBeInstanceOf(HookError);
			expect((error as HookError).hookExitCode).toBe(7);
			expect((error as HookError).slotPath).toBe(tmp);
		}
	});
});

describe("LiveGitRunner", () => {
	test("runs git --version", async () => {
		const git = new LiveGitRunner();
		const result = await git.run(["--version"]);
		expect(result.exitCode).toBe(0);
		expect(result.stdout).toContain("git version");
	});
});

integrationDescribe("wktree non-pool add", () => {
	let tmp: string;
	let originalConfigHome: string | undefined;
	let originalHome: string | undefined;

	beforeEach(() => {
		tmp = mkdtempSync(join(tmpdir(), "wktree-add-test-"));
		originalConfigHome = process.env.XDG_CONFIG_HOME;
		originalHome = process.env.HOME;
		process.env.HOME = tmp;
	});

	afterEach(() => {
		if (originalConfigHome === undefined) delete process.env.XDG_CONFIG_HOME;
		else process.env.XDG_CONFIG_HOME = originalConfigHome;
		if (originalHome === undefined) delete process.env.HOME;
		else process.env.HOME = originalHome;
		rmSync(tmp, {recursive: true, force: true});
	});

	test("adds a new branch, writes snake_case AddPlan, and runner is re-executable", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(tmp, root, `echo hook > "$WK_CREATED/hook-sentinel"`);
		const resultFile = join(tmp, "plan.json");

		const result = await dispatch(
			"add",
			["--cwd", root, "--branch", "feature/new", "--result-file", resultFile],
			deps,
		);

		expect(result.exitCode).toBe(0);
		const worktreePath = `${root}__feature--new`;
		expect(existsSync(join(worktreePath, ".git"))).toBe(true);
		const plan = JSON.parse(readFileSync(resultFile, "utf8"));
		expect(plan).toMatchObject({
			worktree_path: worktreePath,
			branch: "feature/new",
			root,
			title: "feature/new",
			created_new_branch: true,
		});
		expect(plan.runner_script_path).toContain(".runner.sh");
		await run(["bash", plan.runner_script_path]);
		await run(["bash", plan.runner_script_path]);
		expect(readFileSync(join(worktreePath, "hook-sentinel"), "utf8")).toBe("hook\n");
	});

	test.each([
		{
			name: "existing local",
			branch: "feature/local",
			setup: async (root: string) => run(["git", "-C", root, "branch", "feature/local"]),
		},
		{
			name: "existing remote-only",
			branch: "feature/remote",
			setup: async (_root: string, remote: string) => createRemoteBranch(remote, "feature/remote"),
		},
		{
			name: "existing local and remote",
			branch: "feature/both",
			setup: async (root: string, remote: string) => {
				await createRemoteBranch(remote, "feature/both");
				await run(["git", "-C", root, "fetch", "origin"]);
				await run(["git", "-C", root, "branch", "feature/both", "origin/feature/both"]);
			},
		},
	])("adds $name branch", async ({branch, setup}) => {
		const {root, remote} = await initRepoWithOrigin(tmp);
		await setup(root, remote);
		writeConfig(tmp, root, "echo ready");
		const resultFile = join(tmp, `${branch.replaceAll("/", "-")}.json`);

		const result = await dispatch(
			"add",
			["--cwd", root, "--branch", branch, "--result-file", resultFile],
			deps,
		);

		expect(result.exitCode).toBe(0);
		expect(JSON.parse(readFileSync(resultFile, "utf8")).worktree_path).toBe(
			`${root}__${branch.replaceAll("/", "--")}`,
		);
	});

	test("warns but succeeds when local branch has diverged from remote", async () => {
		const {root, remote} = await initRepoWithOrigin(tmp);
		await createRemoteBranch(remote, "feature/diverged");
		await run(["git", "-C", root, "fetch", "origin"]);
		await run(["git", "-C", root, "checkout", "-b", "feature/diverged", "main"]);
		writeFileSync(join(root, "local.txt"), "local\n");
		await run(["git", "-C", root, "add", "local.txt"]);
		await run(["git", "-C", root, "commit", "-m", "local"]);
		await run(["git", "-C", root, "checkout", "main"]);
		writeConfig(tmp, root, "echo ready");
		const warnings: string[] = [];
		const warnDeps = {...deps, progress: {...deps.progress, error: (msg: string) => warnings.push(msg)}};

		const result = await dispatch(
			"add",
			["--cwd", root, "--branch", "feature/diverged", "--result-file", join(tmp, "diverged.json")],
			warnDeps,
		);

		expect(result.exitCode).toBe(0);
		expect(warnings.join("\n")).toContain("couldn't fast-forward");
	});

	test("defaults new branches to origin default branch instead of current HEAD", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(tmp, root, "echo ready");
		await run(["git", "-C", root, "checkout", "-b", "local/current"]);
		writeFileSync(join(root, "current-only.txt"), "current\n");
		await run(["git", "-C", root, "add", "current-only.txt"]);
		await run(["git", "-C", root, "commit", "-m", "current only"]);

		await dispatch(
			"add",
			["--cwd", root, "--branch", "feature/default-base", "--result-file", join(tmp, "default-base.json")],
			deps,
		);

		const missing = await Bun.spawn(
			["git", "-C", `${root}__feature--default-base`, "show", "HEAD:current-only.txt"],
			{stdout: "pipe", stderr: "pipe"},
		).exited;
		expect(missing).not.toBe(0);
	});

	test("uses --base for a new branch and warns when --base is ignored for existing branch", async () => {
		const {root, remote} = await initRepoWithOrigin(tmp);
		await createRemoteBranch(remote, "base/topic");
		writeConfig(tmp, root, "echo ready");
		const warnings: string[] = [];
		const warnDeps = {...deps, progress: {...deps.progress, error: (msg: string) => warnings.push(msg)}};

		await dispatch(
			"add",
			[
				"--cwd",
				root,
				"--branch",
				"feature/from-base",
				"--base",
				"base/topic",
				"--result-file",
				join(tmp, "base.json"),
			],
			warnDeps,
		);
		const baseFile = await run(["git", "-C", `${root}__feature--from-base`, "show", "HEAD:remote.txt"]);
		expect(baseFile.stdout).toBe("base/topic\n");

		await run(["git", "-C", root, "checkout", "-b", "local/base"]);
		writeFileSync(join(root, "local-base.txt"), "local base\n");
		await run(["git", "-C", root, "add", "local-base.txt"]);
		await run(["git", "-C", root, "commit", "-m", "local base"]);
		await run(["git", "-C", root, "checkout", "main"]);
		await dispatch(
			"add",
			[
				"--cwd",
				root,
				"--branch",
				"feature/from-local-base",
				"--base",
				"local/base",
				"--result-file",
				join(tmp, "local-base.json"),
			],
			warnDeps,
		);
		expect(
			(await run(["git", "-C", `${root}__feature--from-local-base`, "show", "HEAD:local-base.txt"])).stdout,
		).toBe("local base\n");

		await dispatch(
			"add",
			[
				"--cwd",
				root,
				"--branch",
				"feature/from-base",
				"--base",
				"base/topic",
				"--result-file",
				join(tmp, "base-ignored.json"),
			],
			warnDeps,
		).catch(() => undefined);
		expect(warnings.join("\n")).toContain("--base ignored");
	});

	test("accepts --force for wrapper compatibility", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(tmp, root, "echo ready");
		const result = await dispatch(
			"add",
			["--cwd", root, "--branch", "feature/force", "--force", "--result-file", join(tmp, "force.json")],
			deps,
		);

		expect(result.exitCode).toBe(0);
		expect(existsSync(`${root}__feature--force`)).toBe(true);
	});

	test("without project config runner_script_path is null", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		process.env.XDG_CONFIG_HOME = join(tmp, "empty-config");
		const resultFile = join(tmp, "plan.json");

		await dispatch(
			"add",
			["--cwd", root, "--branch", "feature/no-project", "--result-file", resultFile],
			deps,
		);

		expect(JSON.parse(readFileSync(resultFile, "utf8")).runner_script_path).toBeNull();
	});

	test("rejects reserved pool branch prefix", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		await expect(
			dispatch(
				"add",
				["--cwd", root, "--branch", "wk-pool/feat1", "--result-file", join(tmp, "x.json")],
				deps,
			),
		).rejects.toThrow("reserved");
	});
});

integrationDescribe("wktree non-pool remove", () => {
	let tmp: string;
	let originalConfigHome: string | undefined;

	beforeEach(() => {
		tmp = mkdtempSync(join(tmpdir(), "wktree-remove-test-"));
		originalConfigHome = process.env.XDG_CONFIG_HOME;
	});

	afterEach(() => {
		if (originalConfigHome === undefined) delete process.env.XDG_CONFIG_HOME;
		else process.env.XDG_CONFIG_HOME = originalConfigHome;
		rmSync(tmp, {recursive: true, force: true});
	});

	test("removes a non-pool worktree and branch", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(tmp, root, "echo ready");
		await dispatch(
			"add",
			["--cwd", root, "--branch", "feature/remove", "--result-file", join(tmp, "add.json")],
			deps,
		);
		const resultFile = join(tmp, "remove.json");

		const result = await dispatch(
			"remove",
			["--cwd", root, "--branch", "feature/remove", "--result-file", resultFile],
			deps,
		);

		expect(result.exitCode).toBe(0);
		expect(existsSync(`${root}__feature--remove`)).toBe(false);
		expect(
			(await runRaw(["git", "-C", root, "show-ref", "--verify", "refs/heads/feature/remove"])).exitCode,
		).not.toBe(0);
		expect(JSON.parse(readFileSync(resultFile, "utf8"))).toEqual({
			worktree_path: `${root}__feature--remove`,
			removed: true,
		});
	});

	test("removes by --self path", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(tmp, root, "echo ready");
		await dispatch(
			"add",
			["--cwd", root, "--branch", "feature/self", "--result-file", join(tmp, "add.json")],
			deps,
		);

		await dispatch(
			"remove",
			["--cwd", root, "--self", `${root}__feature--self`, "--result-file", join(tmp, "self.json")],
			deps,
		);

		expect(existsSync(`${root}__feature--self`)).toBe(false);
	});

	test("removes non-pool branches whose encoded paths resemble pool slots", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(tmp, root, "echo ready");
		await dispatch("add", ["--cwd", root, "--branch", "feat1", "--result-file", join(tmp, "add.json")], deps);

		await dispatch(
			"remove",
			["--cwd", root, "--branch", "feat1", "--result-file", join(tmp, "feat1.json")],
			deps,
		);

		expect(existsSync(`${root}__feat1`)).toBe(false);
	});

	test("unmerged branch fails without --force and succeeds with --force", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(tmp, root, "echo ready");
		await dispatch(
			"add",
			["--cwd", root, "--branch", "feature/unmerged", "--result-file", join(tmp, "add.json")],
			deps,
		);
		writeFileSync(join(`${root}__feature--unmerged`, "unmerged.txt"), "work\n");
		await run(["git", "-C", `${root}__feature--unmerged`, "add", "unmerged.txt"]);
		await run(["git", "-C", `${root}__feature--unmerged`, "commit", "-m", "unmerged"]);

		await expect(
			dispatch(
				"remove",
				["--cwd", root, "--branch", "feature/unmerged", "--result-file", join(tmp, "fail.json")],
				deps,
			),
		).rejects.toThrow("not merged");
		expect(existsSync(`${root}__feature--unmerged`)).toBe(true);

		await dispatch(
			"remove",
			["--cwd", root, "--branch", "feature/unmerged", "--force", "--result-file", join(tmp, "force.json")],
			deps,
		);
		expect(existsSync(`${root}__feature--unmerged`)).toBe(false);
		expect(
			(await runRaw(["git", "-C", root, "show-ref", "--verify", "refs/heads/feature/unmerged"])).exitCode,
		).not.toBe(0);
	});

	test("refuses canonical root and non-worktree targets", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(tmp, root, "echo ready");

		await expect(
			dispatch("remove", ["--cwd", root, "--self", root, "--result-file", join(tmp, "root.json")], deps),
		).rejects.toThrow("canonical root");
		await expect(
			dispatch(
				"remove",
				["--cwd", root, "--self", join(tmp, "missing"), "--result-file", join(tmp, "missing.json")],
				deps,
			),
		).rejects.toThrow("not a git worktree");
	});
});

integrationDescribe("wktree pool status", () => {
	let tmp: string;
	let originalConfigHome: string | undefined;

	beforeEach(() => {
		tmp = mkdtempSync(join(tmpdir(), "wktree-status-test-"));
		originalConfigHome = process.env.XDG_CONFIG_HOME;
	});

	afterEach(() => {
		if (originalConfigHome === undefined) delete process.env.XDG_CONFIG_HOME;
		else process.env.XDG_CONFIG_HOME = originalConfigHome;
		rmSync(tmp, {recursive: true, force: true});
	});

	test("reports absent slots for an empty pool", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(tmp, root, "echo ready", 2);
		const worktrees = parseWorktreeList(
			(await run(["git", "-C", root, "worktree", "list", "--porcelain"])).stdout,
		);

		const state = await buildPoolState(
			{name: "repo", root, command: "echo ready", poolSize: 2},
			worktrees,
			new LiveGitRunner(),
		);

		expect(state).toMatchObject({root, trunk: "main", size: 2});
		expect(state.slots.map((slot) => ({exists: slot.exists, initialized: slot.initialized}))).toEqual([
			{exists: false, initialized: false},
			{exists: false, initialized: false},
		]);
	});

	test("status JSON reports free, taken, dirty, and half-initialized slots", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(tmp, root, "echo ready", 4);
		await createPoolSlot(root, 1, "wk-pool/feat1", true);
		await createPoolSlot(root, 2, "feature/taken", true);
		await createPoolSlot(root, 3, "feature/dirty", true);
		writeFileSync(join(`${root}__feat3`, "dirty.txt"), "dirty\n");
		await createPoolSlot(root, 4, "wk-pool/feat4", false);

		const result = await dispatch("status", ["--cwd", root], deps);
		const state = JSON.parse(result.stdout ?? "{}");

		expect(state.root).toBe(root);
		expect(state.trunk).toBe("main");
		expect(state.slots[0]).toMatchObject({
			index: 1,
			exists: true,
			branch: "wk-pool/feat1",
			placeholder: true,
			dirty: false,
			initialized: true,
		});
		expect(state.slots[1]).toMatchObject({
			index: 2,
			exists: true,
			branch: "feature/taken",
			placeholder: false,
			dirty: false,
			initialized: true,
		});
		expect(state.slots[2]).toMatchObject({
			index: 3,
			exists: true,
			branch: "feature/dirty",
			dirty: true,
			initialized: true,
		});
		expect(state.slots[3]).toMatchObject({index: 4, exists: true, placeholder: true, initialized: false});
		expect(state.slots[0].lastCommitIso).toContain("T");
		expect(state.slots[0].lastCommitSubject).toBe("initial");
	});

	test("gitignored files do not mark a slot dirty and non-pooled status is empty", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(tmp, root, "echo ready", 1);
		await createPoolSlot(root, 1, "wk-pool/feat1", true);
		writeFileSync(join(`${root}__feat1`, ".gitignore"), "node_modules/\n");
		await run(["git", "-C", `${root}__feat1`, "add", ".gitignore"]);
		await run(["git", "-C", `${root}__feat1`, "commit", "-m", "ignore node_modules"]);
		mkdirSync(join(`${root}__feat1`, "node_modules"));
		writeFileSync(join(`${root}__feat1`, "node_modules", "ignored.txt"), "ignored\n");

		const pooled = JSON.parse((await dispatch("status", ["--cwd", root], deps)).stdout ?? "{}");
		expect(pooled.slots[0].dirty).toBe(false);

		writeConfig(tmp, root, "echo ready");
		const nonPooled = JSON.parse((await dispatch("status", ["--cwd", root], deps)).stdout ?? "{}");
		expect(nonPooled).toEqual({root, trunk: null, size: 0, slots: []});
	});
});

integrationDescribe("wktree read-only commands", () => {
	let tmp: string;
	let originalConfigHome: string | undefined;

	beforeEach(() => {
		tmp = mkdtempSync(join(tmpdir(), "wktree-test-"));
		originalConfigHome = process.env.XDG_CONFIG_HOME;
	});

	afterEach(() => {
		if (originalConfigHome === undefined) delete process.env.XDG_CONFIG_HOME;
		else process.env.XDG_CONFIG_HOME = originalConfigHome;
		rmSync(tmp, {recursive: true, force: true});
	});

	test("root, list, json list, and non-pool path against a real repo", async () => {
		let root = join(tmp, "repo");
		await initRepo(root);
		root = realpathSync(root);
		const configHome = join(tmp, "config");
		mkdirSync(join(configHome, "ct-worktrees"), {recursive: true});
		writeFileSync(
			join(configHome, "ct-worktrees", "trees.toml"),
			`[[project]]\nroot = "${root}"\ncommand = "echo ready"\n`,
		);
		process.env.XDG_CONFIG_HOME = configHome;

		const rootResult = await dispatch("root", ["--cwd", root], deps);
		expect(rootResult.stdout).toBe(`${root}\n`);

		const listResult = await dispatch("list", ["--cwd", root], deps);
		expect(listResult.stdout).toContain(`${root}  `);
		expect(listResult.stdout).toContain("[main]");
		expect(listResult.stdout).toContain("[canonical]");

		const jsonResult = await dispatch("list", ["--cwd", root, "--json"], deps);
		const parsed = JSON.parse(jsonResult.stdout ?? "[]");
		expect(parsed[0]).toMatchObject({
			path: root,
			branch: "main",
			branch_ref: "refs/heads/main",
			locked: false,
			prunable: false,
			canonical: true,
			pool: null,
		});
		expect(parsed[0].branchRef).toBeUndefined();

		const pathResult = await dispatch("path", ["--cwd", root, "--branch", "feature/cool"], deps);
		expect(pathResult.stdout).toBe(`${root}__feature--cool\n`);
	});

	test("list fails fast on malformed config", async () => {
		let root = join(tmp, "repo");
		await initRepo(root);
		root = realpathSync(root);
		const configHome = join(tmp, "config");
		mkdirSync(join(configHome, "ct-worktrees"), {recursive: true});
		writeFileSync(join(configHome, "ct-worktrees", "trees.toml"), "[[project]]\nroot = ");
		process.env.XDG_CONFIG_HOME = configHome;

		await expect(dispatch("list", ["--cwd", root], deps)).rejects.toThrow(ConfigError);
	});

	test("list annotates pool slots and path refuses pooled repos before slot state exists", async () => {
		const configRoot = join(tmp, "repo");
		const {root} = await initRepoWithOrigin(tmp);
		await run(["git", "-C", root, "branch", "wk-pool/feat1"]);
		await run(["git", "-C", root, "worktree", "add", `${root}__feat1`, "wk-pool/feat1"]);
		await run(["git", "-C", root, "worktree", "lock", "--reason", "keep slot", `${root}__feat1`]);
		const configHome = join(tmp, "config");
		mkdirSync(join(configHome, "ct-worktrees"), {recursive: true});
		writeFileSync(
			join(configHome, "ct-worktrees", "trees.toml"),
			`[[project]]\nroot = "${configRoot}"\ncommand = "echo ready"\npool_size = 1\n`,
		);
		process.env.XDG_CONFIG_HOME = configHome;

		const listResult = await dispatch("list", ["--cwd", root], deps);
		expect(listResult.stdout).toContain("[pool:free]");
		const jsonResult = await dispatch("list", ["--cwd", root, "--json"], deps);
		const json = JSON.parse(jsonResult.stdout ?? "[]");
		expect(json[1]).toMatchObject({locked: true, lock_reason: "keep slot"});

		await expect(dispatch("path", ["--cwd", root, "--branch", "feature/cool"], deps)).rejects.toThrow(
			"no pooled worktree",
		);
	});
});

integrationDescribe("wktree pooled add", () => {
	let tmp: string;
	let originalConfigHome: string | undefined;
	let originalHome: string | undefined;

	beforeEach(() => {
		tmp = mkdtempSync(join(tmpdir(), "wktree-pool-add-test-"));
		originalConfigHome = process.env.XDG_CONFIG_HOME;
		originalHome = process.env.HOME;
		process.env.HOME = tmp;
	});

	afterEach(() => {
		if (originalConfigHome === undefined) delete process.env.XDG_CONFIG_HOME;
		else process.env.XDG_CONFIG_HOME = originalConfigHome;
		if (originalHome === undefined) delete process.env.HOME;
		else process.env.HOME = originalHome;
		rmSync(tmp, {recursive: true, force: true});
	});

	test("allocates the lowest initialized free slot and writes a pooled runner", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(tmp, root, "touch pooled-sentinel", 2);
		await dispatch("ensure", ["--cwd", root], testDeps());
		const resultFile = join(tmp, "plan.json");

		await dispatch(
			"add",
			["--cwd", root, "--branch", "feature/pooled", "--result-file", resultFile],
			testDeps(),
		);

		const plan = JSON.parse(readFileSync(resultFile, "utf8"));
		const runnerScriptPath = plan.runner_script_path as string;
		expect(plan).toMatchObject({
			worktree_path: `${root}__feat1`,
			branch: "feature/pooled",
			created_new_branch: true,
		});
		expect(runnerScriptPath).toContain(".runner.sh");
		expect(readFileSync(runnerScriptPath, "utf8")).toContain("wk-pool-initialized");
		expect((await run(["git", "-C", `${root}__feat1`, "branch", "--show-current"])).stdout.trim()).toBe(
			"feature/pooled",
		);
		expect((await run(["git", "-C", `${root}__feat2`, "branch", "--show-current"])).stdout.trim()).toBe(
			"wk-pool/feat2",
		);
	});

	test.each([
		{
			name: "existing remote-only",
			branch: "feature/remote-pool",
			setup: async (_root: string, remote: string) => createRemoteBranch(remote, "feature/remote-pool"),
		},
		{
			name: "existing local",
			branch: "feature/local-pool",
			setup: async (root: string) => run(["git", "-C", root, "branch", "feature/local-pool"]),
		},
	])("allocates $name branch", async ({branch, setup}) => {
		const {root, remote} = await initRepoWithOrigin(tmp);
		await setup(root, remote);
		writeConfig(tmp, root, "echo ready", 1);

		await dispatch(
			"add",
			["--cwd", root, "--branch", branch, "--result-file", join(tmp, "plan.json")],
			testDeps(),
		);

		expect((await run(["git", "-C", `${root}__feat1`, "branch", "--show-current"])).stdout.trim()).toBe(
			branch,
		);
	});

	test("warns for diverged branches and rejects duplicates without side effects", async () => {
		const {root, remote} = await initRepoWithOrigin(tmp);
		await createRemoteBranch(remote, "feature/diverged-pool");
		await run(["git", "-C", root, "fetch", "origin"]);
		await run(["git", "-C", root, "checkout", "-b", "feature/diverged-pool", "main"]);
		writeFileSync(join(root, "local.txt"), "local\n");
		await run(["git", "-C", root, "add", "local.txt"]);
		await run(["git", "-C", root, "commit", "-m", "local"]);
		await run(["git", "-C", root, "checkout", "main"]);
		writeConfig(tmp, root, "echo ready", 2);
		const warnings: string[] = [];
		const warnDeps = testDeps({progress: {...deps.progress, error: (msg: string) => warnings.push(msg)}});

		await dispatch(
			"add",
			["--cwd", root, "--branch", "feature/diverged-pool", "--result-file", join(tmp, "diverged.json")],
			warnDeps,
		);
		expect(warnings.join("\n")).toContain("couldn't fast-forward");

		await expect(
			dispatch(
				"add",
				["--cwd", root, "--branch", "feature/diverged-pool", "--result-file", join(tmp, "dup.json")],
				testDeps(),
			),
		).rejects.toThrow(`${root}__feat1`);
		expect((await run(["git", "-C", `${root}__feat2`, "branch", "--show-current"])).stdout.trim()).toBe(
			"wk-pool/feat2",
		);
	});

	test("rejects duplicate canonical branch and reserved branch before allocation", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(tmp, root, "echo ready", 1);

		await expect(
			dispatch(
				"add",
				["--cwd", root, "--branch", "main", "--result-file", join(tmp, "main.json")],
				testDeps(),
			),
		).rejects.toThrow(root);
		await expect(
			dispatch(
				"add",
				["--cwd", root, "--branch", "wk-pool/feat9", "--result-file", join(tmp, "reserved.json")],
				testDeps(),
			),
		).rejects.toThrow("reserved");
		expect(existsSync(`${root}__feat1`)).toBe(false);
	});

	test("pooled path finds allocated branch and --base only affects new branches", async () => {
		const {root, remote} = await initRepoWithOrigin(tmp);
		await createRemoteBranch(remote, "base/pool");
		await run(["git", "-C", root, "fetch", "origin"]);
		await run(["git", "-C", root, "branch", "feature/existing-base"]);
		writeConfig(tmp, root, "echo ready", 2);
		const warnings: string[] = [];
		const warnDeps = testDeps({progress: {...deps.progress, error: (msg: string) => warnings.push(msg)}});

		await dispatch(
			"add",
			[
				"--cwd",
				root,
				"--branch",
				"feature/from-base",
				"--base",
				"base/pool",
				"--result-file",
				join(tmp, "base.json"),
			],
			warnDeps,
		);
		expect((await run(["git", "-C", `${root}__feat1`, "show", "HEAD:remote.txt"])).stdout).toBe(
			"base/pool\n",
		);
		expect((await dispatch("path", ["--cwd", root, "--branch", "feature/from-base"], warnDeps)).stdout).toBe(
			`${root}__feat1\n`,
		);
		await expect(dispatch("path", ["--cwd", root, "--branch", "feature/missing"], warnDeps)).rejects.toThrow(
			"no pooled worktree",
		);

		await dispatch(
			"add",
			[
				"--cwd",
				root,
				"--branch",
				"feature/existing-base",
				"--base",
				"base/pool",
				"--result-file",
				join(tmp, "ignored.json"),
			],
			warnDeps,
		);
		expect(warnings.join("\n")).toContain("--base ignored");
	});

	test("pool full picker recycles selected slot and allocates", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(tmp, root, "echo ready", 1);
		await dispatch(
			"add",
			["--cwd", root, "--branch", "feature/one", "--result-file", join(tmp, "one.json")],
			testDeps(),
		);
		await run(["git", "-C", `${root}__feat1`, "branch", "--set-upstream-to", "origin/main", "feature/one"]);
		const picker = new TestPicker("1", true);

		await dispatch(
			"add",
			["--cwd", root, "--branch", "feature/two", "--result-file", join(tmp, "two.json")],
			testDeps({picker}),
		);

		expect((await run(["git", "-C", `${root}__feat1`, "branch", "--show-current"])).stdout.trim()).toBe(
			"feature/two",
		);
		expect(picker.items[0]?.display).toContain("feature/one");
		expect(picker.items[0]?.preview).toContain("rev-list --left-right --count");
	});

	test("pool full cancel and confirm-no exit 130 without side effects; --force skips confirm", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(tmp, root, "echo ready", 1);
		await dispatch(
			"add",
			["--cwd", root, "--branch", "feature/one", "--result-file", join(tmp, "one.json")],
			testDeps(),
		);
		await expect(
			dispatch(
				"add",
				["--cwd", root, "--branch", "feature/cancel", "--result-file", join(tmp, "cancel.json")],
				testDeps({picker: new TestPicker(null, true)}),
			),
		).rejects.toThrow("cancelled");
		expect((await run(["git", "-C", `${root}__feat1`, "branch", "--show-current"])).stdout.trim()).toBe(
			"feature/one",
		);
		await expect(
			dispatch(
				"add",
				["--cwd", root, "--branch", "feature/no", "--result-file", join(tmp, "no.json")],
				testDeps({picker: new TestPicker("1", false)}),
			),
		).rejects.toThrow("cancelled");
		expect((await run(["git", "-C", `${root}__feat1`, "branch", "--show-current"])).stdout.trim()).toBe(
			"feature/one",
		);
		const picker = new TestPicker("1", false);
		await dispatch(
			"add",
			["--cwd", root, "--branch", "feature/forced", "--force", "--result-file", join(tmp, "forced.json")],
			testDeps({picker}),
		);
		expect(picker.confirmCalls).toBe(0);
		expect((await run(["git", "-C", `${root}__feat1`, "branch", "--show-current"])).stdout.trim()).toBe(
			"feature/forced",
		);
	});
});

integrationDescribe("wktree recycle", () => {
	let tmp: string;
	let originalConfigHome: string | undefined;

	beforeEach(() => {
		tmp = mkdtempSync(join(tmpdir(), "wktree-recycle-test-"));
		originalConfigHome = process.env.XDG_CONFIG_HOME;
	});

	afterEach(() => {
		if (originalConfigHome === undefined) delete process.env.XDG_CONFIG_HOME;
		else process.env.XDG_CONFIG_HOME = originalConfigHome;
		rmSync(tmp, {recursive: true, force: true});
	});

	test("safe recycle resets slot to placeholder and remove delegates with removed false", async () => {
		const {root, remote} = await initRepoWithOrigin(tmp);
		await createRemoteBranch(remote, "feature/safe");
		writeConfig(tmp, root, "echo ready", 1);
		await dispatch(
			"add",
			["--cwd", root, "--branch", "feature/safe", "--result-file", join(tmp, "add.json")],
			testDeps(),
		);
		await run([
			"git",
			"-C",
			`${root}__feat1`,
			"branch",
			"--set-upstream-to",
			"origin/feature/safe",
			"feature/safe",
		]);
		const resultFile = join(tmp, "remove.json");

		await dispatch(
			"remove",
			["--cwd", root, "--branch", "feature/safe", "--result-file", resultFile],
			testDeps(),
		);

		expect(existsSync(`${root}__feat1`)).toBe(true);
		expect((await run(["git", "-C", `${root}__feat1`, "branch", "--show-current"])).stdout.trim()).toBe(
			"wk-pool/feat1",
		);
		expect(
			(await runRaw(["git", "-C", root, "show-ref", "--verify", "refs/heads/feature/safe"])).exitCode,
		).not.toBe(0);
		expect(JSON.parse(readFileSync(resultFile, "utf8"))).toEqual({
			worktree_path: `${root}__feat1`,
			removed: false,
		});
	});

	test("safe preflight blocks dirty slots and leaves branch untouched", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(tmp, root, "echo ready", 1);
		await dispatch(
			"add",
			["--cwd", root, "--branch", "feature/dirty", "--result-file", join(tmp, "add.json")],
			testDeps(),
		);
		writeFileSync(join(`${root}__feat1`, "dirty.txt"), "dirty\n");

		await expect(
			dispatch("recycle", ["--cwd", root, "--slot", `${root}__feat1`], testDeps()),
		).rejects.toThrow("uncommitted changes");

		expect((await run(["git", "-C", `${root}__feat1`, "branch", "--show-current"])).stdout.trim()).toBe(
			"feature/dirty",
		);
		expect(existsSync(join(`${root}__feat1`, "dirty.txt"))).toBe(true);
	});

	test("forced recycle discards tracked and untracked dirt but preserves gitignored node_modules", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeFileSync(join(root, ".gitignore"), "node_modules/\n");
		await run(["git", "-C", root, "add", ".gitignore"]);
		await run(["git", "-C", root, "commit", "-m", "ignore modules"]);
		await run(["git", "-C", root, "push", "origin", "main"]);
		writeConfig(tmp, root, "echo ready", 1);
		await dispatch(
			"add",
			["--cwd", root, "--branch", "feature/force-recycle", "--result-file", join(tmp, "add.json")],
			testDeps(),
		);
		writeFileSync(join(`${root}__feat1`, "tracked.txt"), "tracked\n");
		await run(["git", "-C", `${root}__feat1`, "add", "tracked.txt"]);
		await run(["git", "-C", `${root}__feat1`, "commit", "-m", "local unmerged"]);
		writeFileSync(join(`${root}__feat1`, "untracked.txt"), "untracked\n");
		mkdirSync(join(`${root}__feat1`, "node_modules"));
		writeFileSync(join(`${root}__feat1`, "node_modules", "keep.txt"), "keep\n");

		await dispatch("recycle", ["--cwd", root, "--slot", `${root}__feat1`, "--force"], testDeps());

		expect((await run(["git", "-C", `${root}__feat1`, "branch", "--show-current"])).stdout.trim()).toBe(
			"wk-pool/feat1",
		);
		expect(existsSync(join(`${root}__feat1`, "tracked.txt"))).toBe(false);
		expect(existsSync(join(`${root}__feat1`, "untracked.txt"))).toBe(false);
		expect(existsSync(join(`${root}__feat1`, "node_modules", "keep.txt"))).toBe(true);
		expect(
			(await runRaw(["git", "-C", root, "show-ref", "--verify", "refs/heads/feature/force-recycle"]))
				.exitCode,
		).not.toBe(0);
	});

	test("missing or unmerged upstream blocks safe recycle", async () => {
		const {root, remote} = await initRepoWithOrigin(tmp);
		await createRemoteBranch(remote, "feature/upstream-blocked");
		writeConfig(tmp, root, "echo ready", 1);
		await dispatch(
			"add",
			["--cwd", root, "--branch", "feature/upstream-blocked", "--result-file", join(tmp, "add.json")],
			testDeps(),
		);
		await expect(
			dispatch("recycle", ["--cwd", root, "--slot", `${root}__feat1`], testDeps()),
		).rejects.toThrow("no upstream");
		await run([
			"git",
			"-C",
			`${root}__feat1`,
			"branch",
			"--set-upstream-to",
			"origin/feature/upstream-blocked",
			"feature/upstream-blocked",
		]);
		writeFileSync(join(`${root}__feat1`, "ahead.txt"), "ahead\n");
		await run(["git", "-C", `${root}__feat1`, "add", "ahead.txt"]);
		await run(["git", "-C", `${root}__feat1`, "commit", "-m", "ahead"]);

		await expect(
			dispatch("recycle", ["--cwd", root, "--slot", `${root}__feat1`], testDeps()),
		).rejects.toThrow("not merged");
		expect((await run(["git", "-C", `${root}__feat1`, "branch", "--show-current"])).stdout.trim()).toBe(
			"feature/upstream-blocked",
		);
	});
});

integrationDescribe("wktree ensure", () => {
	let tmp: string;
	let originalConfigHome: string | undefined;

	beforeEach(() => {
		tmp = mkdtempSync(join(tmpdir(), "wktree-ensure-test-"));
		originalConfigHome = process.env.XDG_CONFIG_HOME;
	});

	afterEach(() => {
		if (originalConfigHome === undefined) delete process.env.XDG_CONFIG_HOME;
		else process.env.XDG_CONFIG_HOME = originalConfigHome;
		rmSync(tmp, {recursive: true, force: true});
	});

	test("materialises slots sequentially and streams hook output", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(tmp, root, "echo hook-$WK_CREATED; touch sentinel", 2);
		const events: string[] = [];
		const liveDeps = testDeps({
			progress: {
				banner: (line: string) => {
					events.push(line);
				},
				stream: (_stream: "stdout" | "stderr", line: string) => {
					events.push(line);
				},
				error: () => undefined,
			},
		});

		await dispatch("ensure", ["--cwd", root], liveDeps);

		expect(events[0]).toBe("[wk-pool] initializing feat1…");
		expect(events.some((event) => event.includes("__feat1"))).toBe(true);
		expect(events.indexOf("[wk-pool] initializing feat1…")).toBeLessThan(
			events.indexOf("[wk-pool] initializing feat2…"),
		);
		expect(existsSync(join(`${root}__feat1`, "sentinel"))).toBe(true);
		expect(existsSync(join(`${root}__feat2`, "sentinel"))).toBe(true);
	});

	test("hook failure rolls back only in-flight slot and rerun recovers", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(
			tmp,
			root,
			'case "$WK_CREATED" in *__feat2) if [ ! -f "$WK_ROOT/recover" ]; then exit 7; fi;; esac; touch sentinel',
			3,
		);

		await expect(dispatch("ensure", ["--cwd", root], testDeps())).rejects.toThrow(HookError);
		expect(existsSync(`${root}__feat1`)).toBe(true);
		expect(existsSync(`${root}__feat2`)).toBe(false);
		expect(existsSync(`${root}__feat3`)).toBe(false);

		writeFileSync(join(root, "recover"), "ok\n");
		await dispatch("ensure", ["--cwd", root], testDeps());
		expect(existsSync(join(`${root}__feat3`, "sentinel"))).toBe(true);
	});

	test("half-init reruns hook and preserves existing slot on failure", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(tmp, root, "echo rerun >> hook.log", 1);
		await createPoolSlot(root, 1, "wk-pool/feat1", false);

		await dispatch("ensure", ["--cwd", root], testDeps());

		expect(readFileSync(join(`${root}__feat1`, "hook.log"), "utf8")).toContain("rerun");
		const marker = (
			await run(["git", "-C", `${root}__feat1`, "rev-parse", "--git-path", "wk-pool-initialized"])
		).stdout.trim();
		expect(existsSync(resolve(`${root}__feat1`, marker))).toBe(true);

		writeConfig(tmp, root, "exit 9", 2);
		await createPoolSlot(root, 2, "wk-pool/feat2", false);
		await expect(dispatch("ensure", ["--cwd", root], testDeps())).rejects.toThrow(HookError);
		expect(existsSync(`${root}__feat2`)).toBe(true);
	});

	test("list and pooled remove trigger first-run ensure", async () => {
		const {root} = await initRepoWithOrigin(tmp);
		writeConfig(tmp, root, "touch ensured", 1);

		const listResult = await dispatch("list", ["--cwd", root], testDeps());
		expect(listResult.stdout).toContain("[pool:free]");
		expect(existsSync(join(`${root}__feat1`, "ensured"))).toBe(true);

		await expect(
			dispatch(
				"remove",
				["--cwd", root, "--self", `${root}__feat1`, "--result-file", join(tmp, "remove.json")],
				testDeps(),
			),
		).rejects.toThrow("uncommitted changes");
	});
});

class TestPicker {
	items: {key: string; display: string; preview: string}[] = [];
	confirmCalls = 0;

	constructor(
		private choice: string | null,
		private confirmed: boolean,
	) {}

	async pick(items: {key: string; display: string; preview: string}[]) {
		this.items = items;
		if (this.choice === null) throw new PickerCancelled();
		const item = items.find((candidate) => candidate.key === this.choice);
		if (!item) throw new PickerCancelled();
		return item;
	}

	async confirm() {
		this.confirmCalls++;
		return this.confirmed;
	}
}

function testDeps(overrides: Partial<Deps> = {}): Deps {
	return {
		git: new LiveGitRunner(),
		hooks: new LiveHookRunner(),
		picker: deps.picker,
		progress: deps.progress,
		...overrides,
	};
}

function writeConfig(...args: [tmp: string, root: string, command: string, poolSize?: number]) {
	const [tmp, root, command, poolSize] = args;
	const configHome = join(tmp, "config");
	mkdirSync(join(configHome, "ct-worktrees"), {recursive: true});
	writeFileSync(
		join(configHome, "ct-worktrees", "trees.toml"),
		`[[project]]\nroot = "${root}"\ncommand = '''\n${command}\n'''\n${poolSize ? `pool_size = ${poolSize}\n` : ""}`,
	);
	process.env.XDG_CONFIG_HOME = configHome;
}

let baseOriginFixture: {root: string; remote: string; tmp: string} | null = null;

afterAll(() => {
	if (baseOriginFixture) rmSync(baseOriginFixture.tmp, {recursive: true, force: true});
});

async function initRepoWithOrigin(tmp: string) {
	const fixture = await ensureBaseOriginFixture();
	let root = join(tmp, "repo");
	const remote = join(tmp, "origin.git");
	cpSync(fixture.root, root, {recursive: true});
	cpSync(fixture.remote, remote, {recursive: true});
	root = realpathSync(root);
	await run(["git", "-C", root, "remote", "set-url", "origin", remote]);
	return {root, remote};
}

async function ensureBaseOriginFixture() {
	if (baseOriginFixture) return baseOriginFixture;
	const tmp = mkdtempSync(join(tmpdir(), "wktree-origin-fixture-"));
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

async function createPoolSlot(...args: [root: string, index: number, branch: string, initialized: boolean]) {
	const [root, index, branch, initialized] = args;
	await run(["git", "-C", root, "branch", branch]);
	const slotPath = `${root}__feat${index}`;
	await run(["git", "-C", root, "worktree", "add", slotPath, branch]);
	if (initialized) {
		const marker = (
			await run(["git", "-C", slotPath, "rev-parse", "--git-path", "wk-pool-initialized"])
		).stdout.trim();
		writeFileSync(resolve(slotPath, marker), "");
	}
}

async function createRemoteBranch(remote: string, branch: string) {
	const clone = mkdtempSync(join(tmpdir(), "wktree-remote-clone-"));
	try {
		await run(["git", "clone", remote, clone]);
		await run(["git", "-C", clone, "config", "user.email", "test@example.test"]);
		await run(["git", "-C", clone, "config", "user.name", "Test User"]);
		await run(["git", "-C", clone, "checkout", "-b", branch]);
		writeFileSync(join(clone, "remote.txt"), `${branch}\n`);
		await run(["git", "-C", clone, "add", "remote.txt"]);
		await run(["git", "-C", clone, "commit", "-m", `remote ${branch}`]);
		await run(["git", "-C", clone, "push", "origin", branch]);
	} finally {
		rmSync(clone, {recursive: true, force: true});
	}
}

async function initRepo(root: string) {
	mkdirSync(root, {recursive: true});
	await run(["git", "init", "-b", "main", root]);
	await run(["git", "-C", root, "config", "user.email", "test@example.test"]);
	await run(["git", "-C", root, "config", "user.name", "Test User"]);
	writeFileSync(join(root, "README.md"), "hello\n");
	await run(["git", "-C", root, "add", "README.md"]);
	await run(["git", "-C", root, "commit", "-m", "initial"]);
}

async function run(cmd: string[]) {
	const result = await runRaw(cmd);
	if (result.exitCode !== 0) throw new Error(`${cmd.join(" ")} failed\n${result.stdout}\n${result.stderr}`);
	return result;
}

async function runRaw(cmd: string[]) {
	const proc = Bun.spawn(cmd, {stdout: "pipe", stderr: "pipe"});
	const [stdout, stderr, exitCode] = await Promise.all([
		new Response(proc.stdout).text(),
		new Response(proc.stderr).text(),
		proc.exited,
	]);
	return {stdout, stderr, exitCode};
}
