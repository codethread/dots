// Gentle background snow. Each layer evaluates only one cell per pixel:
// flake centers are inset far enough to contain their radius, sway and AA edge.

float randomValue(vec2 value) {
  value = fract(value * vec2(123.34, 456.21));
  value += dot(value, value + 45.32);
  return fract(value.x * value.y);
}

float snowLayer(vec2 position, float scale, float speed, float layer) {
  vec2 grid = (position - vec2(0.0, iTime * speed)) * scale;
  vec2 cell = floor(grid);

  // Most cells are empty. Skip their offsets, sway and circle evaluation.
  if (randomValue(cell + layer * 91.3) < 0.82) return 0.0;

  vec2 seed = cell + layer * 31.7;
  vec2 offset = vec2(
    randomValue(seed),
    randomValue(seed + vec2(19.19, 73.73))
  );
  float radius = mix(0.035, 0.075, offset.x) + layer * 0.008;
  // Analytic pixel width avoids derivatives inside divergent branches. Cap
  // the fringe for tiny windows so a flake still fits entirely in its cell.
  float edge = clamp(scale / iResolution.y, 0.01, 0.25);
  float outerRadius = radius + edge;
  float swayAmount = 0.08 + layer * 0.015;
  vec2 margin = vec2(outerRadius + swayAmount, outerRadius);
  vec2 center = mix(margin, vec2(1.0) - margin, offset);
  vec2 local = fract(grid) - center;

  // Sway is horizontal: pixels outside this band cannot touch the flake.
  if (abs(local.y) >= outerRadius) return 0.0;
  local.x += sin(iTime * (0.45 + layer * 0.12) + offset.y * 6.28318)
    * swayAmount;
  float distanceSquared = dot(local, local);
  if (distanceSquared >= outerRadius * outerRadius) return 0.0;

  return 1.0 - smoothstep(radius - edge, outerRadius, sqrt(distanceSquared));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
  vec2 uv = fragCoord / iResolution.xy;
  vec4 terminal = texture(iChannel0, uv);

  // Ghostty pauses the animation loop when unfocused, but terminal output can
  // still trigger redraws. Those frames need only the unmodified terminal.
  if (iFocus == 0) {
    fragColor = terminal;
    return;
  }

  // Keep glyphs and colored terminal content clear, and skip snow calculations
  // altogether where the background mask would hide them.
  float backgroundDistance = length(terminal.rgb - iBackgroundColor);
  float backgroundMask = 1.0 - smoothstep(0.025, 0.12, backgroundDistance);
  if (backgroundMask == 0.0) {
    fragColor = terminal;
    return;
  }

  vec2 position = fragCoord / iResolution.y;
  float snow = snowLayer(position, 22.0, 0.018, 0.0) * 0.45
    + snowLayer(position, 30.0, 0.026, 1.0) * 0.32
    + snowLayer(position, 40.0, 0.036, 2.0) * 0.22;

  // Ghostty's Metal renderer has Y increasing downwards. Fade through the
  // bottom fifth, reaching zero opacity at the bottom edge.
  float bottomFade = 1.0 - smoothstep(0.8, 1.0, uv.y);
  // Layer weights sum to less than one, so no snow clamp is needed.
  float opacity = snow * backgroundMask * bottomFade * 0.42;
  vec3 snowColor = mix(iForegroundColor, vec3(1.0), 0.18);
  fragColor = vec4(mix(terminal.rgb, snowColor, opacity), terminal.a);
}
