shader_type canvas_item;

// Adapted from "Screen Smoke/Fog" by TheHyper-Dev (CC0).
// https://godotshaders.com/shader/screen-smoke-fog/
uniform sampler2D noise_texture : repeat_enable;
uniform vec4 smoke_color : source_color = vec4(0.45, 0.58, 0.72, 0.16);
uniform float distortion_speed : hint_range(0.0, 2.0) = 0.11;
uniform float density : hint_range(0.0, 1.0) = 0.2;
uniform float vertical_fade : hint_range(0.0, 1.0) = 0.62;

void fragment() {
	float time_offset_1 = TIME * distortion_speed * 0.1;
	float time_offset_2 = TIME * distortion_speed * 0.2;
	vec4 noise = texture(noise_texture, UV + time_offset_1);
	vec2 distorted_uv = UV + noise.rg * 0.1 - 0.05 + time_offset_2;
	float final_noise = texture(noise_texture, distorted_uv).r;
	float floor_mask = smoothstep(0.08, vertical_fade, UV.y);
	float edge_mask = smoothstep(0.0, 0.16, UV.x) * smoothstep(1.0, 0.84, UV.x);
	float smoke_alpha = final_noise * density * floor_mask * edge_mask * smoke_color.a;
	COLOR = vec4(smoke_color.rgb, smoke_alpha);
}
