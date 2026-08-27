shader_type spatial;

render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D overlay_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 source_rect = vec4(0.214, 0.498, 0.615, 0.542);
uniform float opacity : hint_range(0.0, 1.0) = 0.58;
uniform float reference_camera_z = 10.0899;
uniform float reference_tan_half_fov = 0.46630766;
uniform float reference_aspect = 1.7768332;
uniform vec2 projection_scale = vec2(0.84);
uniform vec2 projection_offset = vec2(0.08);

varying vec3 projection_world_position;


void vertex() {
	projection_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	float depth = max(reference_camera_z - projection_world_position.z, 0.001);
	vec2 projected = vec2(
		projection_world_position.x / (depth * reference_tan_half_fov * reference_aspect),
		projection_world_position.y / (depth * reference_tan_half_fov)
	);
	vec2 projected_uv = vec2(projected.x * 0.5 + 0.5, 0.5 - projected.y * 0.5);
	vec2 room_uv = projected_uv * projection_scale + projection_offset;
	vec2 overlay_uv = (room_uv - source_rect.xy) / source_rect.zw;
	if (any(lessThan(overlay_uv, vec2(0.0))) || any(greaterThan(overlay_uv, vec2(1.0)))) {
		discard;
	}
	vec4 overlay = texture(overlay_texture, overlay_uv);
	ALBEDO = overlay.rgb;
	ALPHA = overlay.a * opacity;
}
