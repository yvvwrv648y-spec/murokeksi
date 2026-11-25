// Shiny sparkle overlay for a shiny Pokemon sprite.
// Attach to: the shiny Pokemon's Sprite2D (or TextureRect) as a ShaderMaterial.
// It keeps the sprite's own colors and adds moving star-like glints,
// but only where the sprite is already drawn (its alpha).
shader_type canvas_item;

uniform vec4 sparkle_color : source_color = vec4(1.0, 1.0, 0.75, 1.0);
uniform float speed : hint_range(0.0, 5.0) = 1.5;
uniform float density : hint_range(4.0, 60.0) = 24.0;

void fragment() {
	vec4 sprite = texture(TEXTURE, UV);

	// Two crossing waves make small bright spots where they line up.
	float wave_a = sin((UV.x + UV.y) * density * 3.14159 + TIME * speed * 2.0);
	float wave_b = sin((UV.x - UV.y) * density * 3.14159 - TIME * speed * 1.7);
	float glint = pow(max(wave_a * wave_b, 0.0), 8.0);

	// A slow sweep so the glints travel across the sprite over time.
	float sweep = 0.5 + 0.5 * sin((UV.x - UV.y) * 2.0 + TIME * speed);
	glint = glint * (0.4 + 0.6 * sweep);

	// Sparkles only show on the opaque parts of the sprite.
	vec3 final_color = sprite.rgb + sparkle_color.rgb * glint * sprite.a;
	COLOR = vec4(final_color, sprite.a);
}
