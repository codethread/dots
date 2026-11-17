import {describe, expect, test} from "bun:test";
import {advanceState, formatBotlakeIdentity, joinRightAligned, visibleWidth} from "../bin/cc-statusline";

describe("cc-statusline alignment", () => {
	test("visibleWidth ignores ANSI colour codes", () => {
		expect(visibleWidth("\x1b[34mabc\x1b[0m")).toBe(3);
	});

	test("right-aligns to the render budget (width minus margin)", () => {
		const line = joinRightAligned("left", "right", 40);
		expect(line).toHaveLength(36);
		expect(line.startsWith("left ")).toBe(true);
		expect(line.endsWith(" right")).toBe(true);
	});

	test("falls back to a single space when width is unknown or too small", () => {
		expect(joinRightAligned("left", "right", null)).toBe("left right");
		expect(joinRightAligned("left", "right", 5)).toBe("left right");
	});

	test("formats identity like pi and strips control characters", () => {
		expect(formatBotlakeIdentity("jade-rich-guan")).toBe("bl: jade-rich-guan");
		expect(formatBotlakeIdentity("a\x1b[31mb\n")).toBe("bl: a [31mb");
	});
});

describe("advanceState", () => {
	test("first observation records the duration without inventing a message time", () => {
		expect(advanceState({}, 100, 5)).toEqual({apiMs: 100});
	});

	test("a changed duration stamps the message time", () => {
		expect(advanceState({apiMs: 100}, 250, 9)).toEqual({apiMs: 250, lastMessageAt: 9});
	});

	test("an unchanged duration keeps the same state object", () => {
		const prev = {apiMs: 250, lastMessageAt: 9};
		expect(advanceState(prev, 250, 99)).toBe(prev);
	});
});
