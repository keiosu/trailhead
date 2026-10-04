// Shared toon lighting. #include from every lit spatial shader so the whole game
// bands, tints shadows and rims the same way.
// 2-band diffuse with colored shadows, toon-banded cast shadows, optional hard
// specular, and a subtle rim light on the lit side.

group_uniforms toon_bands;
// N·L value where lit flips to shadow. Lower = more of the surface is lit.
uniform float band_threshold : hint_range(-1.0, 1.0) = 0.0;
// Half-width of the lit/shadow edge. Keep small (~0.02) for crisp bands.
uniform float band_softness : hint_range(0.0, 0.2) = 0.02;
// Cool tint multiplied into the shadow side of directional light. Never black.
uniform vec4 shadow_tint : source_color = vec4(0.42, 0.42, 0.68, 1.0);
// Optional art-directed ramp: x = (N·L * 0.5 + 0.5) * cast shadow, red channel = lit amount.
uniform bool use_ramp = false;
uniform sampler2D ramp_texture : filter_linear, repeat_disable, hint_default_white;

group_uniforms toon_specular;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.0;
uniform float specular_glossiness : hint_range(1.0, 256.0) = 48.0;

group_uniforms toon_rim;
uniform vec4 rim_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.2;
// Fraction of the silhouette covered by the rim (0 = none, 1 = everything).
uniform float rim_width : hint_range(0.0, 1.0) = 0.3;
group_uniforms;

float toon_band(float x, float edge) {
	return smoothstep(edge - band_softness, edge + band_softness, x);
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	// LIGHT_COLOR already includes energy * PI.
	vec3 light_rgb = LIGHT_COLOR / PI;

	if (LIGHT_IS_DIRECTIONAL) {
		// For directional lights ATTENUATION is the cast shadow only; band it so shadows are hard.
		float cast = toon_band(ATTENUATION, 0.5);
		float lit;
		if (use_ramp) {
			lit = texture(ramp_texture, vec2(clamp((n_dot_l * 0.5 + 0.5) * cast, 0.0, 1.0), 0.5)).r;
		} else {
			lit = toon_band(n_dot_l, band_threshold) * cast;
		}
		DIFFUSE_LIGHT += light_rgb * mix(shadow_tint.rgb, vec3(1.0), lit);

		if (specular_strength > 0.0) {
			vec3 half_vec = normalize(VIEW + LIGHT);
			float spec = pow(max(dot(NORMAL, half_vec), 0.0), specular_glossiness);
			SPECULAR_LIGHT += light_rgb * toon_band(spec, 0.5) * lit * specular_strength;
		}

		if (rim_strength > 0.0) {
			float rim_dot = 1.0 - max(dot(VIEW, NORMAL), 0.0);
			float rim = toon_band(rim_dot, 1.0 - rim_width) * lit;
			SPECULAR_LIGHT += light_rgb * rim_color.rgb * rim * rim_strength;
		}
	} else {
		// Point/spot lights (campfire, lantern): banded falloff so pools of light read as toon.
		float lit = toon_band(n_dot_l, band_threshold);
		DIFFUSE_LIGHT += light_rgb * lit * ATTENUATION;
	}
}
