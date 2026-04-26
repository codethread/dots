#!/usr/bin/env bun

// :module: Clean up common build artifacts and log files from git projects

import {Glob} from "bun";
import {existsSync, readdirSync, rmSync, statSync} from "fs";
import {join} from "path";
import {parseArgs} from "util";

interface CleanupOptions {
	debug?: boolean;
	dryRun?: boolean;
	maxDepth?: number;
}

interface FinderOptions {
	debug?: boolean;
	maxDepth?: number;
	searchRoot: string;
}

// Default search root directories for git projects
const SEARCH_ROOTS = ["~/dev", "~/work"];

// Directories to skip for performance when searching for projects
const SKIP_DIRS = new Set(["node_modules", "target", ".cargo", ".next", "dist", "build", "coverage", ".git"]);

// Directory globs to search for additional sessions
const SEARCH_GLOBS = [
	process.env.DOTFILES ?? "~/dev/dots",
	"~/workfiles",
	"~/.local/share/nvim/lazy/*",
	"~/.local/share/nvim/mason/packages/*",
	"~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Notes",
];

// Patterns to clean up
const CLEANUP_TARGETS = {
	directories: ["node_modules", "target", ".next", "dist", "build", "coverage"],
	filePatterns: ["*.log"],
};

class GitProjectFinder {
	public searchRoot: string;
	private maxDepth: number;
	private debug: boolean;
	private projects: string[] = [];

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
					if (expandedPattern.includes("*") || expandedPattern.includes("?")) {
						const lastSlash = expandedPattern.lastIndexOf("/");
						const baseDir = expandedPattern.substring(0, lastSlash);
						const pattern = expandedPattern.substring(lastSlash + 1);

						if (!existsSync(baseDir)) {
							this.log(`Base directory does not exist, skipping: ${baseDir}`);
							return [];
						}

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
		if (this.isGitProject(dir)) {
			this.projects.push(dir);
			this.log(`Found git project: ${dir}`);
			return;
		}

		if (currentDepth >= this.maxDepth) {
			this.log(`Max depth reached at: ${dir}`);
			return;
		}

		try {
			const entries = readdirSync(dir);

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

		if (!existsSync(this.searchRoot)) {
			throw new Error(`Search root does not exist: ${this.searchRoot}`);
		}

		const [, globDirectories] = await Promise.all([this.walkDirectory(this.searchRoot), this.expandGlobs()]);

		const gitProjects = [...this.projects];
		const allProjects = [...new Set([...gitProjects, ...globDirectories])];

		if (this.debug) {
			console.error(
				`Found ${gitProjects.length} git projects + ${globDirectories.length} glob directories = ${allProjects.length} total`,
			);
		}

		return allProjects.sort();
	}
}

async function discoverAllProjects(options: CleanupOptions): Promise<string[]> {
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

function formatBytes(bytes: number): string {
	if (bytes === 0) return "0 B";
	const k = 1024;
	const sizes = ["B", "KB", "MB", "GB", "TB"];
	const i = Math.floor(Math.log(bytes) / Math.log(k));
	return `${Number.parseFloat((bytes / k ** i).toFixed(2))} ${sizes[i]}`;
}

function getDirectorySize(dirPath: string): number {
	let totalSize = 0;

	try {
		const entries = readdirSync(dirPath, {withFileTypes: true});

		for (const entry of entries) {
			const fullPath = join(dirPath, entry.name);

			try {
				if (entry.isDirectory()) {
					totalSize += getDirectorySize(fullPath);
				} else if (entry.isFile()) {
					const stat = statSync(fullPath);
					totalSize += stat.size;
				}
			} catch (_error) {
				// Skip files/dirs we can't access
			}
		}
	} catch (_error) {
		// Skip directories we can't read
	}

	return totalSize;
}

interface CleanupResult {
	path: string;
	size: number;
	type: "directory" | "file";
}

async function cleanupProject(projectPath: string, options: CleanupOptions): Promise<CleanupResult[]> {
	const results: CleanupResult[] = [];

	// Clean up directories
	for (const dirName of CLEANUP_TARGETS.directories) {
		const dirPath = join(projectPath, dirName);
		if (existsSync(dirPath)) {
			const stat = statSync(dirPath);
			if (stat.isDirectory()) {
				const size = getDirectorySize(dirPath);
				if (size > 0) {
					results.push({path: dirPath, size, type: "directory"});

					if (!options.dryRun) {
						try {
							rmSync(dirPath, {recursive: true, force: true});
							if (options.debug) {
								console.error(`Deleted: ${dirPath} (${formatBytes(size)})`);
							}
						} catch (error) {
							console.error(`Failed to delete ${dirPath}: ${error}`);
						}
					}
				}
			}
		}
	}

	// Clean up log files
	for (const pattern of CLEANUP_TARGETS.filePatterns) {
		try {
			const glob = new Glob(pattern);
			for await (const file of glob.scan({cwd: projectPath, absolute: true})) {
				try {
					const stat = statSync(file);
					if (stat.isFile()) {
						results.push({path: file, size: stat.size, type: "file"});

						if (!options.dryRun) {
							try {
								rmSync(file, {force: true});
								if (options.debug) {
									console.error(`Deleted: ${file} (${formatBytes(stat.size)})`);
								}
							} catch (error) {
								console.error(`Failed to delete ${file}: ${error}`);
							}
						}
					}
				} catch (_error) {
					// Skip files we can't stat
				}
			}
		} catch (_error) {
			// Skip if glob fails
		}
	}

	return results;
}

function showHelp() {
	console.log(`git-cleanup - Clean up build artifacts and log files from git projects

Usage: git-cleanup [options]

Finds projects by:
1. Walking ~/dev and ~/work (if they exist) recursively for git repositories
2. Expanding predefined glob patterns for additional trusted directories

Cleans up:
- Directories: ${CLEANUP_TARGETS.directories.join(", ")}
- File patterns: ${CLEANUP_TARGETS.filePatterns.join(", ")}

Options:
  -h, --help        Show this help message
  -d, --debug       Show debug logs
  -n, --dry-run     Show what would be deleted without actually deleting
  --max-depth N     Maximum search depth (default: 4)

Examples:
  git-cleanup --dry-run          # Preview what would be deleted
  git-cleanup                    # Clean up all projects
  git-cleanup --debug            # Clean up with detailed logging`);
}

async function main() {
	const {values} = parseArgs({
		args: Bun.argv.slice(2),
		options: {
			help: {type: "boolean", short: "h"},
			debug: {type: "boolean", short: "d"},
			"dry-run": {type: "boolean", short: "n"},
			"max-depth": {type: "string"},
		},
		strict: false,
	});

	if (values.help) {
		showHelp();
		process.exit(0);
	}

	const options: CleanupOptions = {
		debug: values.debug === true,
		dryRun: values["dry-run"] === true,
		maxDepth: typeof values["max-depth"] === "string" ? Number.parseInt(values["max-depth"], 10) : undefined,
	};

	try {
		console.error(options.dryRun ? "🔍 Scanning projects (dry run)..." : "🧹 Cleaning projects...");

		const projects = await discoverAllProjects(options);

		if (projects.length === 0) {
			throw new Error(`No git projects found in any search roots: ${SEARCH_ROOTS.join(", ")}`);
		}

		console.error(`Found ${projects.length} projects\n`);

		let totalSize = 0;
		let totalFiles = 0;
		const projectResults: {project: string; results: CleanupResult[]}[] = [];

		for (const project of projects) {
			const results = await cleanupProject(project, options);
			if (results.length > 0) {
				projectResults.push({project, results});
				const projectSize = results.reduce((sum, r) => sum + r.size, 0);
				totalSize += projectSize;
				totalFiles += results.length;
			}
		}

		// Print summary
		console.log(`\n${"=".repeat(80)}`);
		console.log(options.dryRun ? "📊 Cleanup Summary (Dry Run)" : "✅ Cleanup Summary");
		console.log(`${"=".repeat(80)}\n`);

		if (projectResults.length === 0) {
			console.log("No files or directories to clean up!");
		} else {
			for (const {project, results} of projectResults) {
				const projectSize = results.reduce((sum, r) => sum + r.size, 0);
				console.log(`📁 ${project}`);
				console.log(`   ${results.length} items, ${formatBytes(projectSize)}`);

				for (const result of results) {
					const icon = result.type === "directory" ? "📦" : "📄";
					const relativePath = result.path.replace(`${project}/`, "");
					console.log(`   ${icon} ${relativePath} (${formatBytes(result.size)})`);
				}
				console.log();
			}

			console.log("=".repeat(80));
			console.log(`Total: ${totalFiles} items, ${formatBytes(totalSize)}`);
			console.log("=".repeat(80));

			if (options.dryRun) {
				console.log("\n💡 Run without --dry-run to actually delete these files");
			}
		}
	} catch (error) {
		console.error(`Error: ${error instanceof Error ? error.message : String(error)}`);
		process.exit(1);
	}
}

if (import.meta.main) {
	main();
}
