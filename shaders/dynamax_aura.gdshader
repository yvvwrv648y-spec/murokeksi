// Dynamax aura: rising red-pink energy wisps around a Pokemon sprite.
// Attach to: the Dynamax Pokemon's Sprite2D (or TextureRect) as a ShaderMaterial.
// Sine waves layered together look like flames rising around and above the sprite.
// The sprite itself is kept, and the wisps fade out near the top.
shader_type canvas_item;

uniform vec4 aura_color : source_color = vec4(1.0, 0.25, 0.45, 1.0);
uniform float rise_speed : hint_range(0.0, 5.0) = 1.2;
uniform float strength : hint_range(0.0, 3.0) = 1.0;

void fragment() {
	vec4 sprite = texture(TEXTURE, UV);

	// Rising wisp pattern made from layered sine waves. No noise texture needed.
	float wisp_a = sin(UV.x * 40.0 + sin(UV.y * 12.0 - TIME * rise_speed * 2.0) * 2.0);
	float wisp_b = sin(UV.x * 23.0 - UV.y * 18.0 + TIME * rise_speed * 3.0);
	float wisps = pow(max(wisp_a * wisp_b, 0.0), 2.0);

	// The aura lives in a band around the sprite: strong low down,
	// fading out toward the top of the sprite.
	float band = smoothstep(1.0, 0.25, UV.y);

	// The whole aura gently pulses.
	float pulse = 0.8 + 0.2 * sin(TIME * 2.0);

	float aura = wisps * band * strength * pulse;

	// Wisps show beside and above the sprite, not covering its face and body.
	float outside = 1.0 - sprite.a;
	vec3 final_color = sprite.rgb + aura_color.rgb * aura * (0.35 + 0.65 * outside);
	float final_alpha = max(sprite.a, aura * outside);

	COLOR = vec4(final_color, final_alpha);
}
