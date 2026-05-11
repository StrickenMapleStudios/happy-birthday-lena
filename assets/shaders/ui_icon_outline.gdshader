shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.22, 0.16, 0.02, 0.95);
uniform float outline_size = 1.0;

void fragment() {
	vec4 base_color = texture(TEXTURE, UV) * COLOR;
	float alpha = base_color.a;

	vec2 pixel_size = TEXTURE_PIXEL_SIZE * outline_size;
	float outline_alpha = 0.0;
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(pixel_size.x, 0.0)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(-pixel_size.x, 0.0)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(0.0, pixel_size.y)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(0.0, -pixel_size.y)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(pixel_size.x, pixel_size.y)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(-pixel_size.x, pixel_size.y)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(pixel_size.x, -pixel_size.y)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(-pixel_size.x, -pixel_size.y)).a);

	float border = max(outline_alpha - alpha, 0.0);
	vec3 final_rgb = mix(outline_color.rgb, base_color.rgb, alpha);
	float final_alpha = max(alpha, border * outline_color.a);

	COLOR = vec4(final_rgb, final_alpha);
}
