// :module: Reusable git worktree pool manager
// Exit-code taxonomy:
//   0   success / ready
//   10  blocked / recoverable state (for example `pool_full`)
//   11  unsafe operation refused without explicit force
//   12  usage or config error
//   130 cancelled by picker / user
//   1   unexpected runtime or hook failure

import {
	closeSync,
	existsSync,
	mkdirSync,
	openSync,
	readFileSync,
	readSync,
	realpathSync,
	writeFileSync,
} from "node:fs";
import {homedir} from "node:os";
import {basename, resolve} from "node:path";
import {TOML} from "bun";
import {Command, CommanderError} from "commander";
import {fzf} from "../shared/fzf";
import {type GitRunner, LiveGitRunner} from "../shared/git/executor";
import {
	parseTrunkFromRemoteShow,
	parseTrunkFromSymbolicRef,
	parseWorktreeList,
} from "../shared/git/worktrees";

export {GitError} from "../shared/git/executor";

// ── Config types ──────────────────────────────────────────────────────────────
export interface ProjectConfig {
	name: string | null;
	root: string;
	command: string;
	poolSize: number | null;
}

export type TreesConfig = {projects: ProjectConfig[]};

// ── Worktree / slot types ─────────────────────────────────────────────────────
export interface Worktree {
	path: string;
	head: string | null;
	branch: string | null;
	branchRef: string | null;
	detached: boolean;
	bare: boolean;
	canonical: boolean;
	pool: {index: number; placeholder: boolean} | null;
}

export interface Slot {
	index: number;
	path: string;
	exists: boolean;
	branch: string | null;
	placeholder: boolean;
	dirty: boolean;
	lastCommitIso: string | null;
	lastCommitSubject: string | null;
	initialized: boolean;
}

export interface PoolState {
	root: string;
	trunk: string;
	size: number;
	slots: Slot[];
}

export type Allocation =
	| {kind: "free-slot"; slotIndex: number; branchExists: "local" | "remote" | "none"}
	| {kind: "pool-full"; candidateSlots: Slot[]}
	| {kind: "duplicate"; slotIndex: number; branch: string};

export interface AddPlan {
	worktreePath: string;
	branch: string;
	root: string;
	title: string;
	runnerScriptPath: string | null;
	createdNewBranch: boolean;
}

export interface RemovePlan {
	worktreePath: string;
	removed: boolean;
}

export interface SessionInfo {
	name: string;
	path: string;
}

export interface ReadyAddPayload {
	kind: "ready";
	worktree_path: string;
	branch: string;
	root: string;
	title: string;
	session: SessionInfo;
	runner_script_path: string | null;
	created_new_branch: boolean;
}

export interface ReadyRemovePayload {
	kind: "ready";
	worktree_path: string;
	removed: boolean;
	session: SessionInfo;
}

export interface PoolFullCandidate {
	slot: number;
	path: string;
	branch: string | null;
	dirty: boolean;
	ahead: number;
	local_only: boolean;
	last_commit_iso: string | null;
	last_commit_subject: string | null;
}

export interface PoolFullPayload {
	kind: "pool_full";
	root: string;
	branch: string;
	candidates: PoolFullCandidate[];
}

export interface BlockedPayload {
	kind: "blocked";
	reason: string;
	message: string;
	branch?: string;
	worktree_path?: string;
	slot_path?: string;
}

export interface RunnerScriptSpec {
	projectName: string;
	root: string;
	created: string;
	hookBodyPath: string;
	pooled: boolean;
}

export const EXIT_CODES = {
	SUCCESS: 0,
	BLOCKED: 10,
	UNSAFE: 11,
	USAGE: 12,
	CANCELLED: 130,
	FAILURE: 1,
} as const;

export class WktreeError extends Error {
	constructor(
		message: string,
		public exitCode: number = EXIT_CODES.FAILURE,
	) {
		super(message);
		this.name = new.target.name;
	}
}

export class UsageError extends WktreeError {
	constructor(message: string) {
		super(message, EXIT_CODES.USAGE);
	}
}

export class BlockedError extends WktreeError {
	constructor(message: string) {
		super(message, EXIT_CODES.BLOCKED);
	}
}

export class UnsafeOperationError extends WktreeError {
	constructor(message: string) {
		super(message, EXIT_CODES.UNSAFE);
	}
}

export class ConfigError extends UsageError {}
export class PickerCancelled extends WktreeError {
	constructor() {
		super("cancelled", EXIT_CODES.CANCELLED);
	}
}
export class DuplicateBranchError extends BlockedError {}
export class DirtySlotError extends UnsafeOperationError {}
export class UnmergedBranchError extends UnsafeOperationError {}
export class ReservedPrefixError extends UsageError {}
export class CanonicalRootError extends UnsafeOperationError {}
export class HookError extends WktreeError {
	constructor(
		public hookExitCode: number,
		public slotPath: string,
	) {
		super(`hook failed in ${slotPath} (${hookExitCode})`, EXIT_CODES.FAILURE);
	}
}
export class TrunkDetectionError extends UsageError {}

export interface HookRunner {
	runInline(
		scriptPath: string,
		cwd: string,
		env: Record<string, string>,
		onLine: (stream: "stdout" | "stderr", line: string) => void,
	): Promise<void>;
}

export interface PickerItem {
	key: string;
	display: string;
	preview: string;
}

export interface PickerService {
	pick(items: PickerItem[], header: string): Promise<PickerItem>;
	confirm(prompt: string): Promise<boolean>;
}

export interface ProgressReporter {
	banner(line: string): void;
	stream(stream: "stdout" | "stderr", line: string): void;
	error(msg: string): void;
}

export interface Deps {
	git: GitRunner;
	hooks: HookRunner;
	picker: PickerService;
	progress: ProgressReporter;
}

export function parseConfig(toml: string): TreesConfig {
	let raw: unknown;
	try {
		raw = TOML.parse(toml);
	} catch (error) {
		const message = error instanceof Error ? error.message : String(error);
		throw new ConfigError(`Invalid TOML in trees.toml: ${message}`);
	}

	if (!isRecord(raw)) {
		throw new ConfigError("Invalid trees.toml: expected a top-level TOML table");
	}

	if ("post_create" in raw) {
		throw new ConfigError(
			"Legacy [[post_create]] entries are no longer supported; rename [[post_create]] to [[project]]",
		);
	}

	const rawProjects = raw.project ?? [];
	if (!Array.isArray(rawProjects)) {
		throw new ConfigError("Invalid trees.toml: [[project]] must be an array of tables");
	}

	const seenRoots = new Set<string>();
	const projects = rawProjects.map((entry, index) => parseProjectConfig(entry, index, seenRoots));
	return {projects};
}

const USAGE = `wktree - reusable git worktree pool manager

Usage: wktree <subcommand> [options]

Subcommands:
  root      Print canonical worktree root
  list      List worktrees
  path      Print worktree path for branch
  add       Add or allocate a worktree
  remove    Remove or recycle a worktree
  ensure    Materialise pooled worktree slots
  status    Print pool status JSON
  recycle   Recycle a pooled slot

Options:
  -h, --help  Show this help message
`;

export interface CommandResult {
	stdout?: string;
	stderr?: string;
	exitCode: number;
}

interface OutputMode {
	json: boolean;
}

export async function dispatch(
	subcommand: string | undefined,
	args: string[],
	deps: Deps,
): Promise<CommandResult> {
	if (!subcommand || subcommand === "--help" || subcommand === "-h") {
		return {stdout: USAGE, exitCode: 0};
	}

	switch (subcommand) {
		case "root":
			return rootCommand(args, deps);
		case "list":
			return listCommand(args, deps);
		case "path":
			return pathCommand(args, deps);
		case "add":
			return addCommand(args, deps);
		case "remove":
			return removeCommand(args, deps);
		case "status":
			return statusCommand(args, deps);
		case "ensure":
			return ensureCommand(args, deps);
		case "recycle":
			return recycleCommand(args, deps);
		default:
			return {stderr: USAGE, exitCode: EXIT_CODES.USAGE};
	}
}

async function main() {
	const deps = createLiveDeps();

	const program = new Command();
	program
		.name("wktree")
		.description("Reusable git worktree pool manager")
		.configureOutput({
			writeOut: (str) => process.stderr.write(str),
			writeErr: (str) => process.stderr.write(str),
		})
		.exitOverride();

	program
		.command("root")
		.description("Print canonical worktree root")
		.requiredOption("--cwd <path>", "Path within git repository")
		.action(async (opts) => {
			await runAction("root", optsToArgs(opts), deps);
		});

	program
		.command("list")
		.description("List worktrees")
		.requiredOption("--cwd <path>", "Path within git repository")
		.option("--json", "Output as JSON")
		.action(async (opts) => {
			await runAction("list", optsToArgs(opts), deps);
		});

	program
		.command("path")
		.description("Print worktree path for branch")
		.requiredOption("--cwd <path>", "Path within git repository")
		.requiredOption("--branch <branch>", "Branch name")
		.action(async (opts) => {
			await runAction("path", optsToArgs(opts), deps);
		});

	program
		.command("add")
		.description("Add or allocate a worktree")
		.requiredOption("--cwd <path>", "Path within git repository")
		.requiredOption("--branch <branch>", "Branch name")
		.option("--json", "Machine-readable output")
		.option("--slot <path>", "Specific pool slot path")
		.option("--base <branch>", "Base branch for new branches")
		.option("--force", "Force operation")
		.action(async (opts) => {
			await runAction("add", optsToArgs(opts), deps);
		});

	program
		.command("remove")
		.description("Remove or recycle a worktree")
		.requiredOption("--cwd <path>", "Path within git repository")
		.option("--branch <branch>", "Branch to remove")
		.option("--self <path>", "Remove the worktree at this path")
		.option("--json", "Machine-readable output")
		.option("--force", "Force removal")
		.action(async (opts) => {
			await runAction("remove", optsToArgs(opts), deps);
		});

	program
		.command("ensure")
		.description("Materialise pooled worktree slots")
		.requiredOption("--cwd <path>", "Path within git repository")
		.action(async (opts) => {
			await runAction("ensure", optsToArgs(opts), deps);
		});

	program
		.command("status")
		.description("Print pool status JSON")
		.requiredOption("--cwd <path>", "Path within git repository")
		.action(async (opts) => {
			await runAction("status", optsToArgs(opts), deps);
		});

	program
		.command("recycle")
		.description("Recycle a pooled slot")
		.requiredOption("--cwd <path>", "Path within git repository")
		.requiredOption("--slot <path>", "Pool slot path")
		.option("--force", "Force recycle")
		.action(async (opts) => {
			await runAction("recycle", optsToArgs(opts), deps);
		});

	try {
		await program.parseAsync(Bun.argv);
	} catch (error) {
		if (error instanceof CommanderError) {
			process.exit(error.exitCode === 0 ? 0 : EXIT_CODES.USAGE);
		}
		const exitCode = error instanceof WktreeError ? error.exitCode : EXIT_CODES.FAILURE;
		process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
		process.exit(exitCode);
	}
}

async function runAction(subcmd: string, args: string[], deps: Deps): Promise<void> {
	try {
		const result = await dispatch(subcmd, args, deps);
		if (result.stdout) process.stdout.write(result.stdout);
		if (result.stderr) process.stderr.write(result.stderr);
		process.exit(result.exitCode);
	} catch (error) {
		if (error instanceof WktreeError) {
			process.stderr.write(`${error.message}\n`);
			process.exit(error.exitCode);
		}
		throw error;
	}
}

function optsToArgs(opts: Record<string, unknown>): string[] {
	const args: string[] = [];
	for (const [key, value] of Object.entries(opts)) {
		if (value === true) args.push(`--${key}`);
		else if (value !== false && value !== undefined && value !== null) args.push(`--${key}`, String(value));
	}
	return args;
}

function createLiveDeps(): Deps {
	return {
		git: new LiveGitRunner(),
		hooks: new LiveHookRunner(),
		picker: new LivePickerService(),
		progress: new ConsoleProgressReporter(),
	};
}

function parseProjectConfig(entry: unknown, index: number, seenRoots: Set<string>): ProjectConfig {
	const label = `[[project]] entry ${index + 1}`;
	if (!isRecord(entry)) {
		throw new ConfigError(`${label} must be a TOML table`);
	}

	if ("shell" in entry) {
		throw new ConfigError(`${label}: \`shell\` is no longer supported; command always runs under bash`);
	}

	const rootValue = entry.root;
	if (typeof rootValue !== "string" || rootValue.trim() === "") {
		throw new ConfigError(`${label}: required field \`root\` is missing or empty`);
	}

	const commandValue = entry.command;
	if (typeof commandValue !== "string" || commandValue.trim() === "") {
		throw new ConfigError(`${label}: required field \`command\` is missing or empty`);
	}

	const root = expandPath(rootValue);
	if (seenRoots.has(root)) {
		throw new ConfigError(`${label}: duplicate root \`${root}\``);
	}
	seenRoots.add(root);

	const nameValue = entry.name;
	if (nameValue !== undefined && typeof nameValue !== "string") {
		throw new ConfigError(`${label}: optional field \`name\` must be a string when present`);
	}

	const poolSize = parsePoolSize(entry.pool_size, label);
	return {
		name: nameValue ?? basename(root),
		root,
		command: commandValue,
		poolSize,
	};
}

async function rootCommand(args: string[], deps: Deps) {
	const opts = parseOptions(args);
	const cwd = requireOption(opts, "cwd");
	const canonicalRoot = await resolveCanonicalRoot(deps.git, cwd);
	return {stdout: `${canonicalRoot}\n`, exitCode: 0};
}

async function listCommand(args: string[], deps: Deps) {
	const opts = parseOptions(args);
	const cwd = requireOption(opts, "cwd");
	const config = readConfig();
	const canonicalRoot = await resolveCanonicalRoot(deps.git, cwd);
	const project = findProjectForRoot(config, canonicalRoot);
	if (project?.poolSize) await ensurePool(project, deps);
	const worktrees = await listWorktrees(deps.git, cwd);
	if (opts.json) return {stdout: `${JSON.stringify(worktrees.map(toListJson), null, 2)}\n`, exitCode: 0};
	return {stdout: formatWorktreeList(worktrees), exitCode: 0};
}

async function pathCommand(args: string[], deps: Deps) {
	const opts = parseOptions(args);
	const cwd = requireOption(opts, "cwd");
	const branch = requireOption(opts, "branch");
	const canonicalRoot = await resolveCanonicalRoot(deps.git, cwd);
	const project = findProjectForRoot(readConfig(), canonicalRoot);
	if (project?.poolSize) {
		const state = await buildPoolState(project, await listWorktrees(deps.git, canonicalRoot), deps.git);
		const slot = state.slots.find((candidate) => candidate.branch === branch);
		if (!slot) throw new BlockedError(`no pooled worktree found for branch ${branch}`);
		return {stdout: `${slot.path}\n`, exitCode: 0};
	}
	return {stdout: `${canonicalRoot}__${encodeBranch(branch)}\n`, exitCode: 0};
}

async function addCommand(args: string[], deps: Deps) {
	const opts = parseOptions(args);
	const cwd = requireOption(opts, "cwd");
	const branch = requireOption(opts, "branch");
	const output = parseOutputMode(opts);
	const machineDeps = withMachineJsonProgress(deps, output);
	const slotPath = typeof opts.slot === "string" ? opts.slot : null;
	const base = typeof opts.base === "string" ? opts.base : null;
	if (branch.startsWith("wk-pool/")) {
		throw new ReservedPrefixError("branch names starting with wk-pool/ are reserved");
	}

	try {
		const canonicalRoot = await resolveCanonicalRoot(machineDeps.git, cwd);
		const project = findProjectForRoot(readConfig(), canonicalRoot);
		if (slotPath && !project?.poolSize) {
			throw new UsageError("--slot is only valid for pooled projects");
		}
		if (project?.poolSize) {
			return addPooledWorktree({
				deps: machineDeps,
				project,
				root: canonicalRoot,
				branch,
				slotPath,
				output,
				base,
				force: opts.force === true,
			});
		}

		const worktreePath = `${canonicalRoot}__${encodeBranch(branch)}`;
		if (normalizeExistingPath(worktreePath) === normalizeExistingPath(canonicalRoot)) {
			throw new CanonicalRootError("refusing to use canonical root as worktree target");
		}

		await machineDeps.git.run(["-C", canonicalRoot, "fetch", "origin"]);
		const branchState = await detectBranchState(machineDeps.git, canonicalRoot, branch);
		const defaultBase =
			branchState === "none" && !base
				? await detectOriginDefaultBranch(machineDeps.git, canonicalRoot)
				: null;
		await addNonPoolWorktree({
			git: machineDeps.git,
			root: canonicalRoot,
			path: worktreePath,
			branch,
			state: branchState,
			base: base ?? defaultBase,
			progress: machineDeps.progress,
		});
		await mergeOriginIfPresent({
			git: machineDeps.git,
			worktreePath,
			branch,
			progress: machineDeps.progress,
		});

		const runnerScriptPath = project
			? writeRunnerFiles({project, root: canonicalRoot, created: worktreePath, branch, pooled: false})
			: null;
		const plan: AddPlan = {
			worktreePath,
			branch,
			root: canonicalRoot,
			title: branch,
			runnerScriptPath,
			createdNewBranch: branchState === "none",
		};
		return finalizeStructuredResult(toAddPayload(plan), output);
	} catch (error) {
		const blocked = toBlockedCommandResult(error, output, {branch, slot_path: slotPath ?? undefined});
		if (blocked) return blocked;
		throw error;
	}
}

async function addPooledWorktree(options: {
	deps: Deps;
	project: ProjectConfig;
	root: string;
	branch: string;
	slotPath: string | null;
	output: OutputMode;
	base: string | null;
	force: boolean;
}): Promise<CommandResult> {
	const {deps, project, root, branch, slotPath, output, base, force} = options;
	let worktrees = await listWorktrees(deps.git, root);
	for (const worktree of worktrees) {
		if (worktree.branch === branch) {
			throw new DuplicateBranchError(`branch ${branch} is already checked out at ${worktree.path}`);
		}
	}
	await ensurePool(project, deps, worktrees);
	worktrees = await listWorktrees(deps.git, root);
	for (const worktree of worktrees) {
		if (worktree.branch === branch) {
			throw new DuplicateBranchError(`branch ${branch} is already checked out at ${worktree.path}`);
		}
	}
	await deps.git.run(["-C", root, "fetch", "origin"]);
	let state = await buildPoolState(project, worktrees, deps.git);

	if (slotPath) {
		const selected = state.slots.find(
			(candidate) => normalizeExistingPath(candidate.path) === normalizeExistingPath(slotPath),
		);
		if (!selected?.exists) throw new UsageError(`pool slot not found: ${slotPath}`);
		if (!selected.initialized) throw new BlockedError(`pool slot is not initialized: ${selected.path}`);
		let targetSlot = selected;
		if (!targetSlot.placeholder) {
			await recycleSlot({git: deps.git, project, root, slotPath: targetSlot.path, force});
			state = await buildPoolState(project, await listWorktrees(deps.git, root), deps.git);
			targetSlot = state.slots.find((candidate) => candidate.index === selected.index) ?? targetSlot;
		}
		return finalizeStructuredResult(
			await allocatePooledSlot({deps, project, root, slot: targetSlot, branch, base}),
			output,
		);
	}

	const slot = state.slots.find(
		(candidate) => candidate.exists && candidate.initialized && candidate.placeholder,
	);
	if (slot) {
		return finalizeStructuredResult(
			await allocatePooledSlot({deps, project, root, slot, branch, base}),
			output,
		);
	}

	if (output.json) {
		return finalizeStructuredResult(
			await toPoolFullPayload(deps.git, state, branch),
			output,
			EXIT_CODES.BLOCKED,
		);
	}

	const selected = await pickFullPoolSlot({deps, state});
	if (!force) {
		const confirmed = await deps.picker.confirm(await buildRecycleConfirmPrompt(deps.git, selected));
		if (!confirmed) throw new PickerCancelled();
	}
	await recycleSlot({git: deps.git, project, root, slotPath: selected.path, force: true});
	state = await buildPoolState(project, await listWorktrees(deps.git, root), deps.git);
	const recycled = state.slots.find((candidate) => candidate.index === selected.index);
	if (!recycled) throw new WktreeError(`pool slot disappeared after recycle: ${selected.path}`);
	return finalizeStructuredResult(
		await allocatePooledSlot({deps, project, root, slot: recycled, branch, base}),
		output,
	);
}

async function allocatePooledSlot(options: {
	deps: Deps;
	project: ProjectConfig;
	root: string;
	slot: Slot;
	branch: string;
	base: string | null;
}): Promise<ReadyAddPayload> {
	const {deps, project, root, slot, branch, base} = options;
	const branchState = await detectBranchState(deps.git, root, branch);
	const defaultBase =
		branchState === "none" && !base ? await detectOriginDefaultBranch(deps.git, root) : null;
	await checkoutBranchInSlot({
		git: deps.git,
		slotPath: slot.path,
		branch,
		state: branchState,
		base: base ?? defaultBase,
		progress: deps.progress,
	});
	await mergeOriginIfPresent({git: deps.git, worktreePath: slot.path, branch, progress: deps.progress});
	const runnerScriptPath = writeRunnerFiles({project, root, created: slot.path, branch, pooled: true});
	const plan: AddPlan = {
		worktreePath: slot.path,
		branch,
		root,
		title: branch,
		runnerScriptPath,
		createdNewBranch: branchState === "none",
	};
	return toAddPayload(plan);
}

async function pickFullPoolSlot(options: {deps: Deps; state: PoolState}): Promise<Slot> {
	const {deps, state} = options;
	const candidates = state.slots.filter((slot) => slot.exists && slot.initialized && !slot.placeholder);
	if (candidates.length === 0) throw new WktreeError("pool full; no recyclable slots found");
	const items: PickerItem[] = [];
	for (const slot of candidates) {
		const risk = await describeSlotRisk(deps.git, slot);
		items.push({
			key: String(slot.index),
			display: `${shellQuote(slot.path)}\tfeat${slot.index}  ${slot.branch ?? "(detached)"}  ${formatRelativeAge(slot.lastCommitIso)}${slot.dirty ? "  [dirty]" : ""}${risk.ahead > 0 ? `  [${risk.ahead} ahead]` : ""}${risk.localOnly ? "  [local-only]" : ""}`,
			preview: buildPickerPreview(),
		});
	}
	const selected = await deps.picker.pick(items, "Select a worktree slot to recycle");
	return candidates.find((slot) => String(slot.index) === selected.key) ?? candidates[0];
}

async function describeSlotRisk(
	git: GitRunner,
	slot: Slot,
): Promise<{ahead: number; behind: number; localOnly: boolean}> {
	const upstream = await git.runRaw(["-C", slot.path, "rev-parse", "--abbrev-ref", "@{upstream}"]);
	if (upstream.exitCode !== 0 || upstream.stdout.trim() === "") return {ahead: 0, behind: 0, localOnly: true};
	const counts = await git.runRaw([
		"-C",
		slot.path,
		"rev-list",
		"--left-right",
		"--count",
		`${upstream.stdout.trim()}...HEAD`,
	]);
	const [behind, ahead] = counts.stdout
		.trim()
		.split(/\s+/)
		.map((value) => Number(value));
	return {ahead: ahead || 0, behind: behind || 0, localOnly: false};
}

function buildPickerPreview(): string {
	return `slot={1}; counts=$(git -C "$slot" rev-list --left-right --count @{upstream}...HEAD 2>/dev/null); if [ $? -ne 0 ] || [ -z "$counts" ]; then echo '⚠ local-only branch'; else ahead=$(echo "$counts" | awk '{print $2}'); [ "$ahead" -gt 0 ] 2>/dev/null && echo "⚠ $ahead unpushed commits will be lost"; echo "upstream: $(echo "$counts" | awk '{print $1}') behind, $ahead ahead"; fi; git -C "$slot" log -5 --format='%h %s'; git -C "$slot" status --porcelain | head`;
}

async function buildRecycleConfirmPrompt(git: GitRunner, slot: Slot): Promise<string> {
	const risk = await describeSlotRisk(git, slot);
	const warnings = [
		slot.dirty ? "dirty changes will be lost" : null,
		risk.localOnly ? "local-only branch" : null,
		risk.ahead > 0 ? `⚠ ${risk.ahead} unpushed commits will be lost` : null,
	]
		.filter(Boolean)
		.join("; ");
	return `Recycle feat${slot.index} (${slot.branch ?? "detached"})${warnings ? `: ${warnings}` : ""}? [y/N] `;
}

function formatRelativeAge(iso: string | null): string {
	if (!iso) return "unknown";
	const ageMs = Date.now() - Date.parse(iso);
	const days = Math.floor(ageMs / 86_400_000);
	if (days > 0) return `${days}d ago`;
	const hours = Math.floor(ageMs / 3_600_000);
	return hours > 0 ? `${hours}h ago` : "now";
}

async function ensureCommand(args: string[], deps: Deps) {
	const opts = parseOptions(args);
	const cwd = requireOption(opts, "cwd");
	const worktrees = await listWorktrees(deps.git, cwd);
	const canonical = worktrees.find((worktree) => worktree.canonical);
	if (!canonical) throw new WktreeError("couldn't determine canonical worktree");
	const project = findProjectForRoot(readConfig(), canonical.path);
	if (project?.poolSize) await ensurePool(project, deps, worktrees);
	return {exitCode: 0};
}

async function statusCommand(args: string[], deps: Deps) {
	const opts = parseOptions(args);
	const cwd = requireOption(opts, "cwd");
	const worktrees = await listWorktrees(deps.git, cwd);
	const canonical = worktrees.find((worktree) => worktree.canonical);
	if (!canonical) throw new WktreeError("couldn't determine canonical worktree");
	const project = findProjectForRoot(readConfig(), canonical.path);
	if (!project?.poolSize) {
		return {
			stdout: `${JSON.stringify({root: canonical.path, trunk: null, size: 0, slots: []}, null, 2)}\n`,
			exitCode: 0,
		};
	}
	const state = await buildPoolState(project, worktrees, deps.git);
	return {stdout: `${JSON.stringify(state, null, 2)}\n`, exitCode: 0};
}

export async function buildPoolState(
	cfg: ProjectConfig,
	worktrees: Worktree[],
	git: GitRunner,
): Promise<PoolState> {
	if (!cfg.poolSize) throw new ConfigError(`project ${cfg.name ?? cfg.root} is not pooled`);
	const root = normalizeExistingPath(cfg.root);
	const trunk = await detectOriginDefaultBranch(git, root);
	const slots = await Promise.all(
		Array.from({length: cfg.poolSize}, (_, offset) =>
			buildPoolSlotState({
				index: offset + 1,
				root,
				worktrees,
				git,
			}),
		),
	);
	return {root, trunk, size: cfg.poolSize, slots};
}

async function buildPoolSlotState(options: {
	index: number;
	root: string;
	worktrees: Worktree[];
	git: GitRunner;
}): Promise<Slot> {
	const {index, root, worktrees, git} = options;
	const slotPath = `${root}__feat${index}`;
	const worktree = worktrees.find((candidate) => normalizeExistingPath(candidate.path) === slotPath);
	if (!worktree) {
		return {
			index,
			path: slotPath,
			exists: false,
			branch: null,
			placeholder: false,
			dirty: false,
			lastCommitIso: null,
			lastCommitSubject: null,
			initialized: false,
		};
	}

	const branch = worktree.branch;
	const [status, log, marker] = await Promise.all([
		git.runRaw(["-C", slotPath, "status", "--porcelain=v1"]),
		git.runRaw(["-C", slotPath, "log", "-1", "--format=%cI%x1f%s"]),
		git.runRaw(["-C", slotPath, "rev-parse", "--git-path", "wk-pool-initialized"]),
	]);
	const [lastCommitIso, lastCommitSubject] =
		log.exitCode === 0 && log.stdout.trim() !== "" ? log.stdout.trimEnd().split("\x1f", 2) : [null, null];
	return {
		index,
		path: slotPath,
		exists: true,
		branch,
		placeholder: branch === `wk-pool/feat${index}`,
		dirty: status.stdout.trim() !== "",
		lastCommitIso,
		lastCommitSubject,
		initialized: marker.exitCode === 0 && existsSync(resolve(slotPath, marker.stdout.trim())),
	};
}

async function removeCommand(args: string[], deps: Deps) {
	const opts = parseOptions(args);
	const cwd = requireOption(opts, "cwd");
	const output = parseOutputMode(opts);
	const machineDeps = withMachineJsonProgress(deps, output);
	const branch = typeof opts.branch === "string" ? opts.branch : null;
	const self = typeof opts.self === "string" ? opts.self : null;
	const force = opts.force === true;
	if ((branch && self) || (!branch && !self)) {
		throw new UsageError("provide exactly one of --branch or --self");
	}

	let targetPath: string | undefined;
	try {
		let worktrees = await listWorktrees(machineDeps.git, cwd);
		const canonical = worktrees.find((worktree) => worktree.canonical);
		if (!canonical) throw new WktreeError("couldn't determine canonical worktree");
		const project = findProjectForRoot(readConfig(), canonical.path);
		if (project?.poolSize) {
			await ensurePool(project, machineDeps, worktrees);
			worktrees = await listWorktrees(machineDeps.git, cwd);
		}
		const target = resolveRemoveTarget(worktrees, canonical.path, {branch, self});
		targetPath = target.path;
		if (normalizeExistingPath(target.path) === normalizeExistingPath(canonical.path)) {
			throw new CanonicalRootError("refusing to remove canonical root");
		}
		if (project?.poolSize && target.pool) {
			await recycleSlot({git: machineDeps.git, project, root: canonical.path, slotPath: target.path, force});
			return finalizeStructuredResult(toRemovePayload({worktreePath: target.path, removed: false}), output);
		}

		if (target.branch && !force)
			await assertBranchSafelyDeletable(machineDeps.git, canonical.path, target.branch);
		await machineDeps.git.run([
			"-C",
			canonical.path,
			"worktree",
			"remove",
			...(force ? ["--force"] : []),
			target.path,
		]);
		if (target.branch) {
			await machineDeps.git.run(["-C", canonical.path, "branch", force ? "-D" : "-d", target.branch]);
		}

		return finalizeStructuredResult(
			toRemovePayload({worktreePath: target.path, removed: !existsSync(target.path)}),
			output,
		);
	} catch (error) {
		const blocked = toBlockedCommandResult(error, output, {
			branch: branch ?? undefined,
			worktree_path: targetPath,
		});
		if (blocked) return blocked;
		throw error;
	}
}

async function recycleCommand(args: string[], deps: Deps) {
	const opts = parseOptions(args);
	const cwd = requireOption(opts, "cwd");
	const slotPath = requireOption(opts, "slot");
	const force = opts.force === true;
	const root = await resolveCanonicalRoot(deps.git, cwd);
	const project = findProjectForRoot(readConfig(), root);
	if (!project?.poolSize) throw new UsageError("recycle requires a pooled project");
	await recycleSlot({git: deps.git, project, root, slotPath, force});
	return {exitCode: 0};
}

async function recycleSlot(options: {
	git: GitRunner;
	project: ProjectConfig;
	root: string;
	slotPath: string;
	force: boolean;
}): Promise<void> {
	const {git, project, root, slotPath, force} = options;
	const normalizedSlotPath = normalizeExistingPath(slotPath);
	const worktrees = await listWorktrees(git, root);
	const state = await buildPoolState(project, worktrees, git);
	const slot = state.slots.find((candidate) => normalizeExistingPath(candidate.path) === normalizedSlotPath);
	if (!slot?.exists) throw new UsageError(`pool slot not found: ${slotPath}`);
	const placeholderBranch = `wk-pool/feat${slot.index}`;
	const oldBranch = slot.branch;
	await git.run(["-C", root, "fetch", "origin"]);
	if (force) {
		await git.run(["-C", slot.path, "checkout", "-f", "-B", placeholderBranch, `origin/${state.trunk}`]);
		await git.run(["-C", slot.path, "reset", "--hard", placeholderBranch]);
		await git.run(["-C", slot.path, "clean", "-fd"]);
		if (oldBranch && oldBranch !== placeholderBranch) {
			await git.run(["-C", root, "branch", "-D", oldBranch]);
			await killTmuxSessionForPath(slot.path);
		}
		return;
	}

	const dirty = (await git.runRaw(["-C", slot.path, "status", "--porcelain=v1"])).stdout.trim() !== "";
	if (dirty) throw new DirtySlotError(`slot ${slot.path} has uncommitted changes; pass --force to recycle`);
	if (oldBranch && oldBranch !== placeholderBranch) await assertBranchHasMergedUpstream(git, root, oldBranch);
	await git.run(["-C", slot.path, "checkout", "-B", placeholderBranch, `origin/${state.trunk}`]);
	if (oldBranch && oldBranch !== placeholderBranch) {
		await git.run(["-C", root, "branch", "-d", oldBranch]);
		await killTmuxSessionForPath(slot.path);
	}
}

async function assertBranchHasMergedUpstream(git: GitRunner, root: string, branch: string): Promise<void> {
	const upstream = await git.runRaw(["-C", root, "rev-parse", "--abbrev-ref", `${branch}@{upstream}`]);
	if (upstream.exitCode !== 0 || upstream.stdout.trim() === "") {
		throw new UnmergedBranchError(`branch ${branch} has no upstream; pass --force to recycle`);
	}
	const upstreamRef = upstream.stdout.trim();
	const merged = await git.runRaw(["-C", root, "merge-base", "--is-ancestor", branch, upstreamRef]);
	if (merged.exitCode !== 0) {
		throw new UnmergedBranchError(
			`branch ${branch} is not merged to ${upstreamRef}; pass --force to recycle`,
		);
	}
}

async function ensurePool(
	project: ProjectConfig,
	deps: Deps,
	initialWorktrees?: Worktree[],
): Promise<PoolState> {
	if (!project.poolSize) {
		return {root: normalizeExistingPath(project.root), trunk: "", size: 0, slots: []};
	}
	const root = normalizeExistingPath(project.root);
	let worktrees = initialWorktrees ?? (await listWorktrees(deps.git, root));
	let state = await buildPoolState(project, worktrees, deps.git);
	const needsWork = state.slots.some((slot) => !slot.exists || !slot.initialized);
	if (!needsWork) return state;

	await deps.git.run(["-C", root, "fetch", "origin"]);
	for (const slot of state.slots) {
		if (slot.exists && slot.initialized) continue;
		const branch = `wk-pool/feat${slot.index}`;
		deps.progress.banner(`[wk-pool] initializing feat${slot.index}…`);
		await ensurePlaceholderBranch({git: deps.git, root, branch, trunk: state.trunk});
		const createdWorktree = !slot.exists;
		if (createdWorktree) await deps.git.run(["-C", root, "worktree", "add", slot.path, branch]);
		const runnerScriptPath = writeRunnerFiles({
			project,
			root,
			created: slot.path,
			branch,
			pooled: true,
		});
		try {
			await deps.hooks.runInline(runnerScriptPath, slot.path, {}, (stream, line) =>
				deps.progress.stream(stream, line),
			);
		} catch (error) {
			if (createdWorktree) await deps.git.runRaw(["-C", root, "worktree", "remove", "--force", slot.path]);
			throw error;
		}
		worktrees = await listWorktrees(deps.git, root);
		state = await buildPoolState(project, worktrees, deps.git);
	}
	return state;
}

async function ensurePlaceholderBranch(options: {
	git: GitRunner;
	root: string;
	branch: string;
	trunk: string;
}): Promise<void> {
	const {git, root, branch, trunk} = options;
	const exists =
		(await git.runRaw(["-C", root, "show-ref", "--verify", `refs/heads/${branch}`])).exitCode === 0;
	if (!exists) await git.run(["-C", root, "branch", branch, `origin/${trunk}`]);
}

function resolveRemoveTarget(
	worktrees: Worktree[],
	canonicalRoot: string,
	selector: {branch: string | null; self: string | null},
): Worktree {
	const target = selector.branch
		? worktrees.find((worktree) => worktree.branch === selector.branch)
		: worktrees.find(
				(worktree) => normalizeExistingPath(worktree.path) === normalizeExistingPath(selector.self ?? ""),
			);
	if (!target) {
		if (selector.branch) throw new BlockedError(`no worktree found for branch ${selector.branch}`);
		throw new UsageError("target is not a git worktree");
	}
	if (normalizeExistingPath(target.path) === normalizeExistingPath(canonicalRoot))
		throw new CanonicalRootError("refusing to remove canonical root");
	return target;
}

async function assertBranchSafelyDeletable(git: GitRunner, root: string, branch: string): Promise<void> {
	const upstream = await git.runRaw(["-C", root, "rev-parse", "--abbrev-ref", `${branch}@{upstream}`]);
	const mergeTarget = upstream.exitCode === 0 ? upstream.stdout.trim() : "HEAD";
	const merged = await git.runRaw(["-C", root, "merge-base", "--is-ancestor", branch, mergeTarget]);
	if (merged.exitCode !== 0)
		throw new UnmergedBranchError(`branch ${branch} is not merged; pass --force to remove it`);
}

function parseOptions(args: string[]) {
	const opts: Record<string, string | boolean> = {};
	for (let index = 0; index < args.length; index++) {
		const arg = args[index];
		if (arg === "--json" || arg === "--force") {
			opts[arg.slice(2)] = true;
			continue;
		}
		if (arg?.startsWith("--")) {
			const key = arg.slice(2);
			const value = args[index + 1];
			if (value === undefined || value.startsWith("--")) throw new UsageError(`missing value for --${key}`);
			opts[key] = value;
			index++;
		}
	}
	return opts;
}

function requireOption(opts: Record<string, string | boolean>, key: string): string {
	const value = opts[key];
	if (typeof value !== "string" || value === "") throw new UsageError(`missing required --${key}`);
	return value;
}

type BranchState = "local" | "remote" | "local-remote" | "none";

async function detectBranchState(git: GitRunner, root: string, branch: string): Promise<BranchState> {
	const refs = await git.runRaw([
		"-C",
		root,
		"for-each-ref",
		"--format=%(refname)",
		"refs/heads",
		"refs/remotes/origin",
	]);
	const lines = refs.stdout.split("\n");
	const local = lines.includes(`refs/heads/${branch}`);
	const remote = lines.includes(`refs/remotes/origin/${branch}`);
	if (local && remote) return "local-remote";
	if (local) return "local";
	if (remote) return "remote";
	return "none";
}

async function detectOriginDefaultBranch(git: GitRunner, root: string): Promise<string> {
	const symbolic = await git.runRaw(["-C", root, "symbolic-ref", "refs/remotes/origin/HEAD"]);
	const fromSymbolic = symbolic.exitCode === 0 ? parseTrunkFromSymbolicRef(symbolic.stdout) : null;
	if (fromSymbolic) return fromSymbolic;
	const remoteShow = await git.runRaw(["-C", root, "remote", "show", "origin"]);
	const fromRemoteShow = remoteShow.exitCode === 0 ? parseTrunkFromRemoteShow(remoteShow.stdout) : null;
	if (fromRemoteShow) return fromRemoteShow;
	throw new TrunkDetectionError("couldn't determine origin default branch");
}

async function addNonPoolWorktree(options: {
	git: GitRunner;
	root: string;
	path: string;
	branch: string;
	state: BranchState;
	base: string | null;
	progress: ProgressReporter;
}): Promise<void> {
	const {git, root, path, branch, state, base, progress} = options;
	if (state !== "none" && base) progress.error("--base ignored: branch already exists");
	if (state === "local" || state === "local-remote") {
		await git.run(["-C", root, "worktree", "add", path, branch]);
		return;
	}
	if (state === "remote") {
		await git.run(["-C", root, "worktree", "add", "--no-track", "-b", branch, path, `origin/${branch}`]);
		return;
	}
	const startPoint = base ? await resolveBaseRef(git, root, base) : "HEAD";
	await git.run(["-C", root, "worktree", "add", "--no-track", "-b", branch, path, startPoint]);
}

async function resolveBaseRef(git: GitRunner, root: string, base: string): Promise<string> {
	const local = (await git.runRaw(["-C", root, "show-ref", "--verify", `refs/heads/${base}`])).exitCode === 0;
	if (local) return base;
	const remote =
		(await git.runRaw(["-C", root, "show-ref", "--verify", `refs/remotes/origin/${base}`])).exitCode === 0;
	if (remote) return `origin/${base}`;
	throw new UsageError(`base branch not found locally or on origin: ${base}`);
}

async function checkoutBranchInSlot(options: {
	git: GitRunner;
	slotPath: string;
	branch: string;
	state: BranchState;
	base: string | null;
	progress: ProgressReporter;
}): Promise<void> {
	const {git, slotPath, branch, state, base, progress} = options;
	if (state !== "none" && base) progress.error("--base ignored: branch already exists");
	if (state === "local" || state === "local-remote") {
		await git.run(["-C", slotPath, "checkout", branch]);
		return;
	}
	if (state === "remote") {
		await git.run(["-C", slotPath, "checkout", "--no-track", "-B", branch, `origin/${branch}`]);
		return;
	}
	const startPoint = base ? await resolveBaseRef(git, slotPath, base) : "HEAD";
	await git.run(["-C", slotPath, "checkout", "--no-track", "-B", branch, startPoint]);
}

async function mergeOriginIfPresent(options: {
	git: GitRunner;
	worktreePath: string;
	branch: string;
	progress: ProgressReporter;
}): Promise<void> {
	const {git, worktreePath, branch, progress} = options;
	const remoteExists =
		(await git.runRaw(["-C", worktreePath, "show-ref", "--verify", `refs/remotes/origin/${branch}`]))
			.exitCode === 0;
	if (!remoteExists) return;
	const merge = await git.runRaw(["-C", worktreePath, "merge", "--ff-only", `origin/${branch}`]);
	if (merge.exitCode !== 0)
		progress.error(`warning: couldn't fast-forward from origin/${branch}; preserving local work`);
}

function writeRunnerFiles(options: {
	project: ProjectConfig;
	root: string;
	created: string;
	branch: string;
	pooled: boolean;
}): string {
	const {project, root, created, pooled} = options;
	const session = sessionNameForWorktreePath(created);
	const sessionDir = resolve(homedir(), ".config", "kitty", "sessions");
	mkdirSync(sessionDir, {recursive: true});
	const hookBodyPath = resolve(sessionDir, `${session}.hook.sh`);
	const runnerScriptPath = resolve(sessionDir, `${session}.runner.sh`);
	writeFileSync(hookBodyPath, `#!/usr/bin/env bash\nset -euo pipefail\n${project.command}\n`, {mode: 0o755});
	writeFileSync(
		runnerScriptPath,
		generateRunnerScript({projectName: project.name ?? basename(root), root, created, hookBodyPath, pooled}),
		{mode: 0o755},
	);
	return runnerScriptPath;
}

function parseOutputMode(opts: Record<string, string | boolean>): OutputMode {
	return {
		json: opts.json === true,
	};
}

function finalizeStructuredResult(
	payload: ReadyAddPayload | ReadyRemovePayload | PoolFullPayload | BlockedPayload,
	output: OutputMode,
	exitCode: number = EXIT_CODES.SUCCESS,
): CommandResult {
	return {
		stdout: output.json ? `${JSON.stringify(payload, null, 2)}\n` : undefined,
		exitCode,
	};
}

function toBlockedCommandResult(
	error: unknown,
	output: OutputMode,
	context: Omit<BlockedPayload, "kind" | "reason" | "message">,
): CommandResult | null {
	if (!output.json || !(error instanceof WktreeError)) return null;
	const payload = toBlockedPayload(error, context);
	return payload ? finalizeStructuredResult(payload, output, error.exitCode) : null;
}

function toBlockedPayload(
	error: WktreeError,
	context: Omit<BlockedPayload, "kind" | "reason" | "message">,
): BlockedPayload | null {
	if (!(error instanceof BlockedError) && !(error instanceof UnsafeOperationError)) return null;
	let reason = "blocked";
	if (error instanceof DuplicateBranchError) reason = "duplicate_branch";
	else if (error instanceof DirtySlotError) reason = "dirty_slot";
	else if (error instanceof UnmergedBranchError) reason = "unmerged_branch";
	else if (error instanceof CanonicalRootError) reason = "canonical_root";
	else if (error.exitCode === EXIT_CODES.UNSAFE) reason = "unsafe";
	return {kind: "blocked", reason, message: error.message, ...context};
}

function withMachineJsonProgress(deps: Deps, output: OutputMode): Deps {
	if (!output.json) return deps;
	return {
		...deps,
		progress: {
			banner: (line: string) => deps.progress.banner(line),
			stream: (_stream: "stdout" | "stderr", line: string) => deps.progress.error(line),
			error: (msg: string) => deps.progress.error(msg),
		},
	};
}

function toAddPayload(plan: AddPlan): ReadyAddPayload {
	return {
		kind: "ready",
		worktree_path: plan.worktreePath,
		branch: plan.branch,
		root: plan.root,
		title: plan.title,
		session: toSessionInfo(plan.worktreePath),
		runner_script_path: plan.runnerScriptPath,
		created_new_branch: plan.createdNewBranch,
	};
}

function toRemovePayload(plan: RemovePlan): ReadyRemovePayload {
	return {
		kind: "ready",
		worktree_path: plan.worktreePath,
		removed: plan.removed,
		session: toSessionInfo(plan.worktreePath),
	};
}

async function toPoolFullPayload(git: GitRunner, state: PoolState, branch: string): Promise<PoolFullPayload> {
	const candidates = state.slots.filter((slot) => slot.exists && slot.initialized && !slot.placeholder);
	return {
		kind: "pool_full",
		root: state.root,
		branch,
		candidates: await Promise.all(
			candidates.map(async (slot) => {
				const risk = await describeSlotRisk(git, slot);
				return {
					slot: slot.index,
					path: slot.path,
					branch: slot.branch,
					dirty: slot.dirty,
					ahead: risk.ahead,
					local_only: risk.localOnly,
					last_commit_iso: slot.lastCommitIso,
					last_commit_subject: slot.lastCommitSubject,
				};
			}),
		),
	};
}

function sessionNameForWorktreePath(worktreePath: string): string {
	return basename(worktreePath).replaceAll(".", "_");
}

function toSessionInfo(worktreePath: string): SessionInfo {
	return {
		name: sessionNameForWorktreePath(worktreePath),
		path: worktreePath,
	};
}

async function killTmuxSessionForPath(worktreePath: string): Promise<void> {
	const proc = Bun.spawn(["tmux", "kill-session", "-t", `=${sessionNameForWorktreePath(worktreePath)}`], {
		stdout: "ignore",
		stderr: "ignore",
	});
	await proc.exited.catch(() => undefined);
}

async function listWorktrees(git: GitRunner, cwd: string): Promise<Worktree[]> {
	const result = await git.run(["-C", cwd, "worktree", "list", "--porcelain"]);
	return applyWorktreeMetadata(parseWorktreeList(result.stdout), result.stdout);
}

async function resolveCanonicalRoot(git: GitRunner, cwd: string): Promise<string> {
	const worktrees = await listWorktrees(git, cwd);
	const canonical = worktrees.find((worktree) => worktree.canonical);
	if (!canonical) throw new WktreeError("couldn't determine canonical worktree");
	return canonical.path;
}

type WorktreeMetadata = {
	locked: boolean;
	lockReason: string | null;
	prunable: boolean;
	prunableReason: string | null;
};

const worktreeMetadata = new WeakMap<Worktree, WorktreeMetadata>();

function applyWorktreeMetadata(worktrees: Worktree[], porcelainOutput: string): Worktree[] {
	const records = porcelainOutput
		.trim()
		.split(/\n{2,}/)
		.map((record) => record.trim())
		.filter(Boolean);

	for (const [index, record] of records.entries()) {
		const worktree = worktrees[index];
		if (!worktree) continue;
		const metadata: WorktreeMetadata = {
			locked: false,
			lockReason: null,
			prunable: false,
			prunableReason: null,
		};
		for (const line of record.split("\n")) {
			if (line === "locked") metadata.locked = true;
			else if (line.startsWith("locked ")) {
				metadata.locked = true;
				metadata.lockReason = line.slice("locked ".length);
			} else if (line === "prunable") metadata.prunable = true;
			else if (line.startsWith("prunable ")) {
				metadata.prunable = true;
				metadata.prunableReason = line.slice("prunable ".length);
			}
		}
		worktreeMetadata.set(worktree, metadata);
	}

	return worktrees;
}

function getWorktreeMetadata(worktree: Worktree): WorktreeMetadata {
	return (
		worktreeMetadata.get(worktree) ?? {locked: false, lockReason: null, prunable: false, prunableReason: null}
	);
}

function toListJson(worktree: Worktree) {
	const metadata = getWorktreeMetadata(worktree);
	return {
		path: worktree.path,
		head: worktree.head,
		branch: worktree.branch,
		branch_ref: worktree.branchRef,
		detached: worktree.detached,
		bare: worktree.bare,
		locked: metadata.locked,
		lock_reason: metadata.lockReason,
		prunable: metadata.prunable,
		prunable_reason: metadata.prunableReason,
		canonical: worktree.canonical,
		pool: worktree.pool,
		session: toSessionInfo(worktree.path),
	};
}

function formatWorktreeList(worktrees: Worktree[]): string {
	return worktrees
		.map((worktree) => {
			const head = worktree.head ? worktree.head.slice(0, 7) : "-";
			const branch = worktree.branch ? `[${worktree.branch}]` : worktree.detached ? "(detached)" : "";
			const flags = [branch, worktree.canonical ? "[canonical]" : null, formatPool(worktree.pool)]
				.filter(Boolean)
				.join(" ");
			return `${worktree.path}  ${head}${flags ? ` ${flags}` : ""}`;
		})
		.join("\n")
		.concat(worktrees.length > 0 ? "\n" : "");
}

function formatPool(pool: Worktree["pool"]): string | null {
	if (!pool) return null;
	return pool.placeholder ? "[pool:free]" : `[pool:feat${pool.index}]`;
}

function encodeBranch(branch: string): string {
	const parts = branch.split("/").filter((part) => part !== "");
	if (parts.length === 0) throw new UsageError(`invalid branch name: ${branch}`);
	return parts.join("--");
}

export function generateRunnerScript(spec: RunnerScriptSpec): string {
	const lines = [
		"#!/usr/bin/env bash",
		"set -euo pipefail",
		`export WK_ROOT=${shellQuote(spec.root)}`,
		`export WK_CREATED=${shellQuote(spec.created)}`,
		`echo ${shellQuote(`project: ${spec.projectName}`)}`,
		`bash ${shellQuote(spec.hookBodyPath)}`,
	];
	if (spec.pooled) {
		lines.push(': > "$(git -C "$WK_CREATED" rev-parse --git-path wk-pool-initialized)"');
	}
	return `${lines.join("\n")}\n`;
}

function shellQuote(value: string): string {
	return `'${value.replaceAll("'", "'\\''")}'`;
}

function readConfig(): TreesConfig {
	const configHome = process.env.XDG_CONFIG_HOME ?? resolve(homedir(), ".config");
	const configPath = resolve(configHome, "ct-worktrees", "trees.toml");
	if (!existsSync(configPath)) return {projects: []};
	return parseConfig(readFileSync(configPath, "utf8"));
}

function findProjectForRoot(config: TreesConfig, root: string): ProjectConfig | undefined {
	const comparableRoot = normalizeExistingPath(root);
	return config.projects.find((candidate) => normalizeExistingPath(candidate.root) === comparableRoot);
}

function normalizeExistingPath(path: string): string {
	return existsSync(path) ? realpathSync(path) : path;
}

function parsePoolSize(value: unknown, label: string): number | null {
	if (value === undefined) return null;
	if (typeof value !== "number" || !Number.isInteger(value) || value < 1) {
		throw new ConfigError(
			`${label}: optional field \`pool_size\` must be an integer greater than or equal to 1`,
		);
	}
	return value;
}

function expandPath(path: string): string {
	if (path === "~") return homedir();
	if (path.startsWith("~/")) return resolve(homedir(), path.slice(2));
	return resolve(path);
}

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

export class LiveHookRunner implements HookRunner {
	runInline = async (...args: Parameters<HookRunner["runInline"]>): Promise<void> => {
		const [scriptPath, cwd, env, onLine] = args;
		const proc = Bun.spawn(["bash", scriptPath], {
			cwd,
			env: {...process.env, ...env},
			stdout: "pipe",
			stderr: "pipe",
		});

		const [stdout, stderr, exitCode] = await Promise.all([
			pumpLines(proc.stdout, "stdout", onLine),
			pumpLines(proc.stderr, "stderr", onLine),
			proc.exited,
		]);
		await Promise.all([stdout, stderr]);
		if (exitCode !== 0) throw new HookError(exitCode, cwd);
	};
}

async function pumpLines(
	stream: ReadableStream<Uint8Array>,
	name: "stdout" | "stderr",
	onLine: (stream: "stdout" | "stderr", line: string) => void,
): Promise<void> {
	const reader = stream.pipeThrough(new TextDecoderStream()).getReader();
	let buffer = "";
	while (true) {
		const {value, done} = await reader.read();
		if (done) break;
		buffer += value;
		const lines = buffer.split(/\r?\n/);
		buffer = lines.pop() ?? "";
		for (const line of lines) onLine(name, line);
	}
	if (buffer !== "") onLine(name, buffer);
}

class LivePickerService implements PickerService {
	async pick(items: PickerItem[], header: string): Promise<PickerItem> {
		const byDisplay = new Map(items.map((item) => [item.display, item]));
		const selection = await fzf(
			items.map((item) => item.display),
			{header, preview: items[0]?.preview, withNth: "2..", tty: true},
		);
		const item = byDisplay.get(selection.trim());
		if (!item) throw new PickerCancelled();
		return item;
	}

	async confirm(prompt: string): Promise<boolean> {
		const tty = openSync("/dev/tty", "r+");
		try {
			writeFileSync(tty, prompt);
			const answer = Buffer.alloc(1);
			readSync(tty, answer, 0, 1, null);
			writeFileSync(tty, "\n");
			return answer.toString() === "y" || answer.toString() === "Y";
		} finally {
			closeSync(tty);
		}
	}
}

class ConsoleProgressReporter implements ProgressReporter {
	banner(line: string): void {
		process.stderr.write(`${line}\n`);
	}

	stream(stream: "stdout" | "stderr", line: string): void {
		const target = stream === "stdout" ? process.stdout : process.stderr;
		target.write(`${line}\n`);
	}

	error(msg: string): void {
		process.stderr.write(`${msg}\n`);
	}
}

if (import.meta.main) {
	main();
}
