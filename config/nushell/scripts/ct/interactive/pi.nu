# :module: pi wrappers and helpers for tty usage

const core_tools = [
    read
    bash
    edit
    write
    interactive_shell
    pi-internals
    harness_metadata
]

const subagent = [subagent]
const goal_tools = [goal_complete, goal_blocked, goal_wait]

# Pi daily default
export alias pim = pi --tools ($core_tools ++ $subagent ++ $goal_tools | str join ",") --provider openai-codex --model gpt-5.6-sol --thinking medium

# Hard quality-first work
export alias pih = pi --tools ($core_tools ++ $subagent ++ $goal_tools | str join ",") --provider openai-codex --model gpt-6-astra --thinking high

# Cheap lightweight work
export alias pil = pi --tools ($core_tools ++ $subagent | str join ",") --provider openai-codex --model gpt-5.6-terra --thinking high

# Fastest; response
export alias pif = pi --tools ($core_tools | str join ",") --model deepseek/deepseek-flash --thinking max

# Opus big OG
export alias pio = pi --tools ($core_tools ++ $subagent ++ $goal_tools | str join ",") --provider anthropic --model claude-opus-4-6 --thinking high

export def pi-install [] {
    with-env { PI_OFFLINE: null } { pi update --extensions }
}
