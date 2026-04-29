// Provides a fuzzy-finder function for interactive selection of strings using fzf
interface Options {
	multi?: boolean;
	tmux?: boolean;
	header?: string;
	preview?: string;
	withNth?: string;
	tty?: boolean;
}

export async function fzf<Opts extends Options>(
	lines: string[],
	opts?: Opts,
): Promise<Opts["multi"] extends true ? string[] : string> {
	const flags = Object.entries(opts || {}).flatMap(([flag, value]) => {
		if (!value || flag === "tty") return [];
		const cliFlag = flag.replace(/[A-Z]/g, (char) => `-${char.toLowerCase()}`);
		if (typeof value === "string") return [`--${cliFlag}`, value];
		if (flag === "tmux") return ["--tmux"];
		return [`--${flag}`];
	});

	const fzf = Bun.spawn(["fzf", ...flags], {
		stdio: ["pipe", "pipe", "inherit"],
	});

	fzf.stdin.write(lines.join("\n"));
	fzf.stdin.end();

	const output = await new Response(fzf.stdout).text();
	if (opts?.multi) {
		const lines: string[] = output.split("\n").map((l) => l.trim());
		return lines as Opts["multi"] extends true ? string[] : string;
	}
	return output.trim() as Opts["multi"] extends true ? string[] : string;
}
