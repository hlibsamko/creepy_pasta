shader_type canvas_item;

uniform sampler2D noise_texture : repeat_enable, filter_linear;
uniform float cycle_seconds : hint_range(1.0, 120.0) = 30.0;

uniform vec4 smoke_color : source_color = vec4(0.42, 0.55, 0.72, 0.42);
uniform float fog_density : hint_range(0.0, 1.0) = 0.55;
uniform float fog_vertical_fade : hint_range(0.0, 1.0) = 0.62;
uniform float global_haze : hint_range(0.0, 0.12) = 0.035;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.72;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.018;
uniform float scanline_strength : hint_range(0.0, 0.2) = 0.008;
uniform vec4 tint : source_color = vec4(0.1, 0.16, 0.24, 0.1);
uniform float readability_shade : hint_range(0.0, 1.0) = 0.14;


void fragment() {
	float duration = max(cycle_seconds, 0.001);
	float loop_progress = mod(TIME, duration) / duration;
	float phase = loop_progress * 6.28318530718;

	// Integer harmonics make both paths return to the exact same position
	// after one cycle. The result behaves like a seamless 30-second clip.
	vec2 fog_orbit_a = vec2(cos(phase), sin(phase)) * 0.13;
	vec2 fog_orbit_b = vec2(cos(phase * 2.0 + 1.31), sin(phase * 2.0 + 1.31)) * 0.075;
	vec4 first_noise = texture(noise_texture, UV * vec2(1.16, 0.92) + fog_orbit_a);
	vec2 distorted_uv = UV + (first_noise.rg - vec2(0.5)) * 0.095 + fog_orbit_b;
	float fog_noise = texture(noise_texture, distorted_uv).r;
	fog_noise = smoothstep(0.34, 0.72, fog_noise);

	float floor_mask = smoothstep(0.06, fog_vertical_fade, UV.y);
	float left_mask = smoothstep(0.0, 0.14, UV.x);
	float right_mask = 1.0 - smoothstep(0.86, 1.0, UV.x);
	float fog_alpha = fog_noise * fog_density * floor_mask * left_mask * right_mask * smoke_color.a;
	float haze_alpha = global_haze * mix(0.82, 1.0, fog_noise);
	fog_alpha = 1.0 - (1.0 - fog_alpha) * (1.0 - haze_alpha);

	vec2 centered = UV - vec2(0.5);
	float distance_from_center = length(centered * vec2(0.88, 1.08));
	float vignette = smoothstep(0.28, 0.76, distance_from_center) * vignette_strength;

	// A texture lookup is cheaper and more repeatable than the previous
	// per-pixel sine hash. Seven whole orbits still close after 30 seconds.
	vec2 grain_orbit = vec2(cos(phase * 7.0), sin(phase * 7.0)) * 0.31;
	float grain_sample = texture(noise_texture, UV * vec2(10.0, 5.625) + grain_orbit).r;
	float grain = (grain_sample - 0.5) * grain_strength;
	float scanline = (abs(fract(FRAGCOORD.y * 0.42) - 0.5) * 2.0 - 0.5) * scanline_strength;

	float finish_alpha = max(tint.a, vignette * 0.78);
	vec3 finish_color = tint.rgb + vec3(grain - scanline);
	float combined_alpha = finish_alpha + fog_alpha * (1.0 - finish_alpha);
	vec3 combined_premultiplied = finish_color * finish_alpha;
	combined_premultiplied += smoke_color.rgb * fog_alpha * (1.0 - finish_alpha);

	combined_premultiplied *= 1.0 - readability_shade;
	combined_alpha = readability_shade + combined_alpha * (1.0 - readability_shade);
	vec3 combined_color = combined_premultiplied / max(combined_alpha, 0.0001);
	COLOR = vec4(combined_color, combined_alpha);
}
