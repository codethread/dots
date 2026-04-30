// :module: Single-shot GitLab pipeline monitor for current branch MR

import {$} from "bun";
import {parseArgs} from "util";

interface Pipeline {
	id: number;
	status: string;
	ref: string;
	web_url: string;
	updated_at: string;
}

interface Job {
	id: number;
	name: string;
	status: string;
	stage: string;
	web_url: string;
	allow_failure: boolean;
}

interface MR {
	iid: number;
	title: string;
	web_url: string;
	source_branch: string;
}

export interface AwaitOptions {
	branch?: string;
	username?: string;
	maxWait?: number;
	pollInterval?: number;
}

export interface AwaitResult {
	status: "success" | "failed" | "canceled" | "timeout";
	pipelineId?: number;
	webUrl?: string;
	message: string;
}

const TERMINAL_STATUSES = new Set(["success", "failed", "canceled", "skipped"]);
const RUNNING_STATUSES = new Set([
	"running",
	"pending",
	"created",
	"waiting_for_resource",
	"preparing",
	"scheduled",
	"manual",
	"blocked",
]);

const colors = {
	RED: "\x1b[0;31m",
	GREEN: "\x1b[0;32m",
	YELLOW: "\x1b[1;33m",
	BLUE: "\x1b[0;34m",
	CYAN: "\x1b[0;36m",
	BOLD: "\x1b[1m",
	NC: "\x1b[0m",
};

function showHelp() {
	console.log(`git-pipeline--await - Watch the current branch's MR pipeline to completion

Usage: git-pipeline--await [options]

Options:
    -h, --help              Show this help message
    -b, --branch BRANCH     Branch to watch (default: current git branch)
    -u, --username USER     GitLab username (default: adam.hall)
    -w, --max-wait SECONDS  Max seconds to wait for pipeline to start (default: 60)
    -i, --interval SECONDS  Poll interval in seconds (default: 10)

Description:
    Finds the open MR for the current branch, waits up to --max-wait seconds
    for its pipeline to start, then polls job status until complete.
    Exits 0 on pipeline success, 1 on failure, cancellation, or timeout.

Examples:
    git-pipeline--await                    # Watch current branch MR pipeline
    git-pipeline--await -b feature/foo     # Watch specific branch
    git-pipeline--await -w 120 -i 5       # Wait longer, poll faster
`);
	process.exit(0);
}

async function main() {
	const {values} = parseArgs({
		args: Bun.argv.slice(2),
		options: {
			branch: {type: "string", short: "b"},
			username: {type: "string", short: "u"},
			"max-wait": {type: "string", short: "w"},
			interval: {type: "string", short: "i"},
			help: {type: "boolean", short: "h"},
		},
		strict: false,
	});

	if (values.help) showHelp();

	const branch = values.branch as string | undefined;
	const username = values.username as string | undefined;
	const maxWaitRaw = values["max-wait"] as string | undefined;
	const intervalRaw = values.interval as string | undefined;

	const options: AwaitOptions = {
		branch,
		username: username ?? "adam.hall",
		maxWait: maxWaitRaw ? parseInt(maxWaitRaw, 10) : 60,
		pollInterval: intervalRaw ? parseInt(intervalRaw, 10) : 10,
	};

	try {
		const result = await gitPipelineAwaitLib(options);
		console.log(`\n${result.message}`);
		process.exit(result.status === "success" ? 0 : 1);
	} catch (err) {
		console.error(`${colors.RED}Error: ${err}${colors.NC}`);
		process.exit(1);
	}
}

interface ResolvedOptions {
	branch: string;
	username: string;
	maxWait: number;
	pollInterval: number;
}

export async function gitPipelineAwaitLib(options: AwaitOptions = {}): Promise<AwaitResult> {
	const resolved: ResolvedOptions = {
		branch: options.branch ?? (await getCurrentBranch()),
		username: options.username ?? "adam.hall",
		maxWait: options.maxWait ?? 60,
		pollInterval: options.pollInterval ?? 10,
	};

	log("INFO", `Watching pipeline for branch: ${colors.BOLD}${resolved.branch}${colors.NC}`);

	await validateDependencies();

	const mr = await findMRForBranch(resolved.branch);
	if (!mr) {
		return {status: "timeout", message: `No open MR found for branch "${resolved.branch}"`};
	}

	log("INFO", `Found MR !${mr.iid}: ${mr.title}`);

	const pipeline = await waitForMRPipeline(mr.iid, resolved);
	if (!pipeline) {
		return {status: "timeout", message: `No pipeline started for MR !${mr.iid} within ${resolved.maxWait}s`};
	}

	log("INFO", `${colors.CYAN}Pipeline #${pipeline.id}${colors.NC} — ${pipeline.web_url}`);
	console.log();

	return await watchPipeline(pipeline, resolved.pollInterval);
}

async function waitForMRPipeline(mrIid: number, opts: ResolvedOptions): Promise<Pipeline | null> {
	const deadline = Date.now() + opts.maxWait * 1000;
	let waited = 0;

	while (Date.now() < deadline) {
		// Return the newest pipeline regardless of state — if it's already terminal,
		// watchPipeline will detect that and return immediately rather than poll
		const pipeline = await findLatestMRPipeline(mrIid);
		if (pipeline) return pipeline;

		if (waited === 0) {
			log("INFO", `No pipeline yet, waiting up to ${opts.maxWait}s for CI to start...`);
		}

		await sleep(opts.pollInterval * 1000);
		waited += opts.pollInterval;
	}

	return null;
}

async function watchPipeline(pipeline: Pipeline, pollInterval: number): Promise<AwaitResult> {
	const jobStatuses = new Map<number, string>();

	// Prime the map with existing jobs so first poll only reports new transitions
	const initialJobs = await getPipelineJobs(pipeline.id);
	for (const job of initialJobs) {
		jobStatuses.set(job.id, job.status);
	}

	while (true) {
		const [current, jobs] = await Promise.all([getPipelineStatus(pipeline.id), getPipelineJobs(pipeline.id)]);

		reportJobChanges(jobs, jobStatuses);

		if (!RUNNING_STATUSES.has(current.status)) {
			const success = current.status === "success";
			const icon = getStatusEmoji(current.status);
			const color = success ? colors.GREEN : colors.RED;
			return {
				status: current.status as AwaitResult["status"],
				pipelineId: pipeline.id,
				webUrl: pipeline.web_url,
				message: `${color}${icon} Pipeline #${pipeline.id} ${current.status}${colors.NC}`,
			};
		}

		await sleep(pollInterval * 1000);
	}
}

function reportJobChanges(jobs: Job[], known: Map<number, string>) {
	for (const job of jobs) {
		const prev = known.get(job.id);
		if (prev !== job.status && TERMINAL_STATUSES.has(job.status)) {
			const icon = getStatusEmoji(job.status);
			const color =
				job.status === "success" ? colors.GREEN : job.status === "skipped" ? colors.CYAN : colors.RED;
			const ts = new Date().toTimeString().slice(0, 8);
			const allowedNote = job.status === "failed" && job.allow_failure ? " (allowed)" : "";
			console.log(
				`  ${color}[${ts}] ${icon} ${job.stage}/${job.name} — ${job.status}${allowedNote}${colors.NC}`,
			);
		}
		known.set(job.id, job.status);
	}
}

async function getCurrentBranch(): Promise<string> {
	try {
		const result = await $`git branch --show-current`.quiet();
		const branch = result.text().trim();
		if (!branch) throw new Error("Not on a branch (detached HEAD?)");
		return branch;
	} catch {
		throw new Error("Failed to get current git branch");
	}
}

async function validateDependencies() {
	try {
		await $`which glab`.quiet();
	} catch {
		throw new Error("glab CLI not found. Please install GitLab CLI.");
	}
}

async function findMRForBranch(branch: string): Promise<MR | null> {
	const result = await $`glab mr list --source-branch=${branch} --state=opened --output=json`.quiet();
	const mrs = JSON.parse(result.text()) as MR[];
	return mrs[0] ?? null;
}

async function findLatestMRPipeline(mrIid: number): Promise<Pipeline | null> {
	const result = await $`glab api projects/:id/merge_requests/${mrIid}/pipelines`.quiet();
	const pipelines = JSON.parse(result.text()) as Pipeline[];
	// API returns pipelines newest-first; take the first one regardless of state
	return pipelines[0] ?? null;
}

async function getPipelineStatus(pipelineId: number): Promise<Pipeline> {
	const result = await $`glab api projects/:id/pipelines/${pipelineId}`.quiet();
	return JSON.parse(result.text()) as Pipeline;
}

async function getPipelineJobs(pipelineId: number): Promise<Job[]> {
	try {
		const result = await $`glab api projects/:id/pipelines/${pipelineId}/jobs`.quiet();
		return JSON.parse(result.text()) as Job[];
	} catch (err) {
		log("WARN", `Could not fetch pipeline jobs: ${err}`);
		return [];
	}
}

function getStatusEmoji(status: string): string {
	switch (status) {
		case "success":
			return "✅";
		case "failed":
			return "❌";
		case "canceled":
			return "⚠️";
		case "skipped":
			return "⏭️";
		case "running":
			return "🔄";
		default:
			return "⏳";
	}
}

function log(level: string, message: string) {
	const colorMap: Record<string, string> = {
		INFO: colors.BLUE,
		WARN: colors.YELLOW,
		ERROR: colors.RED,
		SUCCESS: colors.GREEN,
	};
	const color = colorMap[level] ?? "";
	const ts = new Date().toTimeString().slice(0, 8);
	console.log(`${color}[${ts}] [${level}] ${message}${colors.NC}`);
}

function sleep(ms: number): Promise<void> {
	return new Promise((resolve) => setTimeout(resolve, ms));
}

if (import.meta.main) {
	main();
}
