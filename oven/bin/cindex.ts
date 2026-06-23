// :module: Generate comprehensive file index with advanced filtering and markdown output

import {TOML} from "bun";
import {appendFileSync, existsSync, mkdirSync} from "fs";
import {join} from "path";
import {parseArgs} from "util";

interface SubdivisionConfig {
	/** Name of the top-level directory to subdivide */
	dir: string;
	/** Optional description for the top-level directory itself */
	description?: string;
	/** Optional descriptions for subdirectories */
	descriptions?: Record<string, string>;
}

interface SummariseConfig {
	/** Directory path to apply summarisation to */
	dir: string;
	/** Optional regex pattern to match files (if not provided, summarises all) */
	pattern?: string;
	/** Description to show instead of individual files */
	desc: string;
}

interface Config {
	/** ignore patterns to be passed to ripgrep */
	iglobs: string[];
	/** Descriptions for top-level directories */
	descriptions?: Record<string, string>;
	/** Subdivision configuration with metadata */
	subdivisions?: SubdivisionConfig[];
	/** Summarise configurations for condensing file listings */
	summarise?: SummariseConfig[];
}

function showHelp() {
	console.log(`
cindex - Generate an index of files in the current project

Usage: cindex [options]

Options:
  -c, --config <path>   Path to cindex.toml config file (default: .cindex.toml)
  -p, --path <path>     Limit index to specific directory path
  -m, --markdown        Output in markdown format with directory grouping
      --missing-doc     Show only files missing :module: comments (diagnostic mode)
  -h, --help            Show this help message

Description:
  Generates a comprehensive index of all files in the current project directory,
  respecting ignore patterns defined in the config file. The tool searches for
  files and extracts descriptions from special :module: comments.

Output formats:
  - Default: Simple bulleted list of files with descriptions
  - Markdown (-m): Grouped by directory with formatted headings

Special comments:
  Files containing ":module: <description>" comments will have their
  descriptions included in the index output.

Config file format (.cindex.toml):
  iglobs = ["pattern1", "pattern2"]  # Patterns to ignore (ripgrep format)

  # Top-level directory descriptions
  [descriptions]
  config = "All application configuration files and dotfiles"
  home = "User home directory configurations and local binaries"

  # Subdivisions with optional descriptions
  [[subdivisions]]
  dir = "config"
  [subdivisions.descriptions]
  nvim = "Neovim configuration with custom plugins and LSP setup"
  kitty = "Kitty terminal configuration with custom keybindings"

  # Summarise many files into one line
  [[summarise]]
  dir = "devflow/specs"
  pattern = "^devflow/specs/.*\\\\.md$"  # Optional regex filter
  desc = "[summary] spec files"

Examples:
  cindex                    # Index current directory with default config
  cindex -m                 # Output in markdown format
  cindex -p src/            # Index only the src/ directory
  cindex -c ~/my.toml       # Use custom config file
  cindex --missing-doc           # Show files missing :module: comments
  cindex --missing-doc -p oven/  # Show undocumented files in oven/ directory
`);
}

async function main() {
	const {values} = parseArgs({
		args: Bun.argv.slice(2),
		options: {
			config: {
				type: "string",
				short: "c",
				default: `.cindex.toml`,
			},
			path: {
				type: "string",
				short: "p",
			},
			markdown: {
				type: "boolean",
				short: "m",
				default: false,
			},
			"missing-doc": {
				type: "boolean",
				default: false,
			},
			help: {
				type: "boolean",
				short: "h",
				default: false,
			},
		},
	});

	if (values.help) {
		showHelp();
		process.exit(0);
	}

	// Validate incompatible options
	if (values["missing-doc"] && values.markdown) {
		console.error("Error: --missing-doc cannot be used with --markdown");
		process.exit(1);
	}

	const configPath = values.config as string;

	if (!existsSync(configPath)) {
		console.error(`Config file not found: ${configPath}`);
		process.exit(1);
	}

	const rawConfig = await Bun.file(configPath).text();
	const config = TOML.parse(rawConfig) as Config;

	// Set up logging
	const logDir = join(process.env.HOME || "~", ".cache", "cindex");
	const logFile = join(logDir, "commands.log");

	if (!existsSync(logDir)) {
		mkdirSync(logDir, {recursive: true});
	}

	// Build commands
	const pathFilter = values.path as string | undefined;
	const commentCmd = [
		"rg",
		":module:",
		"--no-heading",
		"--no-line-number",
		...config.iglobs.map((g) => `-g=!${g}`),
		...(pathFilter ? [pathFilter] : []),
	];
	const filesCmd = [
		"rg",
		"--files",
		...config.iglobs.map((g) => `-g=!${g}`),
		...(pathFilter ? [pathFilter] : []),
	];

	// Log commands
	const timestamp = new Date().toISOString();
	const logEntry =
		`[${timestamp}] cwd: ${process.cwd()}\n` +
		`[${timestamp}] Comment search: ${commentCmd.join(" ")}\n` +
		`[${timestamp}] File listing: ${filesCmd.join(" ")}\n\n`;
	appendFileSync(logFile, logEntry);

	const [fileComments, allFiles] = await Promise.all([
		Bun.spawn(commentCmd).stdout.text(),
		Bun.spawn(filesCmd).stdout.text(),
	]);

	const commentedFiles = new Map<string, string>();

	for (const l of fileComments.split("\n")) {
		if (l === "") continue;

		const [fileWithComment, comment] = l.split(":module: ");
		const [file] = fileWithComment.split(":");

		if (!file) throw new Error(`no file: ${JSON.stringify({file, comment, line: l})}`);
		if (!comment) continue; // TODO log these for update

		if (
			file.endsWith("documentation-generator.md") ||
			file.endsWith("cindex.ts") ||
			file.endsWith("prepend-comment.ts")
		)
			continue;

		commentedFiles.set(file, comment);
	}

	// Get subdivision configurations
	const subdivisionConfigs = getSubdivisionConfigs(config);

	const allFilesList = allFiles.split("\n").filter(Boolean);

	if (values["missing-doc"]) {
		// Find files without :module: comments
		const filesWithoutComments = allFilesList.filter((file) => !commentedFiles.has(file));
		console.log(filesWithoutComments.join("\n"));
		return;
	}

	const output = values.markdown
		? formatMarkdown({
				allFiles: allFilesList,
				commentedFiles,
				subdivisionConfigs,
				topLevelDescriptions: config.descriptions,
				summariseConfigs: config.summarise,
			})
		: formatList(allFilesList, commentedFiles);

	console.log(output);
}

function formatList(allFiles: string[], commentedFiles: Map<string, string>) {
	return allFiles
		.map((f) => {
			const comment = commentedFiles.get(f);
			return `- ${comment ? `${f}: ${comment}` : f}`;
		})
		.join("\n");
}

function getSubdivisionConfigs(config: Config): Map<string, SubdivisionConfig> {
	const configs = new Map<string, SubdivisionConfig>();

	if (config.subdivisions) {
		for (const subdivision of config.subdivisions) {
			configs.set(subdivision.dir, subdivision);
		}
	}

	return configs;
}

function shouldSummarise(path: string, summariseConfigs?: SummariseConfig[]): SummariseConfig | undefined {
	if (!summariseConfigs) return undefined;

	for (const config of summariseConfigs) {
		// Check if path starts with the summarise dir
		if (path.startsWith(`${config.dir}/`) || path === config.dir) {
			// If no pattern specified, summarise all files in this dir
			if (!config.pattern) return config;

			// Check if file matches the pattern
			try {
				const regex = new RegExp(config.pattern);
				if (regex.test(path)) return config;
			} catch (_e) {
				console.error(`Invalid regex pattern: ${config.pattern}`);
			}
		}
	}
	return undefined;
}

function renderFileList(options: {
	files: string[];
	commentedFiles: Map<string, string>;
	summariseConfigs?: SummariseConfig[];
	usedSummarises?: Set<SummariseConfig>;
}): string {
	const {files, commentedFiles, summariseConfigs, usedSummarises} = options;
	let output = "";
	const summarisedGroups = new Map<SummariseConfig, string[]>();
	const regularFiles: string[] = [];

	// Group files by summarisation config
	for (const file of files) {
		const summariseConfig = shouldSummarise(file, summariseConfigs);
		if (summariseConfig) {
			if (!summarisedGroups.has(summariseConfig)) {
				summarisedGroups.set(summariseConfig, []);
			}
			summarisedGroups.get(summariseConfig)?.push(file);
			usedSummarises?.add(summariseConfig);
		} else {
			regularFiles.push(file);
		}
	}

	// Output regular files first
	for (const file of regularFiles) {
		const comment = commentedFiles.get(file);
		output += comment ? `- \`${file}\`: ${comment}\n` : `- \`${file}\`\n`;
	}

	// Output summarised groups
	for (const [config, groupFiles] of summarisedGroups) {
		if (groupFiles.length > 0) {
			output += `- ${config.desc}\n`;
		}
	}

	return output;
}

function formatMarkdown(options: {
	allFiles: string[];
	commentedFiles: Map<string, string>;
	subdivisionConfigs: Map<string, SubdivisionConfig>;
	topLevelDescriptions?: Record<string, string>;
	summariseConfigs?: SummariseConfig[];
}) {
	const {allFiles, commentedFiles, subdivisionConfigs, topLevelDescriptions, summariseConfigs} = options;
	// Track which summarise configs have been used
	const usedSummarises = new Set<SummariseConfig>();

	// Group files by their first directory level
	const rootFiles: string[] = [];
	const directories = new Map<string, string[]>();

	for (const file of allFiles) {
		const slashIndex = file.indexOf("/");
		if (slashIndex === -1) {
			// Root level file
			rootFiles.push(file);
		} else {
			// File in a directory
			const firstDir = file.substring(0, slashIndex);
			if (!directories.has(firstDir)) {
				directories.set(firstDir, []);
			}
			directories.get(firstDir)?.push(file);
		}
	}

	let output = "# Project Index\n\n";

	// Add root files if any
	if (rootFiles.length > 0) {
		output += "## Root files\n\n";
		output += renderFileList({files: rootFiles, commentedFiles, summariseConfigs, usedSummarises});
		output += "\n";
	}

	// Add each directory section, sorted alphabetically
	const sortedDirs = Array.from(directories.keys()).sort();
	for (const dir of sortedDirs) {
		output += `## \`${dir}/\`\n\n`;

		// Add top-level description if available
		const topLevelDesc = topLevelDescriptions?.[dir];
		if (topLevelDesc) {
			output += `${topLevelDesc}\n\n`;
		}

		const files = directories.get(dir)?.sort();
		if (!files) continue;

		// Check if this directory should be subdivided
		const subdivisionConfig = subdivisionConfigs.get(dir);
		if (subdivisionConfig) {
			// Group files by their subdirectory
			const subdirs = new Map<string, string[]>();
			const directFiles: string[] = [];

			for (const file of files) {
				const relativePath = file.substring(dir.length + 1); // Remove "dir/" prefix
				const slashIndex = relativePath.indexOf("/");

				if (slashIndex === -1) {
					// Direct file in this directory
					directFiles.push(file);
				} else {
					// File in a subdirectory
					const subdir = relativePath.substring(0, slashIndex);
					if (!subdirs.has(subdir)) {
						subdirs.set(subdir, []);
					}
					subdirs.get(subdir)?.push(file);
				}
			}

			// Add direct files if any
			if (directFiles.length > 0) {
				output += renderFileList({files: directFiles, commentedFiles, summariseConfigs, usedSummarises});
				if (subdirs.size > 0 && output.endsWith("\n")) {
					output += "\n";
				}
			}

			// Add subdirectory sections
			const sortedSubdirs = Array.from(subdirs.keys()).sort();
			for (const subdir of sortedSubdirs) {
				output += `### \`${subdir}/\`\n\n`;

				// Add description if available
				const description = subdivisionConfig.descriptions?.[subdir];
				if (description) {
					output += `${description}\n\n`;
				}

				const subdirFiles = subdirs.get(subdir)?.sort() || [];
				output += renderFileList({files: subdirFiles, commentedFiles, summariseConfigs, usedSummarises});
				output += "\n";
			}
		} else {
			// Normal listing without subdivision
			output += renderFileList({files, commentedFiles, summariseConfigs, usedSummarises});
			output += "\n";
		}
	}

	return output.trimEnd();
}

if (import.meta.main) {
	main();
}
