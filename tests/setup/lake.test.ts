import {expect, test} from "bun:test";
import {lake} from "../../.botlake/lake.ts";
import agents from "../../.botlake/src/agents.ts";
import work from "../../.botlake/src/work.ts";

test("lake selects Mail delivery with the shared Agents binding", () => {
	const extensions = new Map(lake.extensions.map((extension) => [extension.name, extension]));
	const mail = extensions.get("mail");
	const mailAgents = extensions.get("mail-agents");
	if (!mail || !mailAgents) throw new Error("Mail extensions are not selected");

	expect(extensions.get("agents")).toBe(agents);
	expect(extensions.has("mail-identity")).toBe(true);
	expect(mailAgents.requires).toEqual([mail.name, agents.name]);
});

test("lake selects exact Work and Agents runtime bindings without duplicate extensions", () => {
	const extensions = new Map(lake.extensions.map((extension) => [extension.name, extension]));

	expect(extensions.size).toBe(lake.extensions.length);
	expect(extensions.get("work")).toBe(work);
	expect(extensions.get("agents")).toBe(agents);
	expect(typeof work.instance).toBe("function");
	expect(typeof agents.instance).toBe("function");
	expect(lake.extensions.filter((extension) => extension.name === "ui")).toHaveLength(1);
	expect(extensions.get("work-agents")?.requires).toEqual([work.name, agents.name, "identity"]);
});
