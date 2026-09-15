// Toon / cel shader — banded diffuse, tinted shadow, thin rim light.
// Pair with materials/ink_outline.tres as next_pass for the inverted-hull ink line.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.84, 0.80, 0.72, 1.0);
// Shadow is a TINT, not just "darker" — cool purple shadow on warm light is what
// makes printed comic art read as ink-over-wash instead of grey 3D.
uniform vec4 shadow_tint : source_color = vec4(0.40, 0.385, 0.56, 1.0);
uniform int band_count : hint_range(2, 6) = 3;
uniform float band_softness : hint_range(0.0, 0.25) = 0.03;

uniform float rim_strength : hint_range(0.0, 2.0) = 0.35;
uniform float rim_start : hint_range(0.0, 1.0) = 0.60;
uniform vec4 rim_color : source_color = vec4(1.0, 0.98, 0.92, 1.0);

// Cheap paper grain so flat fills aren't dead flat.
uniform float grain_strength : hint_range(0.0, 0.5) = 0.06;
uniform float grain_scale = 320.0;

float hash21(vec2 p) {
	p = fract(p * vec2(233.34, 851.73));
	p += dot(p, p + 23.45);
	return fract(p.x * p.y);
}

void fragment() {
	// COLOR is (1,1,1,1) on meshes without a colour array, so this is free for
	// everything except the MultiMesh grass, which uses it to vary each tuft.
	vec3 col = base_color.rgb * COLOR.rgb;

	float g = hash21(floor(SCREEN_UV * grain_scale));
	col *= 1.0 + (g - 0.5) * grain_strength;

	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;

	float f = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = smoothstep(rim_start, min(rim_start + 0.35, 0.999), f);
	EMISSION = rim_color.rgb * rim * rim_strength;
}

void light() {
	float ndotl = dot(normalize(NORMAL), normalize(LIGHT));
	// Half-lambert: blocky faces get too binary with raw N·L.
	float wrapped = clamp(ndotl * 0.5 + 0.5, 0.0, 1.0);

	float b = float(band_count);
	float scaled = wrapped * b;
	float idx = floor(scaled);
	float frac_part = scaled - idx;
	// Soften the band edge just enough to kill shimmer without going gradient.
	float edge = smoothstep(0.5 - band_softness, 0.5 + band_softness, frac_part);
	float stepped = clamp((idx + edge) / max(b - 1.0, 1.0), 0.0, 1.0);

	stepped *= ATTENUATION;

	vec3 shaded = mix(ALBEDO * shadow_tint.rgb, ALBEDO, stepped);
	// The / PI is not optional. Godot's built-in diffuse divides by it; a custom
	// light() that forgets to is ~3.1x too bright and the whole scene blows out.
	DIFFUSE_LIGHT += LIGHT_COLOR * shaded / PI;
}
