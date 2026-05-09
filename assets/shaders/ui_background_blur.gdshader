shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 4.0) = 2.6;
uniform vec4 tint_color : source_color = vec4(0.18, 0.2, 0.16, 0.42);

void fragment() {
	vec4 screen_sample = textureLod(SCREEN_TEXTURE, SCREEN_UV, blur_lod);
	COLOR = mix(screen_sample, tint_color, tint_color.a);
	COLOR.a = 1.0;
}
