import {$} from "bun";
import {readdir, readFile, writeFile} from "fs/promises";
import {join} from "path";
import {parseArgs} from "util";

interface ToolInfo {
	name: string;
	description: string;
	usage?: string;
}

interface BinEntry {
	name: string;
	path: string;
}

const BIN_DIR = join(import.meta.dir, "..", "bin");

async function main(verbose = false) {
	try {
		const entries = await loadBinEntries();

		if (verbose) {
			console.log(`Found ${entries.length} executable tools in bin/`);
			console.log("Extracting help information from source entrypoints...");
		}

		// Extract help information from all tools in parallel
		const toolPromises = entries.map((entry) => {
			return extractHelpInfo(entry);
		});

		// Wait for all tools to be processed
		const toolResults = await Promise.all(toolPromises);

		// Filter out null results
		const validTools = toolResults.filter((tool): tool is ToolInfo => tool !== null);

		// Deduplicate tools by name (in case multiple files produce the same tool)
		const toolMap = new Map<string, ToolInfo>();
		validTools.forEach((tool) => {
			// Only keep the first occurrence of each tool name
			if (!toolMap.has(tool.name)) {
				toolMap.set(tool.name, tool);
			}
		});

		const tools = Array.from(toolMap.values());

		if (verbose) {
			console.log("\nExtracted help information:");
			tools.forEach((tool) => {
				console.log(`  ✓ ${tool.name}: ${tool.description}`);
			});
		}

		// Update README with the extracted information
		await updateReadme(tools, verbose);
	} catch (error) {
		console.error("Error:", error);
		process.exit(1);
	}
}

async function loadBinEntries(): Promise<BinEntry[]> {
	const files = await readdir(BIN_DIR, {withFileTypes: true});
	return files
		.filter((file) => file.isFile() && file.name.endsWith(".ts"))
		.map((file) => ({
			name: file.name.slice(0, -3),
			path: join(BIN_DIR, file.name),
		}))
		.toSorted((a, b) => a.name.localeCompare(b.name));
}

async function extractHelpInfo(entry: BinEntry): Promise<ToolInfo | null> {
	const {name: toolName, path: commandPath} = entry;
	try {
		const result = await $`${commandPath} -h`.nothrow().quiet();

		// Check if the command was found
		if (result.stderr?.toString().includes("command not found")) {
			throw new Error(`Command '${toolName}' could not be executed from ${commandPath}.`);
		}

		// Get output regardless of exit code (some tools might exit with 1 on help)
		const helpOutput = result.stdout?.toString() || result.stderr?.toString() || "";

		// Parse the help output
		// Extract the first line which should be "toolname - description"
		const lines = helpOutput.trim().split("\n");
		const firstLine = lines.find((line) => line.includes(" - "));

		if (firstLine) {
			const [name, ...descParts] = firstLine.split(" - ");
			const description = descParts.join(" - ").trim();

			// Extract usage if available
			const usageIndex = lines.findIndex((line) => line.toLowerCase().includes("usage:"));
			let usage: string | undefined;
			if (usageIndex !== -1 && usageIndex + 1 < lines.length) {
				usage = lines[usageIndex + 1].trim();
			}

			return {
				name: name.trim(),
				description,
				usage,
			};
		}

		// Commander format: "Usage: name [options]" followed by blank line then description
		const usageIdx = lines.findIndex((line) => line.trim().startsWith("Usage:"));
		if (usageIdx !== -1) {
			const usageMatch = lines[usageIdx].trim().match(/^Usage:\s+(\S+)/);
			const name = usageMatch ? usageMatch[1] : toolName;
			for (let i = usageIdx + 1; i < lines.length; i++) {
				const trimmed = lines[i].trim();
				if (trimmed === "") continue;
				if (
					trimmed.startsWith("Options:") ||
					trimmed.startsWith("Commands:") ||
					trimmed.startsWith("Arguments:")
				)
					break;
				return {name, description: trimmed};
			}
		}

		// Fallback: just use the tool name
		return {
			name: toolName,
			description: "No description available",
		};
	} catch (error) {
		// Re-throw specific errors about missing commands
		if (error instanceof Error && error.message.includes("not found")) {
			throw error;
		}
		// Silently handle other errors - tool might not support -h
		return {
			name: toolName,
			description: "No description available",
		};
	}
}

async function updateReadme(tools: ToolInfo[], verbose = false): Promise<void> {
	const readmePath = join(process.cwd(), "README.md");

	// Read current README
	const readmeContent = await readFile(readmePath, "utf-8");

	// Find the Tools Included section
	const toolsSectionStart = readmeContent.indexOf("## Tools Included");
	if (toolsSectionStart === -1) {
		throw new Error("Could not find '## Tools Included' section in README.md");
	}

	// Find the next section (or end of file)
	let toolsSectionEnd = readmeContent.indexOf("\n## ", toolsSectionStart + 1);
	if (toolsSectionEnd === -1) {
		toolsSectionEnd = readmeContent.length;
	}

	// Generate new tools section
	let newToolsSection = "## Tools Included\n\n";

	// Sort tools alphabetically by name
	tools.sort((a, b) => a.name.localeCompare(b.name));

	// Create the tools list
	tools.forEach((tool) => {
		newToolsSection += `- **${tool.name}** - ${tool.description}\n`;
	});

	// Add additional section for usage examples if needed
	newToolsSection += "\n### Quick Usage\n\n";
	newToolsSection += "All tools support the `-h` or `--help` flag to display usage information:\n\n";
	newToolsSection += "```bash\n";
	newToolsSection += "# Get help for any tool\n";
	newToolsSection += "analyze-subagents -h\n";
	newToolsSection += "bra --help\n";
	newToolsSection += "```\n";

	// Replace the tools section in README
	const newReadmeContent =
		readmeContent.substring(0, toolsSectionStart) +
		newToolsSection +
		readmeContent.substring(toolsSectionEnd);

	// Write updated README
	await writeFile(readmePath, newReadmeContent, "utf-8");

	if (verbose) {
		console.log(`✅ Updated README.md with ${tools.length} tools`);
	}
}

// Run if called directly
if (import.meta.main) {
	const {values} = parseArgs({
		args: Bun.argv.slice(2),
		options: {
			verbose: {type: "boolean", short: "v"},
		},
	});

	main(values.verbose);
}
