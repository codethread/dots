import {expect, test} from "bun:test";
import {lake} from "../../.botlake/lake.ts";
import agents from "../../.botlake/src/agents.ts";

test("lake selects Mail delivery with the shared Agents binding", () => {
	const extensions = new Map(lake.extensions.map((extension) => [extension.name, extension]));
	const mail = extensions.get("mail");
	const mailAgents = extensions.get("mail-agents");
	if (!mail || !mailAgents) throw new Error("Mail extensions are not selected");

	expect(extensions.get("agents")).toBe(agents);
	expect(extensions.has("mail-identity")).toBe(true);
	expect(mailAgents.requires).toEqual([mail.name, agents.name]);
});
