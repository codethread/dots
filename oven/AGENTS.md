# Oven Docs

## Build System

The build process generates thin bash wrapper scripts that `exec bun run <source>`:

- Outputs to `~/.local/bin` for system-wide PATH availability
- during development run code with `bun run ./bin/<file name>`

### Commands

```bash
cd oven
bun run fmt      # Format code
bun run lint     # Lint code
bun run check    # Check formatting and linting
bun run fix      # Fix issues (quiet by default)
bun run build    # Build executables to ~/.local/bin (quiet by default, use -v for verbose)
bun run sync-docs   # Update documentation (quiet by default, use -v for verbose)
bun run ./bin/<filename>  # Test before building
```

## Package structure

- **Shared modules**: Use `oven/shared/*.ts` for reusable types and utilities
- **Claude Code hooks**: Import types from `oven/shared/claude-hooks.ts` for hook development
- **Quiet by default**: Build scripts support `--verbose` flag for detailed output

### Naming Convention for bin files

**Short Format:**

- `<name>`: concise, potentially ambiguous
- Use case: extremely common commands (as dictated by user request)
- Examples:
  - `oven/bin/bra.ts` -> `bra`
  - `oven/bin/ghub.ts` -> `ghub`

**Long Format:**

- `<domain>-<contex>--<action>`: clear and scoped,
- Use case: most scripts
- Examples:
  - `oven/bin/cc-hook--context-injector.ts` -> `cc-hook--context-injector`
  - `oven/bin/cc-logs--analyze-subagents.ts` -> `cc-logs--analyze-subagents`

existing domains:

- `cc`: claude code
- `git`: git, gitlab or github
- `aud`: audio related commands
- `txt`: text manipulation tools

## Code Standards

### Formatting, Linting & Type checking

- **Formatter**: (`bun fmt`) Biome with 100-character line width, no bracket spacing
- **Linter**: (`bun check`) Biome with recommended rules, allows `any` types and non-null assertions
- **Types**: (`bun run typecheck`) Typescript via `tsc`, relatively strict
- IMPORTANT: when work is complete run `bun run verify` to validate all checks, build the binaries and update the docs

### Best Practices

1. **Script structure**
   - follows 'clean code' style of high level functions first, going down to low level
   - this is an organizational pattern for readability
   - help > CoreInterface > const definitions > main > lib > functions > execute main
   - main function should focus on cli parsing, lib invocation, reporting and error reporting. All 'logic' belongs in the 'lib' function
   - **IMPORTANT**: Never put executable code at the module level (outside of functions). This includes parseArgs calls - they should be inside main(), not at the top level

2. **Help documentation format**
   - **CRITICAL**: The first line of help output MUST be `toolname - description`
   - This format is required for the `sync-docs` script to extract tool descriptions
   - Example: `cc-speak - Advanced text-to-speech tool with file and section reading support`
   - The description appears in README.md automatically when you run `bun run sync-docs`
   - Without this format, your tool won't be documented properly

3. **Use Bun native APIs**
   - Use `import {$} from "bun"` for shell commands instead of Node's child_process
   - Use Bun's built-in APIs wherever possible
   - Proactively use @bun-runtime-expert agent to check for alternatives to Node APIs

4. **Argument parsing**
   - Use `import {parseArgs} from "util"` for CLI argument parsing
   - Define clear option types and provide help documentation
   - Use `strict: false` when no positional arguments are used
   - Example: `parseArgs({args: Bun.argv.slice(2), options: {...}, strict: false})`

5. **Output**
   - All cli functions (unless using interactive tty utils) should capture information and then pass this to a final `report` function which is common across `bin` modules
   - `report` can then write to stdout in typical scenarios, but be extended to support other outputs if appropriate.
   - this allows for consistent testing and a more functional style of avoiding IO

6. **Error handling patterns**
   - Use specific error types when possible: `throw new Error("Descriptive message")`
   - For async operations, always catch and re-throw with context
   - Use `reportError()` to ensure consistent error formatting
   - Example patterns:

   ```typescript
   try {
     const result = await riskyOperation();
     return result;
   } catch (error) {
     throw new Error(`Failed to complete operation: ${error.message}`);
   }
   ```

7. **Testability and Module Safety**
   - Export core logic as function separate from CLI wrapper
   - **CRITICAL**: Always use `if (import.meta.main)` to conditionally run CLI code
   - **Never call main() at the top level without this guard** - it will execute when imported and can cause the importing script to hang
   - This allows function to be imported and tested independently
   - Example of the issue: If main() reads from stdin or starts async operations, importing the file will trigger these operations

   ```typescript
   // ❌ BAD: Will run when imported, causing hangs
   main().catch(console.error);

   // ✅ GOOD: Only runs when executed directly
   if (import.meta.main) {
     main().catch(console.error);
   }
   ```

### Testing Best Practices

- Tests live in `oven/tests/` with matching names (e.g., `ghub.ts` → `ghub.test.ts`)
- Use Bun's built-in test runner: `import {describe, test, expect} from "bun:test"`
- Favour fake implementations, e.g create temporary directories and use real IO calls wherever possible
- Make use of bun snapshot tests to verify outputs
- Test the exported lib function directly, not the CLI wrapper

#### CRITICAL Testing Anti-patterns to Avoid

- **Never use conditional assertions** - Don't write `if ("prop" in obj) expect(obj.prop)...`
- **Always assert the contract** - Use `expect(obj).toHaveProperty('prop')` before accessing
- **Never hard-code system paths** - Use `process.execPath` for Bun, `import.meta.dir` for paths
- **Avoid "testing the mocks"** - Tests should verify behavior, not mock implementations

#### Portable Path Patterns

```typescript
// ❌ BAD: Hard-coded paths
const binPath = "/opt/homebrew/bin/bun";
const projectPath = "/Users/username/project/bin/tool.ts";

// ✅ GOOD: Portable paths
const binPath = process.execPath;
const projectPath = resolve(dirname(import.meta.dir), "bin", "tool.ts");
```

#### Proper Assertion Patterns

```typescript
// ❌ BAD: Conditional assertions that can silently pass
if ("message" in result) {
  expect(result.message).toContain("expected");
}

// ✅ GOOD: Explicit contract assertions
expect(result).toHaveProperty("message");
expect(result.message).toContain("expected");
```

#### Parametrized Testing

Use `test.each` for testing multiple scenarios efficiently:

```typescript
test.each([
  { input: "npm install", expected: "bun install" },
  { input: "npm run dev", expected: "bun run dev" },
  { input: "npx create-app", expected: "bunx create-app" },
])("should redirect $input to $expected", ({ input, expected }) => {
  const result = redirectCommand(input);
  expect(result).toBe(expected);
});
```

#### Dependency Injection for Testing Shell Commands

Since Bun's `$` operator cannot be directly mocked, use dependency injection for testable shell command execution:

```typescript
// Define an interface for shell commands
export interface ShellExecutor {
  runCommand: (cmd: string) => Promise<string>;
  // Add other shell operations as needed
}

// Default implementation using Bun's $ operator
export const defaultShellExecutor: ShellExecutor = {
  async runCommand(cmd: string): Promise<string> {
    return await $`${cmd}`.text();
  },
};

// In your function, accept the executor as a parameter
export async function myToolLib(options: MyOptions & { executor?: ShellExecutor }) {
  const executor = options.executor ?? defaultShellExecutor;
  const result = await executor.runCommand("some-command");
  // ... rest of implementation
}

// In tests, provide a mock executor
test("should handle command execution", async () => {
  const mockExecutor: ShellExecutor = {
    async runCommand(cmd: string): Promise<string> {
      expect(cmd).toBe("expected-command");
      return "mocked output";
    },
  };

  const result = await myToolLib({
    someOption: "value",
    executor: mockExecutor,
  });

  expect(result.success).toBe(true);
});
```

#### Example test structure

```typescript
import { describe, test, expect } from "bun:test";
import { resolve, dirname } from "path";
import { myToolLib } from "../bin/my-tool";

describe("myToolLib", () => {
  test("should handle valid input", async () => {
    const result = await myToolLib({ option: "value" });
    expect(result.success).toBe(true);
    // Assert expected properties exist before using them
    expect(result).toHaveProperty("data");
    expect(result.data).toBeDefined();
  });

  test("should throw on invalid input", async () => {
    expect(() => myToolLib({ invalid: true })).toThrow("Expected error message");
  });
});
```

### Example pseudo script

```typescript
// :module: Description of what this tool does

import { $ } from "bun";
import { parseArgs } from "util";
import { report, reportError } from "../shared/report";

// always first for easy discoverability
function showHelp() {
  // IMPORTANT: First line MUST be "toolname - description" for sync-docs script
  console.log(`my-tool - Brief description of what this tool does

Usage: my-tool [options]

Options:
  --input, -i    Input file path (required)
  --output, -o   Output file path (optional)
  --verbose, -v  Enable verbose logging
  --help, -h     Show this help message

Examples:
  my-tool -i input.txt -o output.txt
  my-tool --input data.json --verbose
`);
  process.exit(0);
}

// interface to core logic if needed
export interface CoreLogicOptions {
  input: string;
  output?: string;
  verbose?: boolean;
}

// constants if needed
const OUTPUT_FILE = "some constant";

// CLI wrapper next
async function main() {
  const { values } = parseArgs({
    args: Bun.argv.slice(2),
    options: {
      input: { type: "string", short: "i" },
      output: { type: "string", short: "o" },
      verbose: { type: "boolean", short: "v" },
      help: { type: "boolean", short: "h" },
    },
    strict: false, // Prevent errors from unexpected positionals in compiled executables
  });

  if (values.help) {
    showHelp();
  }

  if (!values.input) {
    console.error("Error: --input is required");
    showHelp();
  }

  // Handle CLI logic
  try {
    const result = await doBinLib({
      input: values.input!,
      output: values.output,
      verbose: values.verbose,
    });
    report(result);
  } catch (err) {
    reportError(err);
    process.exit(1);
  }
}

// Exported lib functionality matching format `<bin name camelCased>Lib`
export async function doBinLib(options: CoreLogicOptions) {
  if (options.verbose) {
    console.log(`Processing input: ${options.input}`);
  }

  const data = await readInputFile(options.input);
  const processed = processData(data);

  if (options.output) {
    await writeOutputFile(options.output, processed);
    return { success: true, outputPath: options.output };
  }

  return { success: true, data: processed };
}

// implementation functions defined **after** call site
async function readInputFile(path: string): Promise<string> {
  try {
    return await Bun.file(path).text();
  } catch (error) {
    throw new Error(`Failed to read input file: ${error.message}`);
  }
}

function processData(data: string): string {
  // Process the data according to tool logic
  return data.trim().toUpperCase();
}

async function writeOutputFile(path: string, data: string): Promise<void> {
  try {
    await Bun.write(path, data);
  } catch (error) {
    throw new Error(`Failed to write output file: ${error.message}`);
  }
}

// Only run if executed directly
if (import.meta.main) {
  main();
}
```
