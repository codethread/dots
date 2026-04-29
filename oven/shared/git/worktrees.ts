// :module: Pure parsers for git worktree and branch command output

export interface Worktree {
	path: string;
	head: string | null;
	branch: string | null;
	branchRef: string | null;
	detached: boolean;
	bare: boolean;
	canonical: boolean;
	pool: {index: number; placeholder: boolean} | null;
}

function parseRecord(record: string, canonical: boolean): Worktree {
	let path: string | null = null;
	let head: string | null = null;
	let branchRef: string | null = null;
	let detached = false;
	let bare = false;

	for (const line of record.split("\n")) {
		if (line.startsWith("worktree ")) path = line.slice("worktree ".length);
		else if (line.startsWith("HEAD ")) head = line.slice("HEAD ".length);
		else if (line.startsWith("branch ")) branchRef = line.slice("branch ".length);
		else if (line === "detached") detached = true;
		else if (line === "bare") bare = true;
	}

	if (path === null) {
		throw new Error("git worktree porcelain record is missing worktree path");
	}

	const branch = branchRef?.startsWith("refs/heads/") ? branchRef.slice("refs/heads/".length) : null;
	const slotMatch = path.match(/__feat(\d+)$/);
	const pool = slotMatch
		? {
				index: Number(slotMatch[1]),
				placeholder: branchRef === `refs/heads/wk-pool/feat${slotMatch[1]}`,
			}
		: null;

	return {path, head, branch, branchRef, detached, bare, canonical, pool};
}

export function parseWorktreeList(porcelainOutput: string): Worktree[] {
	const records = porcelainOutput
		.trim()
		.split(/\n{2,}/)
		.map((record) => record.trim())
		.filter(Boolean);

	return records.map((record, index) => parseRecord(record, index === 0));
}

export function parseTrunkFromSymbolicRef(stdout: string): string | null {
	const ref = stdout.trim();
	if (ref === "") return null;
	const originPrefix = "refs/remotes/origin/";
	return ref.startsWith(originPrefix) ? ref.slice(originPrefix.length) : ref;
}

export function parseTrunkFromRemoteShow(stdout: string): string | null {
	for (const line of stdout.split("\n")) {
		const match = line.match(/^\s*HEAD branch:\s*(\S+)\s*$/);
		if (match) return match[1] === "(unknown)" ? null : match[1];
	}
	return null;
}

export function branchExistsInList(listOutput: string, branch: string): boolean {
	return listOutput
		.split("\n")
		.map((line) => line.trim().replace(/^[*+]\s*/, ""))
		.some((line) => line === branch);
}
