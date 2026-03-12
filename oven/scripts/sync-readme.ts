import {$} from "bun";
import {access, readdir, readFile, writeFile} from "fs/promises";
import {basename, join} from "path";
import {parseArgs} from "util";

interface ToolInfo {
	name: string;
	description: string;
	usage?: string;
}

async function main(verbose = false) {
	try {
		// Get all TypeScript files in bin directory
		const binDir = join(process.cwd(), "bin");
		const files = await readdir(binDir);
		const tsFiles = files
			.filter((file) => file.endsWith(".ts"))
			.filter((file) => !file.includes(".test.")) // Exclude test files
			.map((file) => basename(file, ".ts")); // Remove .ts extension to get executable names

		if (verbose) {
			console.log(`Found ${tsFiles.length} TypeScript files in bin/`);
			console.log("Extracting help information from built executables...");
		}

		// Extract help information from all tools in parallel
		const toolPromises = tsFiles.map((toolName) => {
			return extractHelpInfo(toolName);
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

async function extractHelpInfo(toolName: string): Promise<ToolInfo | null> {
	try {
		// Prefer the built executable path to avoid PATH differences across shells/devshells.
		const commandPath = await resolveToolPath(toolName);
		const result = await $`${commandPath} -h`.nothrow().quiet();

		// Check if the command was found
		if (result.stderr?.toString().includes("command not found")) {
			throw new Error(`Command '${toolName}' not found. Please run 'bun run build' first.`);
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

async function resolveToolPath(toolName: string): Promise<string> {
	if (process.env.HOME) {
		const userBinaryPath = join(process.env.HOME, ".local", "bin", toolName);
		try {
			await access(userBinaryPath);
			return userBinaryPath;
		} catch {
			// Fall through to PATH lookup.
		}
	}

	return toolName;
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
