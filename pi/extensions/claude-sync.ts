import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

type Issue = {
	level: "warning" | "info";
	message: string;
};

type SyncTargetResult = {
	label: string;
	rootDir: string | null;
	claudeDir: string | null;
	created: string[];
	issues: Issue[];
};

type SyncResult = {
	targets: SyncTargetResult[];
};

async function pathExists(filePath: string): Promise<boolean> {
	try {
		await fs.lstat(filePath);
		return true;
	} catch {
		return false;
	}
}

async function isDirectory(filePath: string): Promise<boolean> {
	try {
		return (await fs.stat(filePath)).isDirectory();
	} catch {
		return false;
	}
}

async function findNearestClaudeRoot(startCwd: string): Promise<string | null> {
	let currentDir = path.resolve(startCwd);

	while (true) {
		const claudeDir = path.join(currentDir, ".claude");
		if (await isDirectory(claudeDir)) return currentDir;

		const parentDir = path.dirname(currentDir);
		if (parentDir === currentDir) return null;
		currentDir = parentDir;
	}
}

async function listMarkdownFilesRecursively(dir: string): Promise<string[]> {
	const files: string[] = [];
	const entries = await fs.readdir(dir, { withFileTypes: true });

	for (const entry of entries) {
		const fullPath = path.join(dir, entry.name);
		if (entry.isDirectory()) {
			files.push(...(await listMarkdownFilesRecursively(fullPath)));
			continue;
		}
		if ((entry.isFile() || entry.isSymbolicLink()) && entry.name.endsWith(".md")) {
			files.push(fullPath);
		}
	}

	return files.sort();
}

function getRelativeSymlinkTarget(linkPath: string, targetPath: string): string {
	const relative = path.relative(path.dirname(linkPath), targetPath);
	return relative || ".";
}

async function ensureParentDir(dirPath: string): Promise<void> {
	await fs.mkdir(dirPath, { recursive: true });
}

async function ensureDirectoryContainer(dirPath: string, issues: Issue[]): Promise<boolean> {
	try {
		const stat = await fs.lstat(dirPath);
		if (stat.isDirectory()) return true;
		issues.push({
			level: "warning",
			message: `Expected directory at ${dirPath}, found something else. Skipping Claude prompt sync.`,
		});
		return false;
	} catch {
		await fs.mkdir(dirPath, { recursive: true });
		return true;
	}
}

async function ensureSymlink(options: {
	linkPath: string;
	targetPath: string;
	created: string[];
	issues: Issue[];
}): Promise<void> {
	const { linkPath, targetPath, created, issues } = options;
	const desiredResolvedTarget = path.resolve(targetPath);

	try {
		const stat = await fs.lstat(linkPath);
		if (!stat.isSymbolicLink()) {
			issues.push({
				level: "warning",
				message: `Path already exists and is not a symlink: ${linkPath}`,
			});
			return;
		}

		const currentRawTarget = await fs.readlink(linkPath);
		const currentResolvedTarget = path.resolve(path.dirname(linkPath), currentRawTarget);
		const currentTargetExists = await pathExists(currentResolvedTarget);

		if (!currentTargetExists) {
			issues.push({
				level: "warning",
				message: `Broken symlink detected: ${linkPath} -> ${currentRawTarget}`,
			});
			return;
		}

		if (currentResolvedTarget === desiredResolvedTarget) {
			return;
		}

		issues.push({
			level: "warning",
			message: `Symlink already points elsewhere: ${linkPath} -> ${currentRawTarget}`,
		});
	} catch {
		await ensureParentDir(path.dirname(linkPath));
		await fs.symlink(getRelativeSymlinkTarget(linkPath, targetPath), linkPath);
		created.push(linkPath);
	}
}

function commandFileToPromptName(commandsDir: string, filePath: string): string {
	const relativePath = path.relative(commandsDir, filePath);
	const withoutExtension = relativePath.replace(/\.md$/i, "");
	return `${withoutExtension.split(path.sep).join(":")}.md`;
}

async function syncClaudeTarget(options: {
	label: string;
	claudeDir: string;
	piDir: string;
	rootDir: string;
}): Promise<SyncTargetResult> {
	const { label, claudeDir, piDir, rootDir } = options;
	const issues: Issue[] = [];
	const created: string[] = [];
	const claudeSkillsDir = path.join(claudeDir, "skills");
	const claudeAgentsDir = path.join(claudeDir, "agents");
	const claudeCommandsDir = path.join(claudeDir, "commands");

	if (await pathExists(piDir)) {
		const piStat = await fs.lstat(piDir);
		if (!piStat.isDirectory()) {
			issues.push({
				level: "warning",
				message: `Expected ${piDir} to be a directory. Skipping Claude sync.`,
			});
			return { label, rootDir, claudeDir, created, issues };
		}
	} else {
		await fs.mkdir(piDir, { recursive: true });
	}

	if (await isDirectory(claudeSkillsDir)) {
		await ensureSymlink({
			linkPath: path.join(piDir, "skills"),
			targetPath: claudeSkillsDir,
			created,
			issues,
		});
	}

	if (await isDirectory(claudeAgentsDir)) {
		await ensureSymlink({
			linkPath: path.join(piDir, "agents"),
			targetPath: claudeAgentsDir,
			created,
			issues,
		});
		}

	if (await isDirectory(claudeCommandsDir)) {
		const promptsDir = path.join(piDir, "prompts");
		const canUsePromptsDir = await ensureDirectoryContainer(promptsDir, issues);
		if (!canUsePromptsDir) {
			return { label, rootDir, claudeDir, created, issues };
		}

		const commandFiles = await listMarkdownFilesRecursively(claudeCommandsDir);
		const seenPromptNames = new Map<string, string>();

		for (const commandFile of commandFiles) {
			const promptFileName = commandFileToPromptName(claudeCommandsDir, commandFile);
			const previous = seenPromptNames.get(promptFileName);
			if (previous) {
				issues.push({
					level: "warning",
					message: `Skipping duplicate Claude command mapping for ${promptFileName}: ${previous} and ${commandFile}`,
				});
				continue;
			}
			seenPromptNames.set(promptFileName, commandFile);

			await ensureSymlink({
				linkPath: path.join(promptsDir, promptFileName),
				targetPath: commandFile,
				created,
				issues,
			});
			}
		}

	return { label, rootDir, claudeDir, created, issues };
}

async function syncClaudeMappings(startCwd: string): Promise<SyncResult> {
	const targets: SyncTargetResult[] = [];

	const userClaudeDir = path.join(os.homedir(), ".claude");
	if (await isDirectory(userClaudeDir)) {
		targets.push(
			await syncClaudeTarget({
				label: "user",
				rootDir: os.homedir(),
				claudeDir: userClaudeDir,
				piDir: path.join(os.homedir(), ".pi", "agent"),
			}),
		);
	}

	const projectRootDir = await findNearestClaudeRoot(startCwd);
	if (projectRootDir) {
		targets.push(
			await syncClaudeTarget({
				label: "project",
				rootDir: projectRootDir,
				claudeDir: path.join(projectRootDir, ".claude"),
				piDir: path.join(projectRootDir, ".pi"),
			}),
		);
	}

	return { targets };
}

export default function (pi: ExtensionAPI) {
	let lastResultPromise = syncClaudeMappings(process.cwd());

	pi.on("resources_discover", async () => {
		await lastResultPromise;
		return {};
	});

	async function notifyResult(result: SyncResult, notify: (message: string, level?: "info" | "warning" | "error") => void) {
		for (const target of result.targets) {
			for (const issue of target.issues) {
				notify(`[claude-sync:${target.label}] ${issue.message}`, issue.level);
			}

			if (target.created.length > 0) {
				notify(
					`[claude-sync:${target.label}] Created ${target.created.length} symlink${target.created.length === 1 ? "" : "s"}`,
					"info",
				);
			}
		}
	}

	pi.on("session_start", async (_event, ctx) => {
		const result = await lastResultPromise;
		if (ctx.hasUI) {
			await notifyResult(result, (message, level = "info") => ctx.ui.notify(message, level));
		} else {
			for (const target of result.targets) {
				for (const issue of target.issues) console.warn(`[claude-sync:${target.label}] ${issue.message}`);
				if (target.created.length > 0) {
					console.warn(
						`[claude-sync:${target.label}] Created ${target.created.length} symlink${target.created.length === 1 ? "" : "s"}`,
					);
				}
			}
		}
	});

}
