/**
 * Agent discovery and configuration
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { getAgentDir, parseFrontmatter } from "@mariozechner/pi-coding-agent";

export type AgentScope = "user" | "project" | "both";

export interface AgentConfig {
	name: string;
	description: string;
	tools?: string[];
	model?: string;
	systemPrompt: string;
	source: "user" | "project";
	filePath: string;
}

export interface AgentDiscoveryResult {
	agents: AgentConfig[];
	projectAgentsDir: string | null;
}

const PI_BUILTIN_TOOLS = new Set(["read", "bash", "edit", "write", "grep", "find", "ls"]);

const CLAUDE_TOOL_MAP: Record<string, string | null> = {
	read: "read",
	bash: "bash",
	edit: "edit",
	write: "write",
	grep: "grep",
	glob: "find",
	ls: "ls",
	multiedit: "edit",
	notebookedit: "edit",
	task: null,
	websearch: null,
	webfetch: null,
	skill: null,
};

interface PiSettings {
	defaultProvider?: string;
	defaultModel?: string;
	enabledModels?: string[];
}

function normalizeTools(rawTools: string[] | undefined): string[] | undefined {
	if (!rawTools || rawTools.length === 0) return undefined;

	const mapped = rawTools
		.map((tool) => tool.trim())
		.filter(Boolean)
		.map((tool) => {
			const lower = tool.toLowerCase();
			if (PI_BUILTIN_TOOLS.has(lower)) return lower;
			return CLAUDE_TOOL_MAP[lower] ?? null;
		})
		.filter((tool): tool is string => Boolean(tool) && PI_BUILTIN_TOOLS.has(tool));

	const unique = Array.from(new Set(mapped));
	return unique.length > 0 ? unique : undefined;
}

function readJsonFile<T>(filePath: string): T | null {
	try {
		if (!fs.existsSync(filePath)) return null;
		const raw = fs.readFileSync(filePath, "utf-8");
		return JSON.parse(raw) as T;
	} catch {
		return null;
	}
}

function findNearestSettingsFile(cwd: string): string | null {
	let currentDir = cwd;
	while (true) {
		const candidate = path.join(currentDir, "pi", "settings.json");
		if (fs.existsSync(candidate)) return candidate;

		const parentDir = path.dirname(currentDir);
		if (parentDir === currentDir) break;
		currentDir = parentDir;
	}

	const userSettings = path.join(getAgentDir(), "settings.json");
	if (fs.existsSync(userSettings)) return userSettings;
	return null;
}

function pickPreferredModel(models: string[], preferMini: boolean): string | undefined {
	if (models.length === 0) return undefined;
	if (preferMini) return models.find((m) => m.toLowerCase().includes("mini")) ?? models[0];
	return models.find((m) => !m.toLowerCase().includes("mini")) ?? models[0];
}

function resolveModelAlias(model: string | undefined, settings: PiSettings | null): string | undefined {
	if (!model) return undefined;

	const trimmed = model.trim();
	if (!trimmed) return undefined;
	if (trimmed.includes("/")) return trimmed;

	const lower = trimmed.toLowerCase();
	const enabled = settings?.enabledModels?.filter((m): m is string => typeof m === "string") ?? [];
	const openAiEnabled = enabled.filter((m) => m.startsWith("openai-codex/") || m.startsWith("openai/"));

	if (openAiEnabled.length === 0) return trimmed;

	const defaultQualified =
		settings?.defaultProvider && settings?.defaultModel
			? `${settings.defaultProvider}/${settings.defaultModel}`
			: undefined;
	const defaultEnabled = defaultQualified && openAiEnabled.includes(defaultQualified) ? defaultQualified : undefined;

	const fallbackLarge = defaultEnabled ?? pickPreferredModel(openAiEnabled, false);
	const fallbackMini = pickPreferredModel(openAiEnabled, true) ?? fallbackLarge;

	if (lower.includes("haiku")) return fallbackMini;
	if (lower.includes("sonnet") || lower.includes("opus") || lower.startsWith("claude")) return fallbackLarge;

	return trimmed;
}

function loadAgentsFromDir(
	dir: string,
	source: "user" | "project",
	settings: PiSettings | null,
): AgentConfig[] {
	const agents: AgentConfig[] = [];

	if (!fs.existsSync(dir)) {
		return agents;
	}

	let entries: fs.Dirent[];
	try {
		entries = fs.readdirSync(dir, { withFileTypes: true });
	} catch {
		return agents;
	}

	for (const entry of entries) {
		if (!entry.name.endsWith(".md")) continue;
		if (!entry.isFile() && !entry.isSymbolicLink()) continue;

		const filePath = path.join(dir, entry.name);
		let content: string;
		try {
			content = fs.readFileSync(filePath, "utf-8");
		} catch {
			continue;
		}

		const { frontmatter, body } = parseFrontmatter<Record<string, string>>(content);

		if (!frontmatter.name || !frontmatter.description) {
			continue;
		}

		const parsedTools = frontmatter.tools
			?.split(",")
			.map((t: string) => t.trim())
			.filter(Boolean);

		agents.push({
			name: frontmatter.name,
			description: frontmatter.description,
			tools: normalizeTools(parsedTools),
			model: resolveModelAlias(frontmatter.model, settings),
			systemPrompt: body,
			source,
			filePath,
		});
	}

	return agents;
}

function isDirectory(p: string): boolean {
	try {
		return fs.statSync(p).isDirectory();
	} catch {
		return false;
	}
}

function findNearestProjectAgentsDir(cwd: string): string | null {
	let currentDir = cwd;
	while (true) {
		const candidate = path.join(currentDir, ".pi", "agents");
		if (isDirectory(candidate)) return candidate;

		const parentDir = path.dirname(currentDir);
		if (parentDir === currentDir) return null;
		currentDir = parentDir;
	}
}

export function discoverAgents(cwd: string, scope: AgentScope): AgentDiscoveryResult {
	const userDir = path.join(getAgentDir(), "agents");
	const projectAgentsDir = findNearestProjectAgentsDir(cwd);
	const settingsPath = findNearestSettingsFile(cwd);
	const settings = settingsPath ? readJsonFile<PiSettings>(settingsPath) : null;

	const userAgents = scope === "project" ? [] : loadAgentsFromDir(userDir, "user", settings);
	const projectAgents =
		scope === "user" || !projectAgentsDir ? [] : loadAgentsFromDir(projectAgentsDir, "project", settings);

	const agentMap = new Map<string, AgentConfig>();

	if (scope === "both") {
		for (const agent of userAgents) agentMap.set(agent.name, agent);
		for (const agent of projectAgents) agentMap.set(agent.name, agent);
	} else if (scope === "user") {
		for (const agent of userAgents) agentMap.set(agent.name, agent);
	} else {
		for (const agent of projectAgents) agentMap.set(agent.name, agent);
	}

	return { agents: Array.from(agentMap.values()), projectAgentsDir };
}

export function formatAgentList(agents: AgentConfig[], maxItems: number): { text: string; remaining: number } {
	if (agents.length === 0) return { text: "none", remaining: 0 };
	const listed = agents.slice(0, maxItems);
	const remaining = agents.length - listed.length;
	return {
		text: listed.map((a) => `${a.name} (${a.source}): ${a.description}`).join("; "),
		remaining,
	};
}
