#!/usr/bin/env bun

import {chmod, mkdir, readdir} from "fs/promises";
import {homedir} from "os";
import {basename, join} from "path";
import {parseArgs} from "util";
import {cleanBuilds} from "./clean";

type CompileTarget = Bun.Build.Target;

const home = homedir();
const BIN_SRC_DIR = join(import.meta.dir, "..", "bin");
const LOCAL_DEST_DIR = join(home, ".local", "bin");
const LINUX_DEST_DIR = join(home, ".local", "state", "oven");

interface BuildTarget {
	label: string;
	target: CompileTarget;
	destDir: string;
}

function getLocalTarget(): CompileTarget {
	if (process.platform === "darwin") {
		return process.arch === "arm64" ? "bun-darwin-arm64" : "bun-darwin-x64";
	}
	return process.arch === "arm64" ? "bun-linux-arm64" : "bun-linux-x64";
}

function getLinuxTarget(): CompileTarget {
	return process.arch === "arm64" ? "bun-linux-arm64" : "bun-linux-x64";
}

async function buildForTarget(tsFiles: string[], buildTarget: BuildTarget, verbose: boolean) {
	const {label, target, destDir} = buildTarget;

	if (verbose) {
		console.log(`Building ${label}...`);
	}

	await mkdir(destDir, {recursive: true});

	const buildPromises = tsFiles.map(async (file) => {
		const srcPath = join(BIN_SRC_DIR, file);
		const destName = basename(file, ".ts");
		const destPath = join(destDir, destName);

		try {
			const result = await Bun.build({
				entrypoints: [srcPath],
				compile: {
					target,
					outfile: destPath,
				},
				minify: true,
				bytecode: true,
				sourcemap: "inline",
			});

			if (!result.success) {
				const errors = result.logs.map((msg) => `  ${msg}`).join("\n");
				return {file, destName, success: false, error: `Build failed:\n${errors}`};
			}

			await chmod(destPath, 0o755);
			return {file, destName, success: true};
		} catch (error) {
			return {file, destName, success: false, error: `Exception: ${error}`};
		}
	});

	const results = await Promise.all(buildPromises);
	const successes = results.filter((r) => r.success);
	const failures = results.filter((r) => !r.success);

	if (verbose && successes.length > 0) {
		console.log("Successfully built:");
		for (const {file, destName} of successes) {
			console.log(`  ${file} -> ${destName}`);
		}
	}

	if (failures.length > 0) {
		console.log(failures.length > 0 && !verbose ? "Failed to build:" : "\nFailed to build:");
		for (const {file, destName, error} of failures) {
			console.log(`  ${file} -> ${destName}`);
			console.error(`    ${error}`);
		}
	}

	if (verbose || failures.length > 0) {
		console.log(
			`${failures.length > 0 && !verbose ? "" : "\n"}Summary: ${successes.length} succeeded, ${failures.length} failed`,
		);
	}

	return failures.length;
}

async function buildExecutables(verbose = false) {
	const files = await readdir(BIN_SRC_DIR, {withFileTypes: true});
	const tsFiles = files.filter((f) => f.isFile() && f.name.endsWith(".ts")).map((f) => f.name);

	if (verbose) {
		console.log(`Found ${tsFiles.length} TypeScript files to build\n`);
	}

	const targets: BuildTarget[] = [
		{label: "executables to ~/.local/bin", target: getLocalTarget(), destDir: LOCAL_DEST_DIR},
		{
			label: `linux (${getLinuxTarget()}) executables to ~/.local/state/oven`,
			target: getLinuxTarget(),
			destDir: LINUX_DEST_DIR,
		},
	];

	let totalFailures = 0;
	for (const buildTarget of targets) {
		totalFailures += await buildForTarget(tsFiles, buildTarget, verbose);
		if (verbose) {
			console.log("");
		}
	}

	await cleanBuilds(verbose);

	if (verbose) {
		console.log("\nBuild complete!");
	}

	if (totalFailures > 0) {
		process.exit(1);
	}
}

if (import.meta.main) {
	const {values} = parseArgs({
		args: Bun.argv.slice(2),
		options: {
			verbose: {type: "boolean", short: "v"},
		},
	});

	await buildExecutables(values.verbose);
}
