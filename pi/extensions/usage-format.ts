import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (_pi: ExtensionAPI) {}

export interface ContextUsageDisplayOptions {
	contextTokens: number | null | undefined;
	contextWindow?: number;
	contextPercent?: number | null;
	autoCompactEnabled?: boolean;
}

export interface ModelDisplayOptions {
	provider?: string;
	model?: string;
	thinkingLevel?: string;
	reasoning?: boolean;
	includeProvider?: boolean;
}

export function formatTokens(count: number): string {
	if (count < 1000) return count.toString();
	if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1000000) return `${Math.round(count / 1000)}k`;
	if (count < 10000000) return `${(count / 1000000).toFixed(1)}M`;
	return `${Math.round(count / 1000000)}M`;
}

export function formatCost(cost: number, usingSubscription = false, digits = 3): string {
	return `$${cost.toFixed(digits)}${usingSubscription ? " (sub)" : ""}`;
}

export function formatContextDisplay(options: ContextUsageDisplayOptions): string {
	const autoSuffix = options.autoCompactEnabled ? " (auto)" : "";
	const contextWindow = options.contextWindow ?? 0;
	const contextTokens = options.contextTokens ?? null;
	const contextPercent = options.contextPercent ?? null;

	if (contextWindow > 0) {
		if (contextTokens !== null && contextPercent !== null) {
			return `ctx ${formatTokens(contextTokens)} ${contextPercent.toFixed(1)}%/${formatTokens(contextWindow)}${autoSuffix}`;
		}
		return `ctx ? ?/${formatTokens(contextWindow)}${autoSuffix}`;
	}

	if (contextTokens !== null) return `ctx ${formatTokens(contextTokens)}${autoSuffix}`;
	return "ctx n/a";
}

export function formatModelDisplay(options: ModelDisplayOptions): string {
	const modelName = options.model || "no-model";
	let result = modelName;

	if (options.reasoning) {
		const thinkingLevel = options.thinkingLevel || "off";
		result = thinkingLevel === "off" ? `${modelName} • thinking off` : `${modelName} • ${thinkingLevel}`;
	}

	if (options.includeProvider && options.provider) {
		result = `(${options.provider}) ${result}`;
	}

	return result;
}
