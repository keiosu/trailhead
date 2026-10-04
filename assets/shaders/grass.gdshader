shader_type spatial;
// Grass tufts (MultiMesh). Shaded with an up-facing normal so the grass bands exactly
// like the ground it grows on. Vertex COLOR.r: 0 at the root, 1 at the tip.
render_mode cull_disabled;

#include "res://assets/shaders/toon_light.gdshaderinc"

group_uniforms grass;
uniform vec4 root_color : source_color = vec4(0.4, 0.71, 0.31, 1.0);
uniform vec4 tip_color : source_color = vec4(0.62, 0.86, 0.4, 1.0);
uniform float sway_strength : hint_range(0.0, 1.0) = 0.25;
uniform float sway_speed = 1.8;
group_uniforms;

varying vec3 instance_tint;

void vertex() {
	instance_tint = INSTANCE_CUSTOM.rgb;
	vec3 world_origin = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = TIME * sway_speed + world_origin.x * 0.35 + world_origin.z * 0.27;
	float bend = COLOR.r * COLOR.r * sway_strength * 0.25;
	VERTEX.x += sin(phase) * bend;
	VERTEX.z += sin(phase * 0.7 + 1.3) * bend * 0.5;
}

void fragment() {
	ALBEDO = mix(root_color.rgb, tip_color.rgb, COLOR.r) * instance_tint;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
