shader_type spatial;
// Toon water: flat color that deepens with depth, animated foam lines at the shore.
render_mode cull_back, depth_draw_always;

#include "res://assets/shaders/toon_light.gdshaderinc"

uniform sampler2D depth_texture : hint_depth_texture, filter_linear;

group_uniforms water;
uniform vec4 shallow_color : source_color = vec4(0.36, 0.8, 0.84, 1.0);
uniform vec4 deep_color : source_color = vec4(0.1, 0.42, 0.72, 1.0);
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);
// Depth (m) over which shallow turns to deep.
uniform float depth_fade = 2.2;
// Solid foam hugging the shore (m of water depth).
uniform float foam_width = 0.18;
// A second foam line that drifts out from the shore and back.
uniform float foam_line_distance = 0.55;
uniform float foam_line_width = 0.06;
uniform float foam_speed = 0.9;
uniform float opacity : hint_range(0.0, 1.0) = 0.95;
group_uniforms;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	view.xyz /= view.w;
	float water_depth = max(-view.z - (-VERTEX.z), 0.0);

	float wobble = sin(world_pos.x * 0.9 + TIME * 0.7) * 0.04 + sin(world_pos.z * 1.3 - TIME * 0.5) * 0.04;
	float depth_mix = smoothstep(0.0, depth_fade, water_depth);
	vec3 color = mix(shallow_color.rgb, deep_color.rgb, depth_mix);

	float shore_foam = 1.0 - step(foam_width + wobble, water_depth);
	float line_at = foam_line_distance * (0.75 + 0.25 * sin(TIME * foam_speed));
	float line_foam = 1.0 - step(foam_line_width, abs(water_depth - line_at - wobble));
	float foam = max(shore_foam, line_foam);
	color = mix(color, foam_color.rgb, foam);

	ALBEDO = color;
	ALPHA = mix(opacity, 1.0, foam);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
