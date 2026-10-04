shader_type spatial;
// Shared toon / cel shader for characters, props and placeables.
// Lighting lives in toon_light.gdshaderinc.

#include "res://assets/shaders/toon_light.gdshaderinc"

group_uniforms surface;
uniform vec4 albedo : source_color = vec4(1.0);
// Shared palette texture (palette.png) goes here; white by default.
uniform sampler2D albedo_texture : source_color, filter_nearest, hint_default_white;
// Multiply in mesh vertex colors (procedural props carry their colors this way).
uniform bool use_vertex_color = false;
group_uniforms;

void fragment() {
	vec3 color = albedo.rgb * texture(albedo_texture, UV).rgb;
	if (use_vertex_color) {
		color *= COLOR.rgb;
	}
	ALBEDO = color;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	// No environment reflections: the look comes from bands, not PBR.
	SPECULAR = 0.0;
}
