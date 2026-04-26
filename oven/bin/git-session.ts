#!/usr/bin/env bun

// :module: Interactive git project session switcher using fzf

import {$, Glob} from "bun";
import {existsSync, mkdirSync, readdirSync, statSync, writeFileSync} from "fs";
import {basename, join} from "path";
import {parseArgs} from "util";

interface FinderOptions {
	debug?: boolean;
	maxDepth?: number;
	searchRoot: string;
}

interface DiscoverOptions {
	debug?: boolean;
	maxDepth?: number;
}

// Default search root directories for git projects
const SEARCH_ROOTS = ["~/dev", "~/work"];

// Directories to skip for performance
const SKIP_DIRS = new Set([
	"node_modules",
	"target",
	".cargo",
	".next",
	"dist",
	"build",
	"coverage",
	".git", // Don't recurse into .git dirs themselves
]);

// Directory globs to search for additional sessions
const SEARCH_GLOBS = [
	process.env.DOTFILES ?? "~/dev/dots",
	"~/workfiles",
	"~/.local/share/nvim/lazy/*",
	"~/.local/share/nvim/mason/packages/*",
	"~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Notes",
];

class GitProjectFinder {
	public searchRoot: string;
	private maxDepth: number;
	private debug: boolean;
	private projects: string[] = [];
	private visitedDirs = 0;
	private maxDepthReached = 0;

	constructor(options: FinderOptions) {
		this.searchRoot = options.searchRoot;
		this.maxDepth = options.maxDepth || 4;
		this.debug = options.debug || false;
	}

	private log(message: string) {
		if (this.debug) {
			console.error(`[DEBUG] ${message}`);
		}
	}

	private isGitProject(dir: string): boolean {
		return existsSync(join(dir, ".git"));
	}

	private shouldSkipDir(dirName: string): boolean {
		return SKIP_DIRS.has(dirName);
	}

	private async expandGlobs(): Promise<string[]> {
		const homeDir = process.env.HOME || "";

		const results = await Promise.all(
			SEARCH_GLOBS.map(async (globPattern) => {
				const expandedPattern = globPattern.startsWith("~/")
					? join(homeDir, globPattern.slice(2))
					: globPattern;

				this.log(`Expanding glob: ${expandedPattern}`);

				try {
					// Check if pattern contains wildcards
					if (expandedPattern.includes("*") || expandedPattern.includes("?")) {
						// Extract base directory and pattern
						const lastSlash = expandedPattern.lastIndexOf("/");
						const baseDir = expandedPattern.substring(0, lastSlash);
						const pattern = expandedPattern.substring(lastSlash + 1);

						if (!existsSync(baseDir)) {
							this.log(`Base directory does not exist, skipping: ${baseDir}`);
							return [];
						}

						// Use Bun's Glob with onlyFiles: false to include directories
						const glob = new Glob(pattern);
						const matches: string[] = [];
						for await (const match of glob.scan({
							cwd: baseDir,
							onlyFiles: false,
							absolute: true,
						})) {
							try {
								const stat = statSync(match);
								if (stat.isDirectory()) {
									matches.push(match);
									this.log(`Expanded to directory: ${match}`);
								}
							} catch (_error) {
								this.log(`Cannot stat glob match, skipping: ${match}`);
							}
						}
						return matches;
					}
					// No wildcards - just check if it's a directory
					if (existsSync(expandedPattern)) {
						const stat = statSync(expandedPattern);
						if (stat.isDirectory()) {
							this.log(`Expanded to directory: ${expandedPattern}`);
							return [expandedPattern];
						}
						this.log(`Path exists but is not a directory, skipping: ${expandedPattern}`);
					} else {
						this.log(`Directory does not exist, skipping: ${expandedPattern}`);
					}
				} catch (_error) {
					this.log(`Error expanding glob, skipping: ${globPattern}`);
				}
				return [];
			}),
		);

		return results.flat();
	}

	private async walkDirectory(dir: string, currentDepth = 0): Promise<void> {
		this.visitedDirs++;
		this.maxDepthReached = Math.max(this.maxDepthReached, currentDepth);

		// Check if current directory is a git project
		if (this.isGitProject(dir)) {
			this.projects.push(dir);
			this.log(`Found git project: ${dir}`);
			return; // Stop recursing - no nested projects
		}

		// Don't recurse too deep
		if (currentDepth >= this.maxDepth) {
			this.log(`Max depth reached at: ${dir}`);
			return;
		}

		try {
			const entries = readdirSync(dir);

			// Process directories in parallel
			await Promise.all(
				entries.map(async (entry) => {
					if (this.shouldSkipDir(entry)) {
						this.log(`Skipping: ${join(dir, entry)}`);
						return;
					}

					const fullPath = join(dir, entry);

					try {
						const stat = statSync(fullPath);
						if (stat.isDirectory()) {
							await this.walkDirectory(fullPath, currentDepth + 1);
						}
					} catch (error) {
						// Skip directories we can't read (permissions, etc.)
						this.log(`Cannot read: ${fullPath} - ${error}`);
					}
				}),
			);
		} catch (error) {
			this.log(`Cannot read directory: ${dir} - ${error}`);
		}
	}

	public async findProjects(): Promise<string[]> {
		this.projects = [];
		this.visitedDirs = 0;
		this.maxDepthReached = 0;

		if (!existsSync(this.searchRoot)) {
			throw new Error(`Search root does not exist: ${this.searchRoot}`);
		}

		const startTime = Date.now();

		// Find git projects by walking directory tree and expand globs in parallel
		const [, globDirectories] = await Promise.all([this.walkDirectory(this.searchRoot), this.expandGlobs()]);

		const gitProjects = [...this.projects];

		// Merge and deduplicate
		const allProjects = [...new Set([...gitProjects, ...globDirectories])];

		const endTime = Date.now();

		if (this.debug) {
			console.error(
				`Found ${gitProjects.length} git projects + ${globDirectories.length} glob directories = ${allProjects.length} total in ${endTime - startTime}ms`,
			);
			console.error(`Visited ${this.visitedDirs} directories`);
			console.error(`Max depth reached: ${this.maxDepthReached}`);
		}

		return allProjects.sort();
	}
}

function toKebabCase(input: string): string {
	return basename(input)
		.toLowerCase()
		.replace(/[^a-z0-9]/g, "-")
		.replace(/-+/g, "-")
		.replace(/^-|-$/g, "");
}

async function createAndSwitchSession(projectPath: string): Promise<void> {
	const sessionName = toKebabCase(projectPath);
	const sessionsDir = join(process.env.HOME || "", ".config", "kitty", "sessions");
	const sessionFile = join(sessionsDir, `${sessionName}.session`);

	if (!existsSync(sessionsDir)) {
		mkdirSync(sessionsDir, {recursive: true});
	}

	const sessionContent = `launch --title ${sessionName} --cwd ${projectPath}\n`;
	writeFileSync(sessionFile, sessionContent);

	console.log(`Created session: ${sessionName}`);
	console.log(`Directory: ${projectPath}`);
	console.log(`Session file: ${sessionFile}`);

	try {
		await $`kitten @ action goto_session ${sessionFile}`.quiet();
	} catch (error) {
		throw new Error(`Failed to switch to session: ${error instanceof Error ? error.message : String(error)}`);
	}
}

async function runFzf(projects: string[]): Promise<string | null> {
	try {
		const result =
			await $`echo ${projects.join("\n")} | fzf --prompt='Select git project: ' --height=40% --reverse`.text();
		return result.trim() || null;
	} catch (_error) {
		return null;
	}
}

function showHelp() {
	console.log(`git-session - Interactive git project session switcher using fzf

Usage: git-session [options]

Finds projects by:
1. Walking ~/dev and ~/work (if they exist) recursively for git repositories
2. Expanding predefined glob patterns for additional trusted directories

Options:
  -h, --help        Show this help message
  -d, --debug       Show debug logs and output results as list instead of fzf
  --max-depth N     Maximum search depth (default: 4)

Examples:
  git-session                    # Interactive mode with fzf
  git-session --debug            # Debug mode with flat list output
  git-session --max-depth 2      # Limit search depth`);
}

async function discoverAllProjects(options: DiscoverOptions): Promise<string[]> {
	const homeDir = process.env.HOME || "";
	const searchRoots = SEARCH_ROOTS.map((root) =>
		root.startsWith("~/") ? join(homeDir, root.slice(2)) : root,
	).filter((root) => existsSync(root));

	if (searchRoots.length === 0) {
		throw new Error(`None of the search roots exist: ${SEARCH_ROOTS.join(", ")}`);
	}

	const finders = searchRoots.map(
		(searchRoot) =>
			new GitProjectFinder({
				...options,
				searchRoot,
			}),
	);

	const results = await Promise.all(finders.map((finder) => finder.findProjects()));

	const allProjects = [...new Set(results.flat())].sort();

	return allProjects;
}

async function main() {
	const {values} = parseArgs({
		args: Bun.argv.slice(2),
		options: {
			help: {type: "boolean", short: "h"},
			debug: {type: "boolean", short: "d"},
			"max-depth": {type: "string"},
		},
		strict: false,
	});

	if (values.help) {
		showHelp();
		process.exit(0);
	}

	const options: DiscoverOptions = {
		debug: values.debug === true,
		maxDepth: typeof values["max-depth"] === "string" ? Number.parseInt(values["max-depth"], 10) : undefined,
	};

	try {
		if (options.debug) {
			console.log("Discovering projects...");
			console.log(`Search roots: ${SEARCH_ROOTS.join(", ")}`);
		} else {
			console.error("Discovering projects...");
		}

		const startTime = Date.now();
		const projects = await discoverAllProjects(options);
		const endTime = Date.now();

		if (projects.length === 0) {
			throw new Error(`No git projects found in any search roots: ${SEARCH_ROOTS.join(", ")}`);
		}

		if (options.debug) {
			console.log(`\nFound ${projects.length} projects in ${endTime - startTime}ms\n`);
			for (const p of projects) {
				console.log(p);
			}
			process.exit(0);
		}

		const selected = await runFzf(projects);

		if (!selected) {
			process.exit(0);
		}

		await createAndSwitchSession(selected);
	} catch (error) {
		console.error(`Error: ${error instanceof Error ? error.message : String(error)}`);
		process.exit(1);
	}
}

if (import.meta.main) {
	main();
}
