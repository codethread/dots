import type { AssistantMessage } from "@mariozechner/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";
import { formatContextDisplay, formatCost, formatModelDisplay } from "./usage-format.js";

function sanitizeStatusText(text: string): string {
	return text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim();
}

function shortenHome(path: string): string {
	const home = process.env.HOME || process.env.USERPROFILE;
	if (home && path.startsWith(home)) return `~${path.slice(home.length)}`;
	return path;
}

export default function (pi: ExtensionAPI) {
	const installFooter = (ctx: ExtensionContext) => {
		ctx.ui.setFooter((tui, theme, footerData) => {
			const unsubscribe = footerData.onBranchChange(() => tui.requestRender());

			return {
				dispose: unsubscribe,
				invalidate() {},
				render(width: number): string[] {
					let pwd = shortenHome(ctx.cwd);
					const branch = footerData.getGitBranch();
					if (branch) pwd = `${pwd} (${branch})`;

					const sessionName = ctx.sessionManager.getSessionName();
					if (sessionName) pwd = `${pwd} • ${sessionName}`;

					let totalCost = 0;
					for (const entry of ctx.sessionManager.getBranch()) {
						if (entry.type === "message" && entry.message.role === "assistant") {
							const assistant = entry.message as AssistantMessage;
							totalCost += assistant.usage.cost.total;
						}
					}

					const contextUsage = ctx.getContextUsage();
					const contextWindow = contextUsage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
					const contextTokens = contextUsage?.tokens ?? null;
					const contextPercentValue = contextUsage?.percent ?? 0;
					const usingSubscription = ctx.model ? ctx.modelRegistry.isUsingOAuth(ctx.model) : false;

					const contextDisplay = formatContextDisplay({
						contextTokens,
						contextWindow,
						contextPercent: contextUsage?.percent,
					});
					const costDisplay = formatCost(totalCost, usingSubscription, 3);

					let styledContextDisplay = theme.fg("dim", contextDisplay);
					if (contextPercentValue > 90) {
						styledContextDisplay = theme.fg("error", contextDisplay);
					} else if (contextPercentValue > 70) {
						styledContextDisplay = theme.fg("warning", contextDisplay);
					}

					const leftParts = [styledContextDisplay, theme.fg("dim", costDisplay)];
					let leftSide = leftParts.join(" ");
					let leftSideWidth = visibleWidth(leftSide);
					if (leftSideWidth > width) {
						leftSide = truncateToWidth(leftSide, width, theme.fg("dim", "..."));
						leftSideWidth = visibleWidth(leftSide);
					}

					const rightSide = formatModelDisplay({
						provider: footerData.getAvailableProviderCount() > 1 ? ctx.model?.provider : undefined,
						model: ctx.model?.id,
						thinkingLevel: pi.getThinkingLevel(),
						reasoning: ctx.model?.reasoning,
						includeProvider: footerData.getAvailableProviderCount() > 1,
					});

					const minPadding = 2;
					const rightSideWidth = visibleWidth(rightSide);
					const totalNeeded = leftSideWidth + minPadding + rightSideWidth;
					let statsLine: string;
					if (totalNeeded <= width) {
						const padding = " ".repeat(width - leftSideWidth - rightSideWidth);
						statsLine = leftSide + padding + theme.fg("dim", rightSide);
					} else {
						const availableForRight = width - leftSideWidth - minPadding;
						if (availableForRight > 0) {
							const truncatedRight = truncateToWidth(theme.fg("dim", rightSide), availableForRight, "");
							const padding = " ".repeat(Math.max(0, width - leftSideWidth - visibleWidth(truncatedRight)));
							statsLine = leftSide + padding + truncatedRight;
						} else {
							statsLine = leftSide;
						}
					}

					const lines = [truncateToWidth(theme.fg("dim", pwd), width, theme.fg("dim", "...")), statsLine];

					const extensionStatuses = footerData.getExtensionStatuses();
					if (extensionStatuses.size > 0) {
						const sortedStatuses = Array.from(extensionStatuses.entries())
							.sort(([a], [b]) => a.localeCompare(b))
							.map(([, text]) => sanitizeStatusText(text));
						const statusLine = sortedStatuses.join(" ");
						lines.push(truncateToWidth(statusLine, width, theme.fg("dim", "...")));
					}

					return lines;
				},
			};
		});
	};

	pi.on("session_start", (_event, ctx) => installFooter(ctx));
	pi.on("session_switch", (_event, ctx) => installFooter(ctx));
}
