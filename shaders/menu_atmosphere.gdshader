shader_type canvas_item;

uniform sampler2D noise_texture : repeat_enable, filter_linear;
uniform float cycle_seconds : hint_range(1.0, 120.0) = 30.0;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.72;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.018;
uniform float scanline_strength : hint_range(0.0, 0.2) = 0.008;
uniform vec4 tint : source_color = vec4(0.1, 0.16, 0.24, 0.1);
uniform float readability_shade : hint_range(0.0, 1.0) = 0.14;


void fragment() {
	float duration = max(cycle_seconds, 0.001);
	float loop_progress = mod(TIME, duration) / duration;
	float phase = loop_progress * 6.28318530718;

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
	float combined_alpha = finish_alpha;
	vec3 combined_premultiplied = finish_color * finish_alpha;

	combined_premultiplied *= 1.0 - readability_shade;
	combined_alpha = readability_shade + combined_alpha * (1.0 - readability_shade);
	vec3 combined_color = combined_premultiplied / max(combined_alpha, 0.0001);
	COLOR = vec4(combined_color, combined_alpha);
}
