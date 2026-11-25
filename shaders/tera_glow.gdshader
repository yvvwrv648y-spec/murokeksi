// Terastallized glow: a pulsing colored rim around a Pokemon sprite,
// plus a soft shimmer that moves up the sprite.
// Attach to: the Terastallized Pokemon's Sprite2D (or TextureRect) as a ShaderMaterial.
// It finds the edge of the sprite by checking the alpha just beside each pixel.
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.6, 0.9, 1.0, 1.0);
uniform float pulse_speed : hint_range(0.0, 6.0) = 2.0;
uniform float glow_strength : hint_range(0.0, 3.0) = 1.2;

void fragment() {
	vec4 sprite = texture(TEXTURE, UV);

	// Sample the alpha a little to each side to find the silhouette edge.
	vec2 offset = vec2(0.006, 0.006);
	float near_alpha = texture(TEXTURE, UV + vec2(offset.x, 0.0)).a;
	near_alpha = max(near_alpha, texture(TEXTURE, UV - vec2(offset.x, 0.0)).a);
	near_alpha = max(near_alpha, texture(TEXTURE, UV + vec2(0.0, offset.y)).a);
	near_alpha = max(near_alpha, texture(TEXTURE, UV - vec2(0.0, offset.y)).a);

	// Edge means: this pixel is clear, but a pixel next to it is drawn.
	float edge = near_alpha * (1.0 - sprite.a);

	// The glow pulses over time.
	float pulse = 0.7 + 0.3 * sin(TIME * pulse_speed * 3.14159);

	// A soft shimmer band moving up the sprite itself.
	float shimmer = pow(0.5 + 0.5 * sin((UV.y * 3.0 + TIME * 0.8) * 3.14159), 4.0) * 0.15;

	vec3 glow = glow_color.rgb * (edge * glow_strength * pulse + shimmer * sprite.a);
	float final_alpha = max(sprite.a, edge * pulse);

	COLOR = vec4(sprite.rgb + glow, final_alpha);
}
