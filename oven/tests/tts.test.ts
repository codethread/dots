import {afterEach, describe, expect, test} from "bun:test";
import {mkdtemp, rm} from "fs/promises";
import {tmpdir} from "os";
import {join} from "path";
import {ttsLib} from "../bin/tts";

describe("ttsLib", () => {
	const cleanupPaths: string[] = [];

	afterEach(async () => {
		await Promise.all(cleanupPaths.splice(0).map((path) => rm(path, {recursive: true, force: true})));
	});

	test("strips markdown, sends request, and writes audio file", async () => {
		const dir = await mkdtemp(join(tmpdir(), "tts-test-"));
		cleanupPaths.push(dir);
		const outputPath = join(dir, "output.mp3");

		let requestBody = "";
		const result = await ttsLib({
			text: "# Hello **world**",
			apiKey: "test-key",
			outputPath,
			fetchImpl: async (_input, init) => {
				requestBody = String(init?.body ?? "");
				return new Response(new Uint8Array([1, 2, 3]), {status: 200});
			},
		});

		expect(result.outputPath).toBe(outputPath);
		expect(result.strippedText).toBe("Hello world.");
		expect(JSON.parse(requestBody)).toMatchObject({
			model: "gpt-4o-mini-tts",
			voice: "alloy",
			input: "Hello world.",
			response_format: "mp3",
		});
		expect(await Bun.file(outputPath).bytes()).toEqual(new Uint8Array([1, 2, 3]));
	});

	test("throws on api failure", async () => {
		await expect(
			ttsLib({
				text: "hello",
				apiKey: "test-key",
				fetchImpl: async () => new Response("bad request", {status: 400}),
			}),
		).rejects.toThrow("OpenAI request failed (400): bad request");
	});
});
