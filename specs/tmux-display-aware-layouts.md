# Tmux display-aware layouts

Status: implemented, initial manual version

## Context

Kitty previously generated display-aware layout defaults at startup. After moving multiplexing to tmux, the same idea is handled by an explicit tmux rebalance command instead of automatic startup/display detection.

Implementation:

- `home/.local/bin/tmux-layout-aware`
- `config/tmux/tmux.conf`
  - `C-a =` forces tall / `main-vertical`
  - `C-a Enter` toggles tall ↔ fat with client-size-aware sizing

## Previous kitty heuristic

The useful behavior was small and self-contained:

```python
# BenQ RD280U (5120x3414 native, 2560x1707 logical)
if width == 2560 and height == 1707:
    return "tall:bias=65,fat:bias=55,stack"

# Retina displays (laptops) - always use smaller bias
if scale == 2:
    return "tall:bias=55,fat:bias=50,stack"

# Non-retina displays - use size-based heuristic
if width is None:
    return "tall:bias=65,fat:bias=55,stack"

if width <= 1920:
    return "tall:bias=65,fat:bias=55,stack"
elif width <= 2560:
    return "tall:bias=70,fat:bias=60,stack"
else:
    return "tall:bias=75,fat:bias=65,stack"
```

Display info came from macOS `system_profiler SPDisplaysDataType -json`; retina was detected by checking for `"Retina"` in the display item.

## Tmux approach

Tmux should use terminal grid size, not physical display APIs:

- works over SSH
- works in kitty, ghostty, Linux terminals, and nested sessions
- responds to actual terminal window size
- avoids macOS-only `system_profiler`

The initial implementation is manual. It does not run on resize/attach because automatic re-layout can fight intentional pane resizing.

## Current sizing table

Tall mode maps to `main-vertical` + `main-pane-width`:

| Client width | Main pane width |
| ---: | ---: |
| `<= 120` cols | `55%` |
| `<= 160` cols | `60%` |
| `<= 220` cols | `65%` |
| `<= 280` cols | `70%` |
| `> 280` cols | `75%` |

Fat mode maps to `main-horizontal` + `main-pane-height`:

| Client height | Main pane height |
| ---: | ---: |
| `<= 35` rows | `50%` |
| `<= 50` rows | `55%` |
| `> 50` rows | `60%` |

## Future tuning

Potential future changes if the manual trigger proves useful:

- Tune thresholds after real use on laptop/external displays.
- Add a third mode if tmux has a better replacement for kitty `stack` beyond pane zoom.
- Add an opt-in hook for resize/attach, but only if manual rebalance feels too repetitive.
