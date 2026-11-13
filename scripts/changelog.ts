import {parseArgs} from "node:util";
import {changelogHistorySchema, renderChangelogMarkdown} from "@codethread/cli-changelog";
import {type FormatConfig, format} from "oxfmt";
import config from "../.oxfmtrc.json";
import history from "../changelog.json";
import manifest from "../package.json";

export async function markdown(recordedHistory: unknown): Promise<string> {
	const rendered = renderChangelogMarkdown({
		title: manifest.name,
		history: changelogHistorySchema.parse(recordedHistory),
	});
	const {code, errors} = await format("CHANGELOG.md", rendered, config as FormatConfig);
	if (errors.length > 0) throw new AggregateError(errors, "Cannot format CHANGELOG.md.");
	return code;
}

if (import.meta.main) {
	const {values} = parseArgs({
		args: Bun.argv.slice(2),
		options: {write: {type: "boolean"}, check: {type: "boolean"}},
		strict: true,
		allowPositionals: false,
	});
	if (values.write && values.check) throw new Error("Select --write or --check, not both.");
	const output = await markdown(history);
	const destination = Bun.file(new URL("../CHANGELOG.md", import.meta.url));
	if (values.check) {
		if ((await destination.text()) !== output) {
			throw new Error("CHANGELOG.md is stale; run bun run changelog:generate.");
		}
	} else if (values.write) {
		await Bun.write(destination, output);
	} else {
		process.stdout.write(output);
	}
}
