// beeswax:begin onboarding v1
export default function (pi) {
	pi.on("before_agent_start", async (event) => {
		const result = await pi.exec("beeswax", ["prime"]);
		if (result.code !== 0) throw new Error(`beeswax prime failed: ${result.stderr}`);
		event.systemPromptOptions.sections.beeswax = result.stdout.trimEnd();
	});
}
// beeswax:end onboarding
