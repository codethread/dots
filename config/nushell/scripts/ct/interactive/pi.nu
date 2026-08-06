# :module: pi wrappers and helpers for tty usage

# Pi daily default
export alias pim = pi --agent main --provider openai-codex --model gpt-5.6-terra --thinking medium

# Cheap lightweight work
export alias pil = pi --agent main --provider openai-codex --model gpt-5.6-luna --thinking high

# Hard quality-first work
export alias pih = pi --agent main --provider openai-codex --model gpt-5.6-sol --thinking high

# Cheaper deep reasoning
export alias pit = pi --agent main --provider openai-codex --model gpt-5.6-terra --thinking high

# Fastest; separate Spark quota
export alias pif = pi --agent main --provider openai-codex --model gpt-5.3-codex-spark --thinking low

# Opus big OG
export alias pio = pi --agent main --provider anthropic --model claude-opus-4-6 --thinking high
# Opus big 4.8
export alias pioo = pi --agent main --provider anthropic --model claude-opus-4-8 --thinking medium
# Sonnet
export alias pis = pi --agent main --provider anthropic --model claude-sonnet-4-6 --thinking high
