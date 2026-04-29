# :module: pi wrappers and helpers for tty usage


# Pi main agent
export def pim --wrapped [...rest] {
	pi --agent main ...$rest
}

# Low reasoning cheap
export def pii --wrapped [...rest] {
	pim --provider openai-codex --model gpt-5.4-mini --thinking low ...$rest
}

# High reasoning
export def pih --wrapped [...rest] {
	pim --provider openai-codex --model gpt-5.5 --thinking xhigh ...$rest
}

# Opus big boy
export def pio --wrapped [...rest] {
	pim --provider anthropic --model claude-opus-4.7 --thinking high ...$rest
}

# Run a slow but cheaper model
export def pis --wrapped [...rest] {
	pim --provider openai-codex --model gpt-5.4 --thinking high ...$rest
}
