// beeswax:begin onboarding v2
export default function (pi) {
	pi.on("before_agent_start", async (event) => {
		const result = await pi.exec("beeswax", ["prime"]);
		if (result.code !== 0) throw new Error(`beeswax prime failed: ${result.stderr}`);
		event.systemPromptOptions.sections.beeswax = result.stdout.trimEnd();
	});
	pi.on("context", async (event, ctx) => {
		const payload = JSON.stringify({ session_id: ctx.sessionManager.getSessionId(), cwd: ctx.cwd, hook_event_name: "context" });
		let context;
		try {
			const result = await pi.exec("beeswax", ["harness-alert", "--harness", "pi", "--input", payload], { timeout: 5000 });
			if (result.code !== 0) throw new Error(result.stderr);
			const output = JSON.parse(result.stdout);
			if (typeof output.context !== "string") throw new Error("Invalid alert callback output");
			context = output.context;
		} catch (error) {
			context = "Beeswax tracker alert check failed. Stop Beads workflows and ordinary tracker operations on the selected endpoint; do not merge. Unrelated non-Beads work and explicitly user-authorized native tracker inspection/recovery may continue. Recheck independent alert status. With no known hold, a healthy check of this endpoint with no active incident restores baseline; do not announce clearance. Clearance is unverified for any known hold, including a handoff or sync failure. A failed check or missing receipt cannot release it. Announce verified matching or newer clearance before resuming that work. Diagnostics: " + String(error);
		}
		const messages = event.messages.filter((message) => message.customType !== "beeswax-tracker-alert");
		if (context) messages.push({ role: "custom", customType: "beeswax-tracker-alert", content: context, display: true, timestamp: Date.now() });
		return { messages };
	});
}
// beeswax:end onboarding
