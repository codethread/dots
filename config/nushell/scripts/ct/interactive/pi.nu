# :module: pi wrappers and helpers for tty usage

# Pi main agent
export alias pim = pi --agent main --provider openai-codex --model gpt-5.5 --thinking low

# Low reasoning cheap
export alias pil = pi --agent main --provider openai-codex --model gpt-5.4-mini --thinking low

# High reasoning
export alias pih = pi --agent main --provider openai-codex --model gpt-5.5 --thinking high

# Run a slow but cheaper model
export alias pis = pi --agent main --provider openai-codex --model gpt-5.4 --thinking high

# Run a fast but cheaper model
export alias pif = pi --agent main --provider openai-codex --model gpt-5.3-codex-spark --thinking low

# Opus big OG
export alias pio = pi --agent main --provider anthropic --model claude-opus-4-6 --thinking high
# Opus big 4.8
export alias pioo = pi --agent main --provider anthropic --model claude-opus-4-8 --thinking medium
# Sonnet
export alias pis = pi --agent main --provider anthropic --model claude-sonnet-4-6 --thinking high
