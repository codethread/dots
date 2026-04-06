import type { BashToolDetails, ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { createBashTool } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";

const COLLAPSED_LINES = 5;

function getTextContent(result: { content?: Array<{ type: string; text?: string }> }) {
  const first = result.content?.find((item) => item.type === "text");
  return first?.type === "text" ? first.text ?? "" : "";
}

function previewLines(text: string, count: number) {
  const lines = text.split("\n");
  const shown = lines.slice(0, count);
  const remaining = Math.max(0, lines.length - shown.length);
  return { shown, remaining, total: lines.length };
}

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    ...createBashTool(process.cwd()),
    name: "bash",

    renderCall(args, theme) {
      let text = theme.fg("toolTitle", theme.bold("$ "));
      text += theme.fg("accent", args.command || "...");
      if (args.timeout) text += theme.fg("muted", ` (timeout: ${args.timeout}s)`);
      return new Text(text, 0, 0);
    },

    renderResult(result, { expanded, isPartial }, theme) {
      if (isPartial) return new Text(theme.fg("warning", "Running..."), 0, 0);

      const details = result.details as BashToolDetails | undefined;
      const output = getTextContent(result);
      const trimmed = output.trimEnd();

      if (!trimmed) {
        return new Text(theme.fg("dim", "(no output)"), 0, 0);
      }

      const { shown, remaining, total } = previewLines(trimmed, expanded ? Number.MAX_SAFE_INTEGER : COLLAPSED_LINES);
      let text = shown.map((line) => theme.fg("toolOutput", line)).join("\n");

      if (!expanded && remaining > 0) {
        text += `\n${theme.fg("muted", `... ${remaining} more lines (Ctrl+o to expand)`)}`;
      }

      if (details?.truncation?.truncated) {
        const notice = `Output truncated by bash tool: ${details.truncation.outputLines}/${details.truncation.totalLines} lines shown`;
        text += `\n${theme.fg("warning", notice)}`;
        if (details.fullOutputPath) {
          text += `\n${theme.fg("muted", `Full output: ${details.fullOutputPath}`)}`;
        }
      } else if (expanded && total > COLLAPSED_LINES) {
        text += `\n${theme.fg("dim", `${total} lines`)}`;
      }

      return new Text(text, 0, 0);
    },
  });
}
