shader_type canvas_item;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.7;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.025;
uniform float scanline_strength : hint_range(0.0, 0.2) = 0.018;
uniform vec4 tint : source_color = vec4(0.17, 0.24, 0.34, 0.12);

float hash(vec2 value) {
	return fract(sin(dot(value, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float distance_from_center = length(centered * vec2(0.88, 1.08));
	float vignette = smoothstep(0.28, 0.76, distance_from_center) * vignette_strength;
	float grain = (hash(FRAGCOORD.xy + floor(TIME * 10.0)) - 0.5) * grain_strength;
	float scanline = sin(FRAGCOORD.y * 1.7) * scanline_strength;
	vec3 color = tint.rgb + vec3(grain - scanline);
	float alpha = max(tint.a, vignette * 0.78);
	COLOR = vec4(color, alpha);
}
