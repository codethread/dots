// :module: Command-line markdown text stripping tool

import {parseArgs} from "util";

function showHelp() {
	console.log(`strip-markdown - Strip markdown formatting from text, optimized for text-to-speech or plain text output.

Usage:
    strip-markdown [options] < input.md
    cat file.md | strip-markdown [options]
    echo "# Hello **world**" | strip-markdown

Options:
    -f, --format FORMAT         Output format: tts (default), plain
    -p, --preserve-structure    Keep some structural hints for readability
    -h, --help                  Show this help

Formats:
    tts   - Optimized for text-to-speech (adds spoken indicators)
    plain - Basic markdown removal without TTS optimizations

Examples:
    cat README.md | strip-markdown | speak
    strip-markdown --format plain < document.md > document.txt
    echo "**bold** and *italic*" | strip-markdown

This is a Unix filter: reads from stdin, writes to stdout.
`);
}

export function stripMarkdownTTS(text: string, preserveStructure: boolean): string {
	// Remove code blocks but keep their content description
	text = text.replace(/```[\w]*\n(.*?)```/gs, preserveStructure ? "Code block:\n$1" : "Code block: $1");

	// Convert headers to spoken format
	if (preserveStructure) {
		text = text.replace(/^#{1,6}\s+(.+)$/gm, "\n$1.\n");
	} else {
		text = text.replace(/^#{1,6}\s+(.+)$/gm, "$1.");
	}

	// Remove markdown formatting
	text = text.replace(/\*\*(.+?)\*\*/g, "$1"); // Bold
	text = text.replace(/\*(.+?)\*/g, "$1"); // Italic
	text = text.replace(/`(.+?)`/g, "$1"); // Inline code

	// Convert lists to spoken format
	text = text.replace(/^[-*+]\s+/gm, "• ");
	text = text.replace(/^\d+\.\s+/gm, "");

	// Remove URLs from link text
	text = text.replace(/\[([^\]]+)\]\([^)]+\)/g, "$1");

	// Remove image references
	text = text.replace(/!\[([^\]]*)\]\([^)]+\)/g, "Image: $1");

	// Clean up tables
	text = text.replace(/\|/g, " ");
	text = text.replace(/^[-\s]+$/gm, "");

	// Remove multiple blank lines
	text = text.replace(/\n{3,}/g, "\n\n");

	// For TTS, also replace newlines with periods for better flow
	if (!preserveStructure) {
		text = text.replace(/\n\n/g, ". ").replace(/\n/g, ". ");
	}

	return text.trim();
}

function stripMarkdownPlain(text: string, preserveStructure: boolean): string {
	// Remove code blocks entirely or just the fence markers
	if (preserveStructure) {
		text = text.replace(/```[\w]*\n(.*?)```/gs, "$1");
	} else {
		text = text.replace(/```[\w]*\n(.*?)```/gs, "$1");
	}

	// Convert headers to plain text
	text = text.replace(/^#{1,6}\s+(.+)$/gm, "$1");

	// Remove markdown formatting
	text = text.replace(/\*\*(.+?)\*\*/g, "$1"); // Bold
	text = text.replace(/\*(.+?)\*/g, "$1"); // Italic
	text = text.replace(/`(.+?)`/g, "$1"); // Inline code
	text = text.replace(/~~(.+?)~~/g, "$1"); // Strikethrough

	// Convert lists to plain format
	text = text.replace(/^[-*+]\s+/gm, preserveStructure ? "  - " : "");
	text = text.replace(/^\d+\.\s+/gm, preserveStructure ? "  " : "");

	// Remove URLs from link text
	text = text.replace(/\[([^\]]+)\]\([^)]+\)/g, "$1");

	// Remove image references
	text = text.replace(/!\[([^\]]*)\]\([^)]+\)/g, preserveStructure ? "[$1]" : "");

	// Clean up tables
	text = text.replace(/^\|(.+)\|$/gm, "$1");
	text = text.replace(/\|/g, preserveStructure ? " | " : " ");
	text = text.replace(/^[-\s|]+$/gm, "");

	// Remove horizontal rules
	text = text.replace(/^---+$/gm, preserveStructure ? "\n" : "");
	text = text.replace(/^\*\*\*+$/gm, preserveStructure ? "\n" : "");

	// Clean up blockquotes
	text = text.replace(/^>\s+/gm, preserveStructure ? "  " : "");

	// Remove multiple blank lines
	text = text.replace(/\n{3,}/g, "\n\n");

	return text.trim();
}

async function main() {
	const {values} = parseArgs({
		args: Bun.argv.slice(2),
		options: {
			format: {
				type: "string",
				default: "tts",
				short: "f",
			},
			"preserve-structure": {
				type: "boolean",
				default: false,
				short: "p",
			},
			help: {
				type: "boolean",
				default: false,
				short: "h",
			},
		},
		strict: false,
		allowPositionals: true,
	});

	if (values.help) {
		showHelp();
		process.exit(0);
	}

	try {
		// Read from stdin
		const decoder = new TextDecoder();
		const chunks: Uint8Array[] = [];

		for await (const chunk of Bun.stdin.stream()) {
			chunks.push(chunk);
		}

		const input = decoder.decode(Buffer.concat(chunks));

		if (!input || input.trim().length === 0) {
			// Empty input, output empty
			process.exit(0);
		}

		const format = (values.format as string) || "tts";
		const preserveStructure = values["preserve-structure"] as boolean;

		let output: string;

		switch (format) {
			case "tts":
				output = stripMarkdownTTS(input, preserveStructure);
				break;
			case "plain":
				output = stripMarkdownPlain(input, preserveStructure);
				break;
			default:
				console.error(`Error: Unknown format '${format}'. Use 'tts' or 'plain'.`);
				process.exit(1);
		}

		// Write to stdout
		console.log(output);
	} catch (error) {
		console.error(`Error: ${error}`);
		process.exit(1);
	}
}

// Only run main if this file is executed directly, not when imported
if (import.meta.main) {
	main().catch((err) => {
		console.error(`Fatal error: ${err}`);
		process.exit(1);
	});
}
