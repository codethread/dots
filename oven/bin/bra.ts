#!/usr/bin/env bun
// :module: Branch repository annotation and management tool

// Interactive git branch switcher that uses fzf for easy branch selection
import {$} from "bun";
import {fzf} from "../shared/fzf";

// try to remove remote/<blah> if it exists
const remoteRegex = /remotes\/[^/]*\//;

function showHelp() {
	console.log(`
bra - Git branch switcher with fzf

Usage: bra [options]

Options:
  -h, --help      Show this help message

Description:
  Interactive git branch switcher using fzf. Shows all local and remote branches,
  allows fuzzy searching, and switches to the selected branch.

Examples:
  bra             # Launch interactive branch selector
`);
}

async function main() {
	const args = process.argv.slice(2);

	// Check for help flag
	if (args.includes("-h") || args.includes("--help")) {
		showHelp();
		process.exit(0);
	}

	try {
		const branches = (await $`git branch --all | grep -v HEAD`.text("utf-8")).split("\n");

		const behind = branches.filter((b) => b.startsWith("+"));
		const out = await fzf(branches, {tmux: true});

		const branch = out.trim().replace(remoteRegex, "").replace("+ ", "").replace("* ", "");

		// TODO: this also means checkedout in a worktree
		if (behind.length > 1) {
			console.log("the following are behind their remote");
			console.log(behind);
			console.log("");
		}
		await $`git checkout ${branch}`;
	} catch (e) {
		console.error(e);
		process.exit(1);
	}
}

if (import.meta.main) {
	main();
}
