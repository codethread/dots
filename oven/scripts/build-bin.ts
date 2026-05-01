#!/usr/bin/env bun

import {chmod, mkdir, readdir, stat} from "fs/promises";
import {homedir} from "os";
import {isAbsolute, join, normalize, sep} from "path";
import {parseArgs} from "util";
import {cleanBuilds} from "./clean";

interface BinEntry {
	bin: string;
	entry: string;
}

interface BinManifest {
	entries: BinEntry[];
}

const home = homedir();
const BIN_SRC_DIR = join(import.meta.dir, "..", "bin");
const MANIFEST_PATH = join(BIN_SRC_DIR, "manifest.json");
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
	const entries = await loadManifestEntries();

	if (verbose) {
		console.log(`Found ${entries.length} manifest entries to build\n`);
	}

	await mkdir(DEST_DIR, {recursive: true});

	const results = await Promise.all(entries.map((entry) => generateWrapper(entry)));
	const successes = results.filter((r) => r.success);
	const failures = results.filter((r) => !r.success);

	if (verbose && successes.length > 0) {
		console.log("Generated wrappers:");
		for (const {entry, destName} of successes) {
			console.log(`  ${entry} -> ${destName}`);
		}
	}

	if (failures.length > 0) {
		console.log(failures.length > 0 && !verbose ? "Failed:" : "\nFailed:");
		for (const {entry, error} of failures) {
			console.log(`  ${entry}: ${error}`);
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

async function loadManifestEntries(): Promise<BinEntry[]> {
	const manifest = await readManifest();
	assertManifestShape(manifest);
	const entries = manifest.entries.toSorted((a, b) => a.bin.localeCompare(b.bin));
	assertUnique(entries, "bin");
	assertUnique(entries, "entry");
	await assertEntriesStayInBin(entries);
	await assertDirectTsFilesAreManifested(entries);
	return entries;
}

async function readManifest(): Promise<unknown> {
	try {
		return await Bun.file(MANIFEST_PATH).json();
	} catch (error) {
		throw new Error(`Failed to read bin manifest at ${MANIFEST_PATH}: ${error}`);
	}
}

function assertManifestShape(manifest: unknown): asserts manifest is BinManifest {
	if (!isPlainObject(manifest)) {
		throw new Error("bin/manifest.json must be a JSON object");
	}
	assertKnownKeys(manifest, ["entries"], "manifest");
	if (!Array.isArray(manifest.entries)) {
		throw new Error("bin/manifest.json must contain an entries array");
	}
	manifest.entries.forEach((entry, index) => {
		if (!isPlainObject(entry)) {
			throw new Error(`manifest entry ${index} must be an object`);
		}
		assertKnownKeys(entry, ["bin", "entry"], `manifest entry ${index}`);
		if (typeof entry.bin !== "string" || entry.bin.length === 0) {
			throw new Error(`manifest entry ${index} must contain non-empty string bin`);
		}
		if (typeof entry.entry !== "string" || entry.entry.length === 0) {
			throw new Error(`manifest entry ${index} must contain non-empty string entry`);
		}
	});
}

function assertKnownKeys(object: Record<string, unknown>, allowed: string[], label: string) {
	const unknownKeys = Object.keys(object).filter((key) => !allowed.includes(key));
	if (unknownKeys.length > 0) {
		throw new Error(`${label} contains unknown keys: ${unknownKeys.join(", ")}`);
	}
}

function assertUnique(entries: BinEntry[], key: keyof BinEntry) {
	const seen = new Set<string>();
	for (const entry of entries) {
		const value = entry[key];
		if (seen.has(value)) {
			throw new Error(`Duplicate manifest ${key}: ${value}`);
		}
		seen.add(value);
	}
}

async function assertEntriesStayInBin(entries: BinEntry[]) {
	for (const entry of entries) {
		assertSafeRelativeEntry(entry.entry);
		const entryPath = join(BIN_SRC_DIR, entry.entry);
		const entryStat = await stat(entryPath).catch(() => null);
		if (entryStat === null) {
			throw new Error(`Manifest entry does not exist: ${entry.entry}`);
		}
		if (!entryStat.isFile()) {
			throw new Error(`Manifest entry is not a file: ${entry.entry}`);
		}
		if (!entry.entry.endsWith(".ts")) {
			throw new Error(`Manifest entry must end with .ts: ${entry.entry}`);
		}
	}
}

function assertSafeRelativeEntry(entry: string) {
	const normalized = normalize(entry);
	if (isAbsolute(entry) || normalized === ".." || normalized.startsWith(`..${sep}`)) {
		throw new Error(`Manifest entry must stay inside bin/: ${entry}`);
	}
}

async function assertDirectTsFilesAreManifested(entries: BinEntry[]) {
	const files = await readdir(BIN_SRC_DIR, {withFileTypes: true});
	const directTsFiles = files.filter((f) => f.isFile() && f.name.endsWith(".ts")).map((f) => f.name);
	const manifested = new Set(entries.map((entry) => normalize(entry.entry)));
	const unlisted = directTsFiles.filter((file) => !manifested.has(file));
	if (unlisted.length > 0) {
		throw new Error(`Direct bin/*.ts files missing from manifest: ${unlisted.join(", ")}`);
	}
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

async function generateWrapper(entry: BinEntry) {
	const srcPath = join(BIN_SRC_DIR, entry.entry);
	const destName = entry.bin;
	const destPath = join(DEST_DIR, destName);

	try {
		const wrapper = `#!/usr/bin/env bash\nexec bun run "${srcPath}" "$@"\n`;
		await Bun.write(destPath, wrapper);
		await chmod(destPath, 0o755);
		return {entry: entry.entry, destName, success: true};
	} catch (error) {
		return {entry: entry.entry, destName, success: false, error: `${error}`};
	}
}
