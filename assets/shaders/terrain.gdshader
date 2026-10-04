shader_type spatial;
// Toon terrain: flat color regions picked by slope, height, trail and shore.
// Vertex COLOR.r = signed distance to the trail / TRAIL_DISTANCE_SCALE * 0.5 + 0.5,
// COLOR.g = patch noise (0..1), COLOR.b = 1 near the lake (where sand may appear),
// COLOR.a = unsigned trail distance / TRAIL_DISTANCE_SCALE.

#include "res://assets/shaders/toon_light.gdshaderinc"

// Must match Terrain.TRAIL_DISTANCE_SCALE.
const float TRAIL_DISTANCE_SCALE = 16.0;
// The signed distance is only trusted this close to the trail. Farther out its sign can
// flip between trail legs, and interpolating across a flip would draw a fake trail line.
const float SIGNED_TRUST_DISTANCE = 5.0;

group_uniforms terrain_colors;
uniform vec4 grass_color : source_color = vec4(0.47, 0.78, 0.33, 1.0);
uniform vec4 grass_alt_color : source_color = vec4(0.4, 0.71, 0.31, 1.0);
uniform vec4 alpine_color : source_color = vec4(0.7, 0.8, 0.44, 1.0);
uniform vec4 rock_color : source_color = vec4(0.62, 0.6, 0.66, 1.0);
uniform vec4 dirt_color : source_color = vec4(0.78, 0.6, 0.4, 1.0);
uniform vec4 dirt_edge_color : source_color = vec4(0.66, 0.52, 0.34, 1.0);
uniform vec4 sand_color : source_color = vec4(0.93, 0.86, 0.64, 1.0);

group_uniforms terrain_rules;
uniform float rock_slope_degrees = 36.0;
uniform float alpine_height = 62.0;
uniform float trail_half_width = 1.3;
// Set by the world after generation.
uniform float water_level = -1000.0;
uniform float shore_height = 0.5;
// Extra blur on color-region edges, in pixels. ~1 keeps toon edges crisp but not aliased.
uniform float edge_pixels = 1.0;
group_uniforms;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Crisp step whose blur is a fixed number of screen pixels, at any distance.
float region(float value, float edge, float min_softness) {
	float softness = max(fwidth(value) * edge_pixels, min_softness);
	return smoothstep(edge - softness, edge + softness, value);
}

void fragment() {
	float patch_value = COLOR.g;
	vec3 color = mix(grass_color.rgb, grass_alt_color.rgb, region(patch_value, 0.5, 0.0));

	// Alpine meadow above a wobbly line.
	float alpine = region(world_pos.y + (patch_value - 0.5) * 10.0, alpine_height, 0.0);
	color = mix(color, alpine_color.rgb, alpine);

	float slope_degrees = degrees(acos(clamp(world_normal.y, -1.0, 1.0)));
	color = mix(color, rock_color.rgb, region(slope_degrees + (patch_value - 0.5) * 6.0, rock_slope_degrees, 0.0));

	float shore = (1.0 - region(world_pos.y, water_level + shore_height, 0.0)) * step(0.5, COLOR.b);
	color = mix(color, sand_color.rgb, shore);

	float unsigned_distance = COLOR.a * TRAIL_DISTANCE_SCALE;
	float signed_distance = abs((COLOR.r - 0.5) * 2.0 * TRAIL_DISTANCE_SCALE);
	float trail_distance = unsigned_distance < SIGNED_TRUST_DISTANCE ? signed_distance : unsigned_distance;
	float edge = 1.0 - region(trail_distance, trail_half_width + 0.3, 0.0);
	float core = 1.0 - region(trail_distance, trail_half_width, 0.0);
	color = mix(color, dirt_edge_color.rgb, edge);
	color = mix(color, dirt_color.rgb, core);

	ALBEDO = color;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
