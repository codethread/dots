import {describe, expect, test} from "bun:test";
import {
	ghosttyNotification,
	notificationDelivery,
	parseNotifArgs,
	tmuxIsAway,
	wrapTmuxNotification,
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

	test.each([
		{},
		{KITTY_WINDOW_ID: "1"},
		{TERM_PROGRAM: "ghostty"},
	])("uses CC Notify when away regardless of desktop backend %j", (env) => {
		expect(notificationDelivery({title: "Hello", details: "World"}, env, true)).toEqual({
			backend: "cc-notify",
		});
	});

	test.each<[NodeJS.ProcessEnv, ReturnType<typeof notificationDelivery>]>([
		[{}, {backend: "applescript"}],
		[{TMUX: "/tmp/tmux"}, {backend: "applescript"}],
		[
			{TERM_PROGRAM: "ghostty"},
			{backend: "ghostty", payload: "\x1b]777;notify;Hello;World\x1b\\", tmux: false},
		],
		[
			{TERM: "xterm-ghostty"},
			{backend: "ghostty", payload: "\x1b]777;notify;Hello;World\x1b\\", tmux: false},
		],
		[
			{GHOSTTY_RESOURCES_DIR: "/ghostty", TERM_PROGRAM: "tmux", TERM: "tmux-256color", TMUX: "/tmp/tmux"},
			{backend: "ghostty", payload: "\x1b]777;notify;Hello;World\x1b\\", tmux: true},
		],
		[{KITTY_WINDOW_ID: "1"}, {backend: "kitty", args: ["--", "Hello", "World"], tmux: false}],
		[
			{KITTY_WINDOW_ID: "1", TMUX: "/tmp/tmux"},
			{backend: "kitty", args: ["--", "Hello", "World"], tmux: true},
		],
	])("selects notification delivery for %j", (env, expected) => {
		expect(notificationDelivery({title: "Hello", details: "World"}, env)).toEqual(expected);
	});

	test("encodes Ghostty title/details without allowing delimiter or control injection", () => {
		const payload = ghosttyNotification({title: "Build; done", details: 'Quotes " ; 雪\nnext\x07\x1b\\\x00'});
		expect(payload).toBe('\x1b]777;notify;Build； done;Quotes " ; 雪\nnext\\\x1b\\');
		expect(wrapTmuxNotification(payload)).toBe(
			'\x1bPtmux;\x1b\x1b]777;notify;Build； done;Quotes " ; 雪\nnext\\\x1b\x1b\\\x1b\\',
		);
	});

	test("passes literal title/details to Kitty", () => {
		expect(
			notificationDelivery(
				{title: "--literal", details: 'Quotes " and $(commands)\nsecond line'},
				{KITTY_WINDOW_ID: "1"},
			),
		).toEqual({
			backend: "kitty",
			args: ["--", "--literal", 'Quotes " and $(commands)\nsecond line'],
			tmux: false,
		});
	});

	test("wraps all OSC chunks and doubles every inner escape for tmux", () => {
		const payload = "\x1b]99;i=test:d=0;Hello\x1b\\\x1b]99;i=test:p=body;World\x1b\\";
		expect(wrapTmuxNotification(payload)).toBe(
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
