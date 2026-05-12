// :module: Shared type definitions for Claude Code hook inputs and outputs

/**
 * Base interface for all Claude Code hook inputs
 */
export interface BaseHookInput {
	session_id: string;
	transcript_path: string;
	cwd: string;
	hook_event_name: string;
}

export interface StatuslineInput extends BaseHookInput {
	hook_event_name: "Status";
	model: {
		id: string;
		display_name: string;
	};
	workspace: {
		current_dir: string;
		project_dir: string;
	};
	version: string;
	output_style: {
		name: string;
	};
	cost: {
		total_cost_usd: number;
		total_duration_ms: number;
		total_api_duration_ms: number;
		total_lines_added: number;
		total_lines_removed: number;
	};
	context_window?: {
		total_input_tokens: number;
		total_output_tokens: number;
		context_window_size: number;
		used_percentage: number;
		remaining_percentage: number;
		current_usage: {
			input_tokens: number;
			output_tokens: number;
			cache_creation_input_tokens: number;
			cache_read_input_tokens: number;
		} | null;
	};
	exceeds_200k_tokens?: boolean;
	rate_limits?: {
		five_hour?: {
			used_percentage: number;
			resets_at: number;
		};
		seven_day?: {
			used_percentage: number;
			resets_at: number;
		};
	};
	vim?: {
		mode: string;
	};
	agent?: {
		name: string;
	};
	worktree?: {
		name: string;
		path: string;
		branch: string;
		original_cwd: string;
		original_branch: string;
	};
	effort?: {
		level: "low" | "medium" | "high" | "xhigh" | "max";
	};
}

/**
 * Hook input for PreToolUse events - fired before a tool is executed
 */
export interface PreToolUseInput extends BaseHookInput {
	hook_event_name: "PreToolUse";
	tool_name: string;
	tool_input: Record<string, unknown>; // Schema depends on the specific tool
}

/**
 * Hook input for PostToolUse events - fired after a tool completes successfully
 */
export interface PostToolUseInput extends BaseHookInput {
	hook_event_name: "PostToolUse";
	tool_name: string;
	tool_input: Record<string, unknown>; // Schema depends on the specific tool
	tool_response: Record<string, unknown>; // Schema depends on the specific tool
}

/**
 * Hook input for Notification events - fired when Claude Code sends notifications
 */
export interface NotificationInput extends BaseHookInput {
	hook_event_name: "Notification";
	message: string;
}

/**
 * Hook input for UserPromptSubmit events - fired when user submits a prompt
 */
export interface UserPromptSubmitInput extends BaseHookInput {
	hook_event_name: "UserPromptSubmit";
	prompt: string;
}

/**
 * Hook input for Stop/SubagentStop events - fired when Claude finishes responding
 */
export interface StopInput extends BaseHookInput {
	hook_event_name: "Stop" | "SubagentStop";
	stop_hook_active: boolean; // True when Claude is already continuing from a stop hook
}

/**
 * Hook input for PreCompact events - fired before compacting conversation
 */
export interface PreCompactInput extends BaseHookInput {
	hook_event_name: "PreCompact";
	trigger: "manual" | "auto";
	custom_instructions: string; // Empty for auto, user-provided for manual
}

/**
 * Hook input for SessionStart events - fired when a session begins
 */
export interface SessionStartInput extends BaseHookInput {
	hook_event_name: "SessionStart";
	source: "startup" | "resume" | "clear" | "compact";
}

/**
 * Hook input for SessionEnd events - fired when a session ends
 */
export interface SessionEndInput extends BaseHookInput {
	hook_event_name: "SessionEnd";
	reason: "clear" | "logout" | "prompt_input_exit" | "other";
}

/**
 * Union type for all possible hook inputs
 */
export type HookInput =
	| StatuslineInput
	| PreToolUseInput
	| PostToolUseInput
	| NotificationInput
	| UserPromptSubmitInput
	| StopInput
	| PreCompactInput
	| SessionStartInput
	| SessionEndInput;

// Hook Output Types (JSON stdout)

/**
 * Base interface for all Claude Code hook outputs
 */
export interface BaseHookOutput {
	continue?: boolean; // Whether Claude should continue (default: true)
	stopReason?: string; // Message shown when continue is false
	suppressOutput?: boolean; // Hide stdout from transcript mode (default: false)
	systemMessage?: string; // Optional warning shown to user
}

/**
 * Hook output for PreToolUse events - can control tool permission
 */
export interface PreToolUseOutput extends BaseHookOutput {
	decision?: "approve" | "block"; // Deprecated, use hookSpecificOutput
	reason?: string; // Deprecated
	hookSpecificOutput?: {
		hookEventName: "PreToolUse";
		permissionDecision: "allow" | "deny" | "ask";
		permissionDecisionReason: string;
	};
}

/**
 * Hook output for PostToolUse events - can provide feedback to Claude
 */
export interface PostToolUseOutput extends BaseHookOutput {
	decision?: "block"; // Automatically prompts Claude with reason
	reason?: string; // Explanation for decision
	hookSpecificOutput?: {
		hookEventName: "PostToolUse";
		additionalContext: string; // Additional info for Claude
	};
}

/**
 * Hook output for UserPromptSubmit events - can block or add context
 */
export interface UserPromptSubmitOutput extends BaseHookOutput {
	decision?: "block"; // Prevents prompt processing
	reason?: string; // Shown to user, not added to context
	hookSpecificOutput?: {
		hookEventName: "UserPromptSubmit";
		additionalContext: string; // Added to context if not blocked
	};
}

/**
 * Hook output for Stop/SubagentStop events - can prevent stopping
 */
export interface StopOutput extends BaseHookOutput {
	decision?: "block"; // Prevents Claude from stopping
	reason?: string; // Must be provided when blocking
}

/**
 * Hook output for SessionStart events - can add initial context
 */
export interface SessionStartOutput extends BaseHookOutput {
	hookSpecificOutput?: {
		hookEventName: "SessionStart";
		additionalContext: string; // Added to context
	};
}

/**
 * Union type for all possible hook outputs
 */
export type HookOutput =
	| PreToolUseOutput
	| PostToolUseOutput
	| UserPromptSubmitOutput
	| StopOutput
	| SessionStartOutput
	| BaseHookOutput; // For events without specific output requirements

/**
 * Type guard to check if hook input is a specific type
 */
export function isHookInputOfType<T extends HookInput>(
	input: HookInput,
	eventName: T["hook_event_name"],
): input is T {
	return input.hook_event_name === eventName;
}

/**
 * Type guard specifically for PostToolUse with Read tool
 */
export function isPostToolUseRead(input: HookInput): input is PostToolUseInput & {tool_name: "Read"} {
	return input.hook_event_name === "PostToolUse" && "tool_name" in input && input.tool_name === "Read";
}

/**
 * Type guard for SessionStart events
 */
export function isSessionStart(input: HookInput): input is SessionStartInput {
	return input.hook_event_name === "SessionStart";
}

/**
 * Type guard for SessionEnd events
 */
export function isSessionEnd(input: HookInput): input is SessionEndInput {
	return input.hook_event_name === "SessionEnd";
}
