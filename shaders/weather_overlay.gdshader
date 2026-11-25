// Full-screen rain or snow overlay. Pick the weather with the mode uniform.
// Attach to: a ColorRect that covers the whole screen (for example inside a
// CanvasLayer above the scene) as a ShaderMaterial.
// Mode 0 is rain: fast, thin diagonal streaks. Mode 1 is snow: slow soft dots.
// The overlay is clear everywhere except on the rain or snow itself.
shader_type canvas_item;

uniform int mode = 0;
uniform float intensity : hint_range(0.0, 1.0) = 0.6;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	float alpha = 0.0;

	if (mode == 1) {
		// Snow: a grid of dots that drifts down and sways side to side.
		vec2 snow_uv = UV;
		snow_uv.x += sin(TIME * 0.5 + UV.y * 10.0) * 0.01;
		snow_uv.y += TIME * 0.03;
		vec2 cell = fract(snow_uv * vec2(30.0, 20.0));
		float dist = length(cell - vec2(0.5, 0.5));
		alpha = smoothstep(0.18, 0.05, dist);
	} else {
		// Rain: thin diagonal lines that fall fast.
		float fall = fract(UV.x * 40.0 + UV.y * 8.0 + TIME * 1.5);
		float streak = step(0.96, fall);
		float fade = fract(UV.y * 3.0 - TIME * 2.0);
		alpha = streak * (0.4 + 0.6 * fade);
	}

	COLOR = vec4(tint.rgb, alpha * intensity);
}
