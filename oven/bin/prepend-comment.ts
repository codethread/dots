#!/usr/bin/env bun
// :module: Tool for adding and updating module-level documentation comments across programming languages

import {readFileSync, writeFileSync} from "fs";
import {extname, resolve} from "path";

// Map file extensions to their comment syntax
const COMMENT_SYNTAX: Record<string, string> = {
	// Shell scripts and configs
	".sh": "#",
	".bash": "#",
	".zsh": "#",
	".fish": "#",
	".nu": "#",
	".env": "#",
	".gitignore": "#",
	".dockerignore": "#",

	// JavaScript/TypeScript
	".js": "//",
	".jsx": "//",
	".ts": "//",
	".tsx": "//",
	".mjs": "//",
	".cjs": "//",

	// Rust
	".rs": "//",

	// Go
	".go": "//",

	// C/C++
	".c": "//",
	".cpp": "//",
	".cc": "//",
	".cxx": "//",
	".h": "//",
	".hpp": "//",

	// Java/Kotlin/Scala
	".java": "//",
	".kt": "//",
	".scala": "//",

	// Python
	".py": "#",
	".pyi": "#",

	// Ruby
	".rb": "#",

	// PHP
	".php": "//",

	// CSS/SCSS/LESS
	".css": "/*",
	".scss": "//",
	".sass": "//",
	".less": "//",

	// SQL
	".sql": "--",

	// YAML/TOML
	".yml": "#",
	".yaml": "#",
	".toml": "#",

	// Configuration files
	".conf": "#",
	".config": "#",
	".ini": "#",

	// Web
	".html": "<!--",
	".htm": "<!--",
	".xml": "<!--",

	// Markdown
	".md": "<!--",
	".markdown": "<!--",

	// Vim
	".vim": '"',
	".vimrc": '"',

	// Lua
	".lua": "--",
};

function showHelp() {
	console.log(`
prepend-comment - Add or update module documentation comments

Usage: prepend-comment [options] <file-path> <comment-text>

Arguments:
  file-path     Path to the file (absolute or relative to current directory)
  comment-text  Description text (without :module: prefix - added automatically)

Options:
  -h, --help    Show this help message
  -m, --module  Replace the first comment line, treating it as module-level
                documentation (for languages like Nushell, Python, etc.)

Behavior:

  DEFAULT (no flags):
    - If file has :module: comment → replaces it with new text
    - If file has no :module: comment → adds new :module: comment at top
    - Preserves shebang lines and other comments

  WITH --module FLAG:
    - Replaces the FIRST comment line with new :module: comment
    - Use when file has existing module-level documentation without :module:
    - Common in Nushell/Python files with module docstrings

Examples:

  # Add/update :module: comment (most common usage)
  prepend-comment script.sh "Shell script for automation"
    → # :module: Shell script for automation

  # Replace existing module comment that lacks :module: marker
  prepend-comment --module utils.nu "Utility functions for file operations"
    → Replaces first comment with: # :module: Utility functions for file operations

  # Update existing :module: comment (no flag needed)
  prepend-comment main.rs "Application entry point with CLI parsing"
    → Updates existing :module: line

Decision Guide:
  - File has :module: comment? → Use WITHOUT --module flag
  - File has module comment without :module:? → Use WITH --module flag
  - File has no module comment? → Use WITHOUT --module flag

Search for existing module comments:
  rg ":module:"              # Find all :module: documentation
  grep -r ":module:" .       # Alternative using grep

Supported file types:
  Shell scripts, JavaScript/TypeScript, Rust, Python, Go, C/C++, and more.
  Files without extensions are treated as shell scripts (#).
`);
}

function getCommentPrefix(filePath: string): string {
	const ext = extname(filePath).toLowerCase();

	// If no extension, assume shell script
	if (!ext) {
		return "#";
	}

	const prefix = COMMENT_SYNTAX[ext];
	if (!prefix) {
		console.warn(`Warning: Unknown file extension '${ext}', using '#' comment syntax`);
		return "#";
	}

	return prefix;
}

function formatComment(prefix: string, text: string): string {
	// Add the :module: keyword identifier before the text
	const commentWithKeyword = `:module: ${text}`;

	switch (prefix) {
		case "/*":
			return `/* ${commentWithKeyword} */`;
		case "<!--":
			return `<!-- ${commentWithKeyword} -->`;
		case "--":
			return `-- ${commentWithKeyword}`;
		case '"':
			return `" ${commentWithKeyword}`;
		default:
			return `${prefix} ${commentWithKeyword}`;
	}
}

function isCommentLine(line: string, prefix: string): boolean {
	const trimmed = line.trim();

	// Check if the line contains our :module: keyword identifier
	const hasModuleKeyword = trimmed.includes(":module:");

	switch (prefix) {
		case "/*":
			return trimmed.startsWith("/*") && trimmed.endsWith("*/") && hasModuleKeyword;
		case "<!--":
			return trimmed.startsWith("<!--") && trimmed.endsWith("-->") && hasModuleKeyword;
		case "--":
			return trimmed.startsWith("--") && hasModuleKeyword;
		case '"':
			return trimmed.startsWith('"') && hasModuleKeyword;
		default:
			return trimmed.startsWith(prefix) && hasModuleKeyword;
	}
}

function isAnyCommentLine(line: string, prefix: string): boolean {
	const trimmed = line.trim();

	switch (prefix) {
		case "/*":
			return trimmed.startsWith("/*") && trimmed.endsWith("*/");
		case "<!--":
			return trimmed.startsWith("<!--") && trimmed.endsWith("-->");
		case "--":
			return trimmed.startsWith("--");
		case '"':
			return trimmed.startsWith('"');
		default:
			return trimmed.startsWith(prefix);
	}
}

function main() {
	const args = process.argv.slice(2);

	// Check for help flag
	if (args.length === 0 || args.includes("-h") || args.includes("--help")) {
		showHelp();
		process.exit(args.length === 0 ? 1 : 0);
	}

	// Parse --module flag
	let moduleFlag = false;
	let filteredArgs = args;

	if (args.includes("--module") || args.includes("-m")) {
		moduleFlag = true;
		filteredArgs = args.filter((arg) => arg !== "--module" && arg !== "-m");
	}

	if (filteredArgs.length !== 2) {
		console.error(
			`Error: Expected exactly 2 arguments (plus optional --module flag), got ${filteredArgs.length}`,
		);
		showHelp();
		process.exit(1);
	}

	const [filePath, commentText] = filteredArgs;
	const resolvedPath = resolve(filePath);

	try {
		// Read the existing file content
		const originalContent = readFileSync(resolvedPath, "utf-8");
		const lines = originalContent.split("\n");

		// Get the appropriate comment syntax
		const commentPrefix = getCommentPrefix(resolvedPath);
		const commentLine = formatComment(commentPrefix, commentText);

		let newContent: string;
		let _action: string;
		let insertIndex = 0;

		// Check if the first line is a shebang
		const hasShebang = lines.length > 0 && lines[0].startsWith("#!");
		if (hasShebang) {
			insertIndex = 1;
		}

		// Determine if we should replace the existing comment
		let shouldReplace = false;

		if (lines.length > insertIndex) {
			// Check if line has :module: marker
			if (isCommentLine(lines[insertIndex], commentPrefix)) {
				shouldReplace = true;
			}
			// With --module flag, replace any comment line (treating it as module comment)
			else if (moduleFlag && isAnyCommentLine(lines[insertIndex], commentPrefix)) {
				shouldReplace = true;
			}
		}

		if (shouldReplace) {
			// Replace the existing comment
			lines[insertIndex] = commentLine;
			// Add blank line after module comment if next line exists and isn't blank
			if (lines.length > insertIndex + 1 && lines[insertIndex + 1].trim() !== "") {
				lines.splice(insertIndex + 1, 0, "");
			}
			newContent = lines.join("\n");
			_action = "Replaced comment in";
		} else {
			// Insert the comment after shebang (if present) or at the beginning
			if (hasShebang) {
				// Add module comment after shebang
				lines.splice(1, 0, commentLine);
				// Add blank line if next line exists and isn't blank
				if (lines.length > 2 && lines[2].trim() !== "") {
					lines.splice(2, 0, "");
				}
				newContent = lines.join("\n");
			} else {
				// Add at beginning with blank line if content follows
				if (originalContent.trim() !== "") {
					newContent = `${commentLine}\n\n${originalContent}`;
				} else {
					newContent = `${commentLine}\n${originalContent}`;
				}
			}
			_action = "Added comment to";
		}

		// Write back to the file
		writeFileSync(resolvedPath, newContent, "utf-8");
	} catch (error) {
		if (error instanceof Error) {
			console.error(`Error: ${error.message}`);
		} else {
			console.error("An unknown error occurred");
		}
		process.exit(1);
	}
}

if (import.meta.main) {
	main();
}
