// :module: Git command execution utilities for wktree

export interface GitResult {
	stdout: string;
	stderr: string;
	exitCode: number;
}

export interface GitRunner {
	run(args: string[], opts?: {cwd?: string}): Promise<GitResult>;
	runRaw(args: string[], opts?: {cwd?: string}): Promise<GitResult>;
}

export class GitError extends Error {
	constructor(
		public args: string[],
		public stderr: string,
		public gitExitCode: number,
	) {
		super(`git ${args.join(" ")} failed: ${stderr.trim()}`);
		this.name = "GitError";
	}
}

export class LiveGitRunner implements GitRunner {
	async run(args: string[], opts: {cwd?: string} = {}): Promise<GitResult> {
		const result = await this.runRaw(args, opts);
		if (result.exitCode !== 0) {
			throw new GitError(args, result.stderr, result.exitCode);
		}
		return result;
	}

	async runRaw(args: string[], opts: {cwd?: string} = {}): Promise<GitResult> {
		const proc = Bun.spawn(["git", ...args], {
			cwd: opts.cwd,
			stdout: "pipe",
			stderr: "pipe",
		});

		const [stdout, stderr, exitCode] = await Promise.all([
			new Response(proc.stdout).text(),
			new Response(proc.stderr).text(),
			proc.exited,
		]);

		return {stdout, stderr, exitCode};
	}
}
