import {afterAll, beforeAll, describe, expect, test} from "bun:test";
import {existsSync, mkdtempSync, readFileSync, unlinkSync} from "fs";
import {tmpdir} from "os";
import {join} from "path";
import {ccBridgeInstall, ccBridgeServe} from "../bin/cc-bridge";

describe("ccBridgeInstall", () => {
	let tempDir: string;

	beforeAll(() => {
		tempDir = mkdtempSync(join(tmpdir(), "cc-bridge-test-"));
	});

	test("creates executable shim scripts", () => {
		ccBridgeInstall(["obsidian", "tmux"], tempDir);

		const obsidianShim = join(tempDir, "obsidian");
		const tmuxShim = join(tempDir, "tmux");

		expect(existsSync(obsidianShim)).toBe(true);
		expect(existsSync(tmuxShim)).toBe(true);

		const obsidianContent = readFileSync(obsidianShim, "utf-8");
		expect(obsidianContent).toContain("#!/usr/bin/env bash");
		expect(obsidianContent).toContain("cc-bridge exec obsidian");
		expect(obsidianContent).toContain('"$@"');

		const tmuxContent = readFileSync(tmuxShim, "utf-8");
		expect(tmuxContent).toContain("cc-bridge exec tmux");
	});

	test("creates all requested shims", () => {
		const commands = ["cmd1", "cmd2", "cmd3"];
		ccBridgeInstall(commands, tempDir);

		for (const cmd of commands) {
			expect(existsSync(join(tempDir, cmd))).toBe(true);
		}
	});
});

describe("cc-bridge serve + exec", () => {
	const socketPath = join(tmpdir(), `cc-bridge-test-${Date.now()}.sock`);
	beforeAll(async () => {
		// Start server in background — it never resolves, so don't await it
		ccBridgeServe(["echo", "cat"], socketPath);
		// Give server time to bind
		await Bun.sleep(100);
	});

	afterAll(() => {
		if (existsSync(socketPath)) {
			unlinkSync(socketPath);
		}
	});

	test("socket file is created", () => {
		expect(existsSync(socketPath)).toBe(true);
	});

	test("executes allowed command and returns output", async () => {
		const request = `${JSON.stringify({cmd: "echo", args: ["hello", "world"]})}\n`;
		let responseData = "";

		const result = await new Promise<{exitCode: number; stdout: string; stderr: string}>(
			(resolve, reject) => {
				Bun.connect({
					unix: socketPath,
					socket: {
						open(socket) {
							socket.write(request);
						},
						data(_socket, data) {
							responseData += data.toString();
						},
						close() {
							try {
								resolve(JSON.parse(responseData.trim()));
							} catch (e) {
								reject(e);
							}
						},
						error(_socket, error) {
							reject(error);
						},
					},
				}).catch(reject);
			},
		);

		expect(result.exitCode).toBe(0);
		expect(result.stdout.trim()).toBe("hello world");
		expect(result.stderr).toBe("");
	});

	test("rejects disallowed commands", async () => {
		const request = `${JSON.stringify({cmd: "rm", args: ["-rf", "/"]})}\n`;
		let responseData = "";

		const result = await new Promise<{exitCode: number; stdout: string; stderr: string}>(
			(resolve, reject) => {
				Bun.connect({
					unix: socketPath,
					socket: {
						open(socket) {
							socket.write(request);
						},
						data(_socket, data) {
							responseData += data.toString();
						},
						close() {
							try {
								resolve(JSON.parse(responseData.trim()));
							} catch (e) {
								reject(e);
							}
						},
						error(_socket, error) {
							reject(error);
						},
					},
				}).catch(reject);
			},
		);

		expect(result.exitCode).toBe(1);
		expect(result.stderr).toContain("Command not allowed: rm");
	});

	test("handles invalid JSON gracefully", async () => {
		let responseData = "";

		const result = await new Promise<{exitCode: number; stdout: string; stderr: string}>(
			(resolve, reject) => {
				Bun.connect({
					unix: socketPath,
					socket: {
						open(socket) {
							socket.write("not json\n");
						},
						data(_socket, data) {
							responseData += data.toString();
						},
						close() {
							try {
								resolve(JSON.parse(responseData.trim()));
							} catch (e) {
								reject(e);
							}
						},
						error(_socket, error) {
							reject(error);
						},
					},
				}).catch(reject);
			},
		);

		expect(result.exitCode).toBe(1);
		expect(result.stderr).toContain("Invalid request");
	});

	test("handles multiple concurrent requests", async () => {
		const makeRequest = (msg: string) => {
			const request = `${JSON.stringify({cmd: "echo", args: [msg]})}\n`;
			let responseData = "";
			return new Promise<{exitCode: number; stdout: string; stderr: string}>((resolve, reject) => {
				Bun.connect({
					unix: socketPath,
					socket: {
						open(socket) {
							socket.write(request);
						},
						data(_socket, data) {
							responseData += data.toString();
						},
						close() {
							try {
								resolve(JSON.parse(responseData.trim()));
							} catch (e) {
								reject(e);
							}
						},
						error(_socket, error) {
							reject(error);
						},
					},
				}).catch(reject);
			});
		};

		const results = await Promise.all([makeRequest("one"), makeRequest("two"), makeRequest("three")]);

		expect(results).toHaveLength(3);
		const outputs = results.map((r) => r.stdout.trim()).sort();
		expect(outputs).toEqual(["one", "three", "two"]);
	});
});
