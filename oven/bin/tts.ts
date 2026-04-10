// :module: Basic OpenAI text-to-speech wrapper

import {tmpdir} from "os";
import {join} from "path";
import {parseArgs} from "util";
import {report} from "../shared/report";
import {stripMarkdownTTS} from "./strip-markdown";

function showHelp() {
	console.log(`tts - Basic OpenAI text-to-speech wrapper

Usage: tts [options] [text...]

Reads text from args or stdin, strips markdown, sends it to OpenAI, and writes the audio response to a file.

Options:
    --voice VOICE            Voice to request (default: alloy)
    --format FORMAT          Output format: mp3, wav, opus, flac, pcm (default: mp3)
    --model MODEL            OpenAI model to request (default: gpt-4o-mini-tts)
    --out PATH               Output file path (default: temp file)
    --help, -h               Show this help

Examples:
    echo "# Hello **world**" | tts
    tts "Read this out loud"
    cat README.md | tts --out /tmp/readme.mp3
    cat README.md | tts | speak
`);
}

export type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

export interface TtsOptions {
	text: string;
	apiKey?: string;
	voice?: string;
	format?: string;
	model?: string;
	outputPath?: string;
	fetchImpl?: FetchLike;
}

export interface TtsResult {
	outputPath: string;
	strippedText: string;
}

const DEFAULT_VOICE = "alloy";
const DEFAULT_FORMAT = "mp3";
const DEFAULT_MODEL = "gpt-4o-mini-tts";
const OPENAI_SPEECH_URL = "https://api.openai.com/v1/audio/speech";

async function main() {
	const {values, positionals} = parseArgs({
		args: Bun.argv.slice(2),
		options: {
			voice: {type: "string", default: DEFAULT_VOICE},
			format: {type: "string", default: DEFAULT_FORMAT},
			model: {type: "string", default: DEFAULT_MODEL},
			out: {type: "string"},
			help: {type: "boolean", short: "h", default: false},
		},
		strict: false,
		allowPositionals: true,
	});

	if (values.help) {
		showHelp();
		process.exit(0);
	}

	const text = await resolveInputText(positionals);
	if (!text) {
		console.error("Error: provide text as args or via stdin");
		process.exit(1);
	}

	try {
		const result = await ttsLib({
			text,
			voice: typeof values.voice === "string" ? values.voice : undefined,
			format: typeof values.format === "string" ? values.format : undefined,
			model: typeof values.model === "string" ? values.model : undefined,
			outputPath: typeof values.out === "string" ? values.out : undefined,
		});
		report(result.outputPath);
	} catch (error) {
		console.error(`Error: ${error instanceof Error ? error.message : String(error)}`);
		process.exit(1);
	}
}

export async function ttsLib(options: TtsOptions): Promise<TtsResult> {
	const fetchImpl = options.fetchImpl ?? fetch;
	const apiKey = options.apiKey ?? (await resolveOpenAiApiKey());
	const strippedText = stripMarkdownTTS(options.text, false);

	if (!strippedText) {
		throw new Error("No text to send after markdown stripping");
	}

	const outputPath = options.outputPath ?? defaultOutputPath(options.format ?? DEFAULT_FORMAT);
	const response = await fetchImpl(OPENAI_SPEECH_URL, {
		method: "POST",
		headers: {
			Authorization: `Bearer ${apiKey}`,
			"Content-Type": "application/json",
		},
		body: JSON.stringify({
			model: options.model ?? DEFAULT_MODEL,
			voice: options.voice ?? DEFAULT_VOICE,
			input: strippedText,
			response_format: options.format ?? DEFAULT_FORMAT,
		}),
	});

	if (!response.ok) {
		const errorText = await response.text();
		throw new Error(`OpenAI request failed (${response.status}): ${errorText}`);
	}

	await Bun.write(outputPath, new Uint8Array(await response.arrayBuffer()));
	return {outputPath, strippedText};
}

async function resolveInputText(positionals: string[]): Promise<string> {
	if (positionals.length > 0) {
		return positionals.join(" ").trim();
	}

	if (process.stdin.isTTY) {
		return "";
	}

	return (await new Response(Bun.stdin.stream()).text()).trim();
}

async function resolveOpenAiApiKey(): Promise<string> {
	const envKey = process.env.OPENAI_API_KEY?.trim();
	if (envKey) {
		return envKey;
	}

	const home = process.env.HOME;
	if (!home) {
		throw new Error("Missing HOME and OPENAI_API_KEY");
	}

	try {
		const authPath = join(home, ".pi/agent/auth.json");
		const auth = (await Bun.file(authPath).json()) as {
			openai?: {key?: string};
		};
		const fileKey = auth.openai?.key?.trim();
		if (fileKey) {
			return fileKey;
		}
	} catch {
		// fall through to final error
	}

	throw new Error("Missing OpenAI API key in OPENAI_API_KEY or ~/.pi/agent/auth.json");
}

function defaultOutputPath(format: string): string {
	return join(tmpdir(), `tts-${crypto.randomUUID()}.${format}`);
}

if (import.meta.main) {
	main();
}
