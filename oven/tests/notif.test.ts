import {describe, expect, test} from "bun:test";
import {
	ghosttyPayload,
	parseNotifArgs,
	terminalProtocol,
	tmuxIsAway,
	wrapTmuxPassthrough,
} from "../bin/notif";

describe("notif", () => {
	test.each([
		["", true],
		["\n", true],
		["821\n", false],
		["820\n", true],
		["819\n", true],
		["700\n999\n", false],
		["999\n700\n", false],
		["700\n800\n", true],
	])("detects tmux inactivity from %j", (activity, away) => {
		expect(tmuxIsAway(activity, 1000)).toBe(away);
	});

	test("rejects invalid tmux activity instead of silently choosing a channel", () => {
		expect(() => tmuxIsAway("not-a-timestamp", 1000)).toThrow("Invalid tmux client_activity");
	});

	test.each<[NodeJS.ProcessEnv, ReturnType<typeof terminalProtocol>]>([
		[{}, undefined],
		[{TMUX: "/tmp/tmux", TERM_PROGRAM: "tmux", TERM: "tmux-256color"}, undefined],
		[{TERM_PROGRAM: "ghostty"}, "ghostty"],
		[{TERM: "xterm-ghostty"}, "ghostty"],
		[{GHOSTTY_RESOURCES_DIR: "/ghostty", TERM_PROGRAM: "tmux", TMUX: "/tmp/tmux"}, "ghostty"],
		[{KITTY_WINDOW_ID: "1"}, "kitty"],
		[{KITTY_WINDOW_ID: "1", TMUX: "/tmp/tmux"}, "kitty"],
	])("detects the terminal protocol from %j", (env, expected) => {
		expect(terminalProtocol(env)).toBe(expected);
	});

	test("encodes Ghostty title/details without allowing delimiter or control injection", () => {
		const payload = ghosttyPayload({title: "Build; done", details: 'Quotes " ; 雪\nnext\x07\x1b\\\x00'});
		expect(payload).toBe('\x1b]777;notify;Build； done;Quotes " ; 雪\nnext\\\x1b\\');
		expect(wrapTmuxPassthrough(payload)).toBe(
			'\x1bPtmux;\x1b\x1b]777;notify;Build； done;Quotes " ; 雪\nnext\\\x1b\x1b\\\x1b\\',
		);
	});

	test("wraps all OSC chunks and doubles every inner escape for tmux", () => {
		const payload = "\x1b]99;i=test:d=0;Hello\x1b\\\x1b]99;i=test:p=body;World\x1b\\";
		expect(wrapTmuxPassthrough(payload)).toBe(
			"\x1bPtmux;\x1b\x1b]99;i=test:d=0;Hello\x1b\x1b\\\x1b\x1b]99;i=test:p=body;World\x1b\x1b\\\x1b\\",
		);
	});

	test("parses title and details", () => {
		expect(parseNotifArgs(["Hello", "some", "details"])).toEqual({
			title: "Hello",
			details: "some details",
		});
		expect(parseNotifArgs(["Hello"])).toEqual({title: "Hello", details: ""});
	});

	test("requires a title and supports help without one", () => {
		expect(() => parseNotifArgs([])).toThrow("title is required");
		expect(parseNotifArgs(["--help"])).toBeUndefined();
	});
});
