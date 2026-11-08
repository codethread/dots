#!/usr/bin/env bun
// :module: GitLab pipeline status monitoring tool

// GitLab Pipeline Watcher
// Monitors running GitLab pipelines for a user and sends notifications when they complete

import {$} from "bun";
import {existsSync, readFileSync, unlinkSync, writeFileSync} from "fs";

// Pipeline type from GitLab API
interface Pipeline {
	id: number;
	status: string;
	ref: string;
	web_url: string;
	updated_at: string;
}

// Configuration
let POLL_INTERVAL = 30;
let USERNAME = "adam.hall";
let BRANCH: string | undefined;
const TRACKED_PIPELINES_FILE = "/tmp/gitlab-pipeline-watcher-tracked-ts.txt";

// Colors for terminal output
const colors = {
	RED: "\x1b[0;31m",
	GREEN: "\x1b[0;32m",
	YELLOW: "\x1b[1;33m",
	BLUE: "\x1b[0;34m",
	NC: "\x1b[0m", // No Color
};

// Function to log with timestamp and color
function log(level: string, message: string) {
	let color = "";

	switch (level) {
		case "INFO":
			color = colors.BLUE;
			break;
		case "WARN":
			color = colors.YELLOW;
			break;
		case "ERROR":
			color = colors.RED;
			break;
		case "SUCCESS":
			color = colors.GREEN;
			break;
	}

	const timestamp = new Date().toTimeString().slice(0, 8);
	console.log(`${color}[${timestamp}] [${level}] ${message}${colors.NC}`);
}

// Function to send notification
async function sendNotification(options: {
	title: string;
	body: string;
	icon?: string;
	webUrl?: string;
	expireAfter?: string;
}) {
	const {title, body, icon = "info", webUrl, expireAfter} = options;
	try {
		const notifyCmd = ["kitten", "notify", `--icon=${icon}`];

		if (expireAfter) {
			notifyCmd.push(`--expire-after=${expireAfter}`);
		}

		if (webUrl) {
			notifyCmd.push("--wait-for-completion");
		}

		notifyCmd.push(title, body);

		const result = await $`${notifyCmd}`.quiet();

		// If notification was clicked (returns "0"), open the URL
		if (webUrl && result.text().trim() === "0") {
			try {
				await $`open ${webUrl}`;
				log("INFO", `Opened pipeline URL: ${webUrl}`);
			} catch (error) {
				log("ERROR", `Failed to open URL: ${error}`);
			}
		}
	} catch (error) {
		log("ERROR", `Failed to send notification: ${error}`);
	}
}

// Function to get status icon for notifications
function getStatusIcon(status: string): string {
	switch (status) {
		case "success":
			return "info";
		case "failed":
			return "error";
		case "canceled":
			return "warning";
		default:
			return "system-monitor";
	}
}

// Function to get status emoji for terminal
function getStatusEmoji(status: string): string {
	switch (status) {
		case "success":
			return "✅";
		case "failed":
			return "❌";
		case "canceled":
			return "⚠️";
		case "running":
			return "🔄";
		default:
			return "ℹ️";
	}
}

// Function to format pipeline info
function _formatPipelineInfo(pipeline: Pipeline): string {
	const id = pipeline.id;
	const status = pipeline.status;
	const ref = pipeline.ref.replace(/refs\/merge-requests\//, "").replace(/\/head/, "");
	const _webUrl = pipeline.web_url;
	const updatedAt = pipeline.updated_at;

	return `Pipeline ${id} (MR ${ref}) - ${status} - ${updatedAt}`;
}

// Function to get currently running pipelines
async function getRunningPipelines(): Promise<Pipeline[]> {
	try {
		const args = [`glab`, `pipeline`, `list`, `--username=${USERNAME}`, `--status=running`, `--output=json`];
		if (BRANCH) {
			args.push(`--ref=${BRANCH}`);
		}
		const result = await $`${args}`.quiet();
		return JSON.parse(result.text()) as Pipeline[];
	} catch (_error) {
		return [];
	}
}

// Function to get pipeline by ID
async function getPipelineById(pipelineId: string): Promise<Pipeline | null> {
	try {
		const args = [`glab`, `pipeline`, `list`, `--username=${USERNAME}`, `--output=json`];
		if (BRANCH) {
			args.push(`--ref=${BRANCH}`);
		}
		const result = await $`${args}`.quiet();
		const pipelines = JSON.parse(result.text()) as Pipeline[];
		return pipelines.find((p) => p.id.toString() === pipelineId) || null;
	} catch (_error) {
		return null;
	}
}

// Initialize tracked pipelines file
function initializeTracking() {
	if (!existsSync(TRACKED_PIPELINES_FILE)) {
		writeFileSync(TRACKED_PIPELINES_FILE, "");
		log("INFO", `Initialized tracking file: ${TRACKED_PIPELINES_FILE}`);
	}
}

// Cleanup function
function cleanup() {
	log("INFO", "Cleaning up and exiting...");
	try {
		unlinkSync(TRACKED_PIPELINES_FILE);
	} catch (_error) {
		// File might not exist
	}
	process.exit(0);
}

// Set up signal handlers
process.on("SIGINT", cleanup);
process.on("SIGTERM", cleanup);

// Main monitoring loop
async function monitorPipelines() {
	log("INFO", `Starting GitLab pipeline watcher for user: ${USERNAME}`);
	if (BRANCH) {
		log("INFO", `Filtering by branch: ${BRANCH}`);
	}
	log("INFO", `Polling interval: ${POLL_INTERVAL}s`);
	log("INFO", "Press Ctrl+C to stop");
	console.log();

	initializeTracking();

	// Get initial running pipelines
	const runningPipelines = await getRunningPipelines();
	if (runningPipelines.length > 0) {
		const ids = runningPipelines.map((p) => p.id.toString()).join("\n");
		writeFileSync(TRACKED_PIPELINES_FILE, ids);
		log("INFO", `Found ${runningPipelines.length} running pipeline(s)`);

		for (const pipeline of runningPipelines) {
			const ref = pipeline.ref.replace(/refs\/merge-requests\//, "MR ").replace(/\/head/, "");
			log("INFO", `${getStatusEmoji(pipeline.status)} Tracking Pipeline ${pipeline.id} (${ref})`);
		}
		console.log();
	} else {
		log("INFO", "No running pipelines found");
		console.log();
	}

	while (true) {
		await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL * 1000));

		// Get current running pipelines
		const currentRunning = await getRunningPipelines();
		const currentRunningIds = currentRunning.map((p) => p.id.toString());

		// Read previously tracked pipelines
		let trackedIds: string[] = [];
		if (existsSync(TRACKED_PIPELINES_FILE)) {
			try {
				const content = readFileSync(TRACKED_PIPELINES_FILE, "utf8").trim();
				trackedIds = content ? content.split("\n").filter((id) => id.length > 0) : [];
			} catch (_error) {
				trackedIds = [];
			}
		}

		// Check for newly started pipelines
		for (const pipelineId of currentRunningIds) {
			if (!trackedIds.includes(pipelineId)) {
				const pipeline = currentRunning.find((p) => p.id.toString() === pipelineId);
				if (pipeline) {
					const ref = pipeline.ref.replace(/refs\/merge-requests\//, "").replace(/\/head/, "");
					log("INFO", `${getStatusEmoji("running")} New pipeline started: ${pipelineId} (MR ${ref})`);
				}
			}
		}

		// Check for completed pipelines
		for (const pipelineId of trackedIds) {
			if (!currentRunningIds.includes(pipelineId)) {
				// Pipeline is no longer running, check its final status
				const completedPipeline = await getPipelineById(pipelineId);
				if (completedPipeline) {
					const status = completedPipeline.status;
					const ref = completedPipeline.ref.replace(/refs\/merge-requests\//, "").replace(/\/head/, "");
					const webUrl = completedPipeline.web_url;

					// Send notification (non-blocking)
					const icon = getStatusIcon(status);
					const title = `GitLab Pipeline ${status}`;
					const body = `Pipeline ${pipelineId} (MR ${ref}) has ${status}`;
					const expireAfter = status === "success" ? "10s" : undefined;

					sendNotification({title, body, icon, webUrl, expireAfter});

					// Log completion
					switch (status) {
						case "success":
							log(
								"SUCCESS",
								`${getStatusEmoji(status)} Pipeline ${pipelineId} (MR ${ref}) completed successfully`,
							);
							break;
						case "failed":
							log("ERROR", `${getStatusEmoji(status)} Pipeline ${pipelineId} (MR ${ref}) failed`);
							break;
						default:
							log("WARN", `${getStatusEmoji(status)} Pipeline ${pipelineId} (MR ${ref}) ${status}`);
							break;
					}

					log("INFO", `View at: ${webUrl}`);
					console.log();
				}
			}
		}

		// Update tracked pipelines file
		if (currentRunningIds.length > 0) {
			writeFileSync(TRACKED_PIPELINES_FILE, currentRunningIds.join("\n"));
		} else {
			writeFileSync(TRACKED_PIPELINES_FILE, "");
		}
	}
}

// Show help
function showHelp() {
	console.log(`
gitlab-pipeline-watcher - Monitor GitLab pipelines and send notifications

Usage: gitlab-pipeline-watcher [options]

Options:
    -h, --help              Show this help message
    -i, --interval SECONDS  Set polling interval (default: 30)
    -u, --username USER     Set GitLab username (default: adam.hall)
    -b, --branch BRANCH     Filter pipelines by branch name

Description:
    Monitors GitLab pipelines for the specified user and sends desktop notifications
    when pipelines complete. Uses 'kitten notify' for notifications and 'glab' CLI
    for GitLab API access.

Examples:
    gitlab-pipeline-watcher                    # Start monitoring with default settings
    gitlab-pipeline-watcher -i 60             # Check every 60 seconds
    gitlab-pipeline-watcher -u john.doe       # Monitor different user
    gitlab-pipeline-watcher -b master         # Watch only master branch pipelines
`);
}

// Parse command line arguments
const args = process.argv.slice(2);
for (let i = 0; i < args.length; i++) {
	switch (args[i]) {
		case "-h":
		case "--help":
			showHelp();
			process.exit(0);
			break;
		case "-i":
		case "--interval":
			POLL_INTERVAL = parseInt(args[++i], 10);
			break;
		case "-u":
		case "--username":
			USERNAME = args[++i];
			break;
		case "-b":
		case "--branch":
			BRANCH = args[++i];
			break;
		default:
			log("ERROR", `Unknown option: ${args[i]}`);
			console.log("Use --help for usage information.");
			process.exit(1);
	}
}

// Validate dependencies
async function validateDependencies() {
	try {
		await $`which glab`.quiet();
	} catch {
		log("ERROR", "glab CLI not found. Please install GitLab CLI.");
		process.exit(1);
	}

	try {
		await $`which kitten`.quiet();
	} catch {
		log("ERROR", "kitten not found. Please install Kitty terminal.");
		process.exit(1);
	}
}

// Start monitoring
validateDependencies().then(() => {
	monitorPipelines();
});
