shader_type spatial;

render_mode unshaded, cull_front, depth_draw_never, depth_test_disabled, blend_mix;

uniform sampler3D volume_noise : repeat_enable, filter_linear;
uniform vec4 fog_color : source_color = vec4(0.46, 0.51, 0.55, 1.0);
uniform float density : hint_range(0.0, 4.0) = 0.82;
uniform float base_density : hint_range(0.0, 0.5) = 0.012;
uniform float max_opacity : hint_range(0.0, 0.8) = 0.18;
uniform float noise_scale : hint_range(0.01, 1.0) = 0.14;
uniform float contrast : hint_range(0.0, 1.0) = 0.46;
uniform float ceiling_variation : hint_range(0.0, 0.8) = 0.38;
uniform float cycle_seconds : hint_range(1.0, 120.0) = 30.0;

const int MARCH_STEPS = 12;

varying vec3 fog_local_position;


void vertex() {
	fog_local_position = VERTEX;
}


void fragment() {
	float duration = max(cycle_seconds, 0.001);
	float phase = mod(TIME, duration) / duration * 6.28318530718;
	vec3 noise_orbit = vec3(
		cos(phase) * 0.23,
		sin(phase * 2.0 + 0.83) * 0.11,
		sin(phase) * 0.23
	);

	mat4 inverse_model = inverse(MODEL_MATRIX);
	vec3 camera_local = (inverse_model * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec3 ray_direction = normalize(fog_local_position - camera_local);
	vec3 safe_direction = sign(ray_direction + vec3(0.000001)) * max(abs(ray_direction), vec3(0.0001));
	vec3 inverse_direction = 1.0 / safe_direction;
	vec3 intersection_a = (vec3(-0.5) - camera_local) * inverse_direction;
	vec3 intersection_b = (vec3(0.5) - camera_local) * inverse_direction;
	vec3 entry_axis = min(intersection_a, intersection_b);
	vec3 exit_axis = max(intersection_a, intersection_b);
	float entry_distance = max(max(entry_axis.x, entry_axis.y), entry_axis.z);
	float exit_distance = min(min(exit_axis.x, exit_axis.y), exit_axis.z);
	entry_distance = max(entry_distance, 0.0);
	if (exit_distance <= entry_distance) {
		discard;
	}

	float step_length = (exit_distance - entry_distance) / float(MARCH_STEPS);
	float stable_jitter = texture(volume_noise, vec3(SCREEN_UV * vec2(2.0, 1.125), 0.371)).r;
	float sample_distance = entry_distance + step_length * stable_jitter;
	float accumulated_alpha = 0.0;
	vec3 accumulated_color = vec3(0.0);

	for (int step_index = 0; step_index < MARCH_STEPS; step_index++) {
		vec3 sample_local = camera_local + ray_direction * sample_distance;
		vec3 sample_world = (MODEL_MATRIX * vec4(sample_local, 1.0)).xyz;
		vec3 anchored_uvw = sample_world * noise_scale + noise_orbit;
		float noise_value = texture(volume_noise, anchored_uvw).r;
		float shaped_noise = smoothstep(contrast, 0.86, noise_value);

		float normalized_height = clamp(sample_local.y + 0.5, 0.0, 1.0);
		float fog_ceiling = 0.28 + noise_value * ceiling_variation;
		float ceiling_mask = 1.0 - smoothstep(fog_ceiling - 0.16, fog_ceiling + 0.13, normalized_height);
		float floor_mask = smoothstep(0.0, 0.075, normalized_height);
		float side_distance = min(0.5 - abs(sample_local.x), 0.5 - abs(sample_local.z));
		float side_fade = smoothstep(0.0, 0.16, side_distance);
		float local_density = mix(base_density, 1.0, shaped_noise);
		local_density *= ceiling_mask * floor_mask * side_fade;

		float sample_alpha = 1.0 - exp(-local_density * density * step_length * 1.2);
		sample_alpha = min(sample_alpha, max_opacity);
		float contribution = (1.0 - accumulated_alpha) * sample_alpha;
		vec3 sample_color = mix(fog_color.rgb * 0.78, fog_color.rgb, shaped_noise);
		accumulated_color += sample_color * contribution;
		accumulated_alpha += contribution;
		sample_distance += step_length;
	}

	ALBEDO = accumulated_color / max(accumulated_alpha, 0.0001);
	ALPHA = min(accumulated_alpha, max_opacity);
}
