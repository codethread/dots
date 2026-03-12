#!/usr/bin/env bun

import {chmod, mkdir, readdir} from "fs/promises";
import {homedir} from "os";
import {basename, join} from "path";
import {parseArgs} from "util";
import {cleanBuilds} from "./clean";

const home = homedir();
const BIN_SRC_DIR = join(import.meta.dir, "..", "bin");
const DEST_DIR = join(home, ".local", "bin");

if (import.meta.main) {
	const {values} = parseArgs({
		args: Bun.argv.slice(2),
		options: {
			verbose: {type: "boolean", short: "v"},
		},
	});

	await buildExecutables(values.verbose);
}

// PRIVATES ------------------------------------------

async function buildExecutables(verbose = false) {
	const files = await readdir(BIN_SRC_DIR, {withFileTypes: true});
	const tsFiles = files.filter((f) => f.isFile() && f.name.endsWith(".ts")).map((f) => f.name);

	if (verbose) {
		console.log(`Found ${tsFiles.length} TypeScript files to build\n`);
	}

	await mkdir(DEST_DIR, {recursive: true});

	const results = await Promise.all(tsFiles.map((file) => generateWrapper(file)));
	const successes = results.filter((r) => r.success);
	const failures = results.filter((r) => !r.success);

	if (verbose && successes.length > 0) {
		console.log("Generated wrappers:");
		for (const {file, destName} of successes) {
			console.log(`  ${file} -> ${destName}`);
		}
	}

	if (failures.length > 0) {
		console.log(failures.length > 0 && !verbose ? "Failed:" : "\nFailed:");
		for (const {file, error} of failures) {
			console.log(`  ${file}: ${error}`);
		}
	}

	if (verbose || failures.length > 0) {
		console.log(
			`${failures.length > 0 && !verbose ? "" : "\n"}Summary: ${successes.length} succeeded, ${failures.length} failed`,
		);
	}

	await cleanBuilds(verbose);

	if (verbose) {
		console.log("\nBuild complete!");
	}

	if (failures.length > 0) process.exit(1);
}

async function generateWrapper(file: string) {
	const srcPath = join(BIN_SRC_DIR, file);
	const destName = basename(file, ".ts");
	const destPath = join(DEST_DIR, destName);

	try {
		const wrapper = `#!/usr/bin/env bash\nexec bun run "${srcPath}" "$@"\n`;
		await Bun.write(destPath, wrapper);
		await chmod(destPath, 0o755);
		return {file, destName, success: true};
	} catch (error) {
		return {file, destName, success: false, error: `${error}`};
	}
}
