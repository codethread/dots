import { createReadTool, type ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Container, Text } from "@mariozechner/pi-tui";

/**
 * Compact read renderer.
 * Keeps built-in read execution, but shows only file path in tool output.
 */
function mapReadError(message: string): string {
  if (message.includes("ENOENT")) return "No such path";
  return message;
}

export default function (pi: ExtensionAPI) {
  const builtinRead = createReadTool(process.cwd());

  pi.registerTool({
    ...builtinRead,
    name: "read",

    renderCall(args, theme) {
      const path = (args.path as string | undefined) ?? "(unknown)";
      return new Text(theme.fg("toolTitle", theme.bold("read ")) + theme.fg("muted", path), 0, 0);
    },

    renderResult(result, _options, theme, context) {
      if (!context.isError) {
        return new Container();
      }

      const first = result.content?.[0];
      const rawMessage = first?.type === "text" ? first.text : "read failed";
      const message = mapReadError(rawMessage);
      return new Text(theme.fg("error", message), 0, 0);
    },
  });
}
