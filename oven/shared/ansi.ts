// :module: ANSI color codes and formatting utilities

/**
 * ANSI escape codes for terminal colors and formatting
 */
export const ANSI = {
	// Reset
	reset: "\x1b[0m",

	// Colors
	black: "\x1b[30m",
	red: "\x1b[31m",
	green: "\x1b[32m",
	yellow: "\x1b[33m",
	blue: "\x1b[34m",
	magenta: "\x1b[35m",
	cyan: "\x1b[36m",
	white: "\x1b[37m",

	// Bright colors
	brightBlack: "\x1b[90m",
	brightRed: "\x1b[91m",
	brightGreen: "\x1b[92m",
	brightYellow: "\x1b[93m",
	brightBlue: "\x1b[94m",
	brightMagenta: "\x1b[95m",
	brightCyan: "\x1b[96m",
	brightWhite: "\x1b[97m",

	// Styles
	bold: "\x1b[1m",
	dim: "\x1b[2m",
	italic: "\x1b[3m",
	underline: "\x1b[4m",
	blink: "\x1b[5m",
	reverse: "\x1b[7m",
	hidden: "\x1b[8m",
} as const;

/**
 * Helper functions to colorize text
 */
export const colorize = {
	red: (text: string | number) => `${ANSI.red}${text}${ANSI.reset}`,
	green: (text: string | number) => `${ANSI.green}${text}${ANSI.reset}`,
	yellow: (text: string | number) => `${ANSI.yellow}${text}${ANSI.reset}`,
	blue: (text: string | number) => `${ANSI.blue}${text}${ANSI.reset}`,
	magenta: (text: string | number) => `${ANSI.magenta}${text}${ANSI.reset}`,
	cyan: (text: string | number) => `${ANSI.cyan}${text}${ANSI.reset}`,
	white: (text: string | number) => `${ANSI.white}${text}${ANSI.reset}`,
	dim: (text: string | number) => `${ANSI.dim}${text}${ANSI.reset}`,
	bold: (text: string | number) => `${ANSI.bold}${text}${ANSI.reset}`,
	italic: (text: string | number) => `${ANSI.italic}${text}${ANSI.reset}`,
	underline: (text: string | number) => `${ANSI.underline}${text}${ANSI.reset}`,
	// Dimmed colors
	dimRed: (text: string | number) => `${ANSI.dim}${ANSI.red}${text}${ANSI.reset}`,
	dimGreen: (text: string | number) => `${ANSI.dim}${ANSI.green}${text}${ANSI.reset}`,
	dimYellow: (text: string | number) => `${ANSI.dim}${ANSI.yellow}${text}${ANSI.reset}`,
	dimBlue: (text: string | number) => `${ANSI.dim}${ANSI.blue}${text}${ANSI.reset}`,
	dimMagenta: (text: string | number) => `${ANSI.dim}${ANSI.magenta}${text}${ANSI.reset}`,
	dimCyan: (text: string | number) => `${ANSI.dim}${ANSI.cyan}${text}${ANSI.reset}`,
	dimItalic: (text: string | number) => `${ANSI.dim}${ANSI.italic}${text}${ANSI.reset}`,
	brightBlack: (text: string | number) => `${ANSI.brightBlack}${text}${ANSI.reset}`,
} as const;
