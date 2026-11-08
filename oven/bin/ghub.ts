#!/usr/bin/env bun
// :module: GitHub CLI utility for repository interactions

import {$} from "bun";
import {parseArgs} from "util";
import {report, reportError} from "../shared/report";

function showHelp() {
	console.log(`
ghub - Open GitHub/GitLab repository in browser

Usage: ghub [options]

Options:
  -h, --help      Show this help message

Description:
  Opens the current git repository in the browser. Automatically detects
  GitHub and GitLab repositories and opens the appropriate URL.

Examples:
  ghub            # Open current repo in browser
`);
	process.exit(0);
}

// biome-ignore lint/suspicious/noEmptyInterface: Future options will be added here
export interface GhubOptions {}

async function main() {
	const {values} = parseArgs({
		args: Bun.argv.slice(2),
		options: {
			help: {
				type: "boolean",
				short: "h",
			},
		},
		strict: false,
	});

	if (values.help) {
		showHelp();
	}

	try {
		const result = await ghubLib({});
		report(`Opening: ${result.url}`);
	} catch (err) {
		reportError(err);
		process.exit(1);
	}
}

export async function ghubLib(_options: GhubOptions): Promise<{url: string}> {
	const remoteInfo = await getRemoteInfo();
	const url = buildUrl(remoteInfo);
	await openInBrowser(url);
	return {url};
}

// Alias for more semantic naming
export const openRepo = ghubLib;

interface RemoteInfo {
	domain: string;
	repo: string;
	branch: string;
}

async function getRemoteInfo(): Promise<RemoteInfo> {
	const remoteOutput = await $`git remote -v`.text();
	const branch = (await $`git rev-parse --abbrev-ref HEAD`.text()).trim();

	// Parse remote URL
	const remoteLine = remoteOutput.split("\n")[0];
	const remoteUrl = remoteLine.split("\t")[1].split(" ")[0];

	// Extract domain and repo from git URL
	const match = /^git@(?<domain>.*):(?<repo>.*).git$/.exec(remoteUrl);
	if (!match?.groups) {
		throw new Error(`Could not parse remote URL: ${remoteUrl}`);
	}

	return {
		domain: match.groups.domain,
		repo: match.groups.repo,
		branch,
	};
}

function buildUrl(remoteInfo: RemoteInfo): string {
	const {domain, repo, branch} = remoteInfo;

	if (domain === "github.com") {
		return `https://${domain}/${repo}`;
	}

	if (domain.startsWith("git.")) {
		// GitLab style
		return `https://${domain}/${repo}/-/tree/${branch}`;
	}

	throw new Error(`Remote not supported: ${domain} (expected github or gitlab)`);
}

async function openInBrowser(url: string): Promise<void> {
	await $`open ${url}`;
}

// Only run if executed directly
if (import.meta.main) {
	main();
}
