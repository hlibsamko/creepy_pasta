shader_type spatial;

render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D noise_texture : repeat_enable, filter_linear;
uniform vec4 fog_color : source_color = vec4(0.34, 0.46, 0.63, 1.0);
uniform float opacity : hint_range(0.0, 0.4) = 0.085;
uniform float noise_scale : hint_range(0.01, 1.0) = 0.17;
uniform float contrast : hint_range(0.0, 1.0) = 0.42;
uniform float phase_offset : hint_range(0.0, 6.283185) = 0.0;
uniform float cycle_seconds : hint_range(1.0, 120.0) = 30.0;

varying vec3 fog_world_position;


void vertex() {
	fog_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	float duration = max(cycle_seconds, 0.001);
	float phase = mod(TIME, duration) / duration * 6.28318530718 + phase_offset;
	vec2 orbit_a = vec2(cos(phase), sin(phase)) * 0.37;
	vec2 orbit_b = vec2(cos(phase * 3.0 + 0.83), sin(phase * 3.0 + 0.83)) * 0.16;
	vec2 anchored_uv = fog_world_position.xz * noise_scale;
	float broad_noise = texture(noise_texture, anchored_uv + orbit_a).r;
	float detail_noise = texture(noise_texture, anchored_uv * 2.17 + orbit_b).r;
	float density = mix(broad_noise, detail_noise, 0.34);
	density = smoothstep(contrast, 0.88, density);

	float edge_x = smoothstep(0.0, 0.12, UV.x) * (1.0 - smoothstep(0.88, 1.0, UV.x));
	float edge_y = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.88, 1.0, UV.y));
	ALBEDO = fog_color.rgb;
	ALPHA = density * edge_x * edge_y * opacity;
}
