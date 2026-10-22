// beeswax:begin identity v1
export default async function scent(pi) {
	const SUCCESS = 0;
	const result = await pi.exec("scent", ["system", "pi-extension", "--json"]);
	if (result.code !== SUCCESS) {
		throw new Error(result.stdout || result.stderr);
	}
	const output = JSON.parse(result.stdout);
	if (output.ok !== true || output.kind !== "pi_extension" || typeof output.source !== "string") {
		throw new Error("Invalid Scent Pi extension output");
	}
	const moduleUrl = `data:text/javascript;base64,${Buffer.from(output.source).toString("base64")}`;
	const runtime = await import(moduleUrl);
	runtime.default(pi);
}
// beeswax:end identity
