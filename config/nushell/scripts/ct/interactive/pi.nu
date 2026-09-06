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

const smart_tools = [subagent]
const goal_tools = [goal_complete, goal_blocked, goal_wait]

# Pi daily default
export alias pim = pi --tools ($core_tools ++ $smart_tools ++ $goal_tools | str join ",") --provider openai-codex --model gpt-5.6-sol --thinking medium

# Hard quality-first work
export alias pih = pi --tools ($core_tools ++ $smart_tools ++ $goal_tools | str join ",") --provider openai-codex --model gpt-5.6-sol --thinking xhigh

# Cheap lightweight work
export alias pil = pi --tools ($core_tools | str join ",") --provider openai-codex --model gpt-5.6-luna --thinking high

# Fastest; response
export alias pif = pi --tools ($core_tools | str join ",") --provider openai-codex --model gpt-5.6-luna --thinking low

# Opus big OG
export alias pio = pi --tools ($core_tools ++ $smart_tools ++ $goal_tools | str join ",") --provider anthropic --model claude-opus-4-6 --thinking high

export def pi-install [] {
    with-env { PI_OFFLINE: null } { pi update --extensions }
}
