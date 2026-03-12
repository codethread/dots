#!/usr/bin/env python3
"""
Dynamic Kitty configuration generator.

This script is called via geninclude directive in kitty.conf to dynamically
generate configuration based on runtime environment and display properties.

Current features:
- Layout bias adjustment based on display scale and size
  - Retina displays (scale=2): Use 55/50 bias (smaller splits for laptop screens)
  - Non-retina displays: Use size-based heuristic for appropriate bias

Can be extended to handle other dynamic configuration needs such as:
- Theme selection based on time of day
- Font size adjustments per display
- Terminal dimensions based on screen resolution
"""

import subprocess
import sys
import json
from typing import Tuple, Optional


# Public API

def generate_config() -> str:
    """
    Generate kitty configuration dynamically.

    Returns:
        Configuration string to be included in kitty.conf
    """
    width, height, scale = _get_display_info()
    layout = _get_layout_config(width, height, scale)

    config_lines = []
    config_lines.append(f"# Auto-generated config (Display: {width}x{height} @{scale}x)")
    config_lines.append(f"enabled_layouts {layout}")

    return "\n".join(config_lines)


# Private implementation

def _get_display_info() -> Tuple[Optional[int], Optional[int], int]:
    """
    Get current display dimensions and scale factor.

    Returns:
        Tuple of (width_px, height_px, scale_factor)
    """
    try:
        result = subprocess.run(
            ["system_profiler", "SPDisplaysDataType", "-json"],
            capture_output=True,
            text=True,
            check=True
        )

        data = json.loads(result.stdout)
        displays = data.get("SPDisplaysDataType", [])

        if not displays:
            return None, None, 1

        main_display = displays[0]
        items = main_display.get("spdisplays_ndrvs", [])
        if not items:
            return None, None, 1

        display_item = items[0]

        # Parse resolution string (e.g., "2560 x 1600" or "2560 x 1600 @ 60 Hz")
        resolution = display_item.get("_spdisplays_resolution", "")
        if resolution:
            parts = resolution.split("x")
            if len(parts) >= 2:
                width = int(parts[0].strip())
                height = int(parts[1].split("@")[0].strip())

                # Detect retina/scale factor
                scale = 2 if "Retina" in str(display_item) else 1

                return width, height, scale

        return None, None, 1

    except (subprocess.CalledProcessError, FileNotFoundError, json.JSONDecodeError, KeyError, ValueError):
        return None, None, 1


def _get_layout_config(width: Optional[int], height: Optional[int], scale: int) -> str:
    """
    Determine layout configuration based on display properties.

    Args:
        width: Display width in logical pixels
        height: Display height in logical pixels
        scale: Display scale factor (1 for normal, 2 for retina)

    Returns:
        Configuration string for enabled_layouts
    """
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


if __name__ == "__main__":
    try:
        print(generate_config())
    except Exception as e:
        # On error, output a safe default config
        print(f"# Error in geninclude_config.py: {e}", file=sys.stderr)
        print("enabled_layouts tall:bias=65,fat:bias=55,stack")
