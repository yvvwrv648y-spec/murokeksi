// Gentle moving water for 2D water tiles or water sprites in the overworld.
// Attach to: a water Sprite2D, TextureRect, or TileMapLayer node as a ShaderMaterial.
// It bends the texture a little with two sine waves and adds a moving light band.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.75, 0.9, 1.0, 1.0);
uniform float wave_strength : hint_range(0.0, 0.05) = 0.008;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.0;

void fragment() {
	// Two wave layers moving at different speeds and directions.
	vec2 uv = UV;
	uv.x += sin(UV.y * 40.0 + TIME * wave_speed * 1.6) * wave_strength;
	uv.y += sin(UV.x * 30.0 - TIME * wave_speed * 1.1) * wave_strength * 0.6;

	vec4 water = texture(TEXTURE, uv);

	// A soft highlight band that drifts down the water.
	float band = 0.5 + 0.5 * sin((UV.y * 6.0 - TIME * wave_speed * 0.7) * 3.14159);
	float highlight = pow(band, 6.0) * 0.12;

	vec3 final_color = water.rgb * tint.rgb + vec3(highlight);
	COLOR = vec4(final_color, water.a);
}
