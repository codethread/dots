import {createLake} from "@botlake/core";
import batteriesExtension from "@botlake/extension-batteries";
import {ui} from "@botlake/extension-ct-config";
import identityExtension from "@botlake/extension-identity";
import agents from "./src/agents.ts";
import flags from "./src/flags.ts";
import priming from "./src/priming.ts";
import references from "./src/references.ts";
import work from "./src/work.ts";
import workAgents from "./src/work-agents.ts";

export const lake = createLake({
	name: "dots",
	minimumCore: "0.3.2",
	extensions: [
		batteriesExtension,
		identityExtension,
		flags,
		references,
		agents,
		priming,
		ui,
		work,
		workAgents,
	],
});
