shader_type spatial;

render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D sprite_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);


void fragment() {
	vec4 sprite = texture(sprite_texture, UV) * tint;
	ALBEDO = sprite.rgb;
	ALPHA = sprite.a;
}
