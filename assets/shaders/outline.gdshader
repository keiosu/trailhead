shader_type spatial;
// Inverted-hull outline. Use as `next_pass` on a toon material.
// Not for MultiMesh foliage or grass.
render_mode unshaded, cull_front, shadows_disabled, fog_disabled;

uniform vec4 outline_color : source_color = vec4(0.13, 0.1, 0.2, 1.0);
// Outline thickness in meters at close range.
uniform float outline_width : hint_range(0.0, 0.1) = 0.018;
// Outline thins out between these camera distances and is gone past fade_end.
uniform float fade_start = 25.0;
uniform float fade_end = 70.0;

void vertex() {
	// Push out in view space so width stays in meters regardless of node scale.
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float fade = 1.0 - smoothstep(fade_start, fade_end, -view_pos.z);
	view_pos.xyz += view_normal * outline_width * fade;
	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
