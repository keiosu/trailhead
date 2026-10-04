shader_type spatial;
// MultiMesh scatter (trees, bushes, rocks, flowers). Colors come from vertex COLOR
// times a per-instance tint in INSTANCE_CUSTOM.rgb. Gentle wind sway grows with height.
// No outline pass: too costly and noisy on foliage.

#include "res://assets/shaders/toon_light.gdshaderinc"

group_uniforms wind;
uniform float sway_strength : hint_range(0.0, 0.2) = 0.02;
uniform float sway_speed = 1.1;
group_uniforms;

varying vec3 instance_tint;

void vertex() {
	instance_tint = INSTANCE_CUSTOM.rgb;
	vec3 world_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = TIME * sway_speed + world_origin.x * 0.21 + world_origin.z * 0.17;
	float bend = VERTEX.y * VERTEX.y * sway_strength;
	VERTEX.x += sin(phase) * bend;
	VERTEX.z += cos(phase * 0.8) * bend * 0.6;
}

void fragment() {
	ALBEDO = COLOR.rgb * instance_tint;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
