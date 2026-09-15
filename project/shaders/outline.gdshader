// Inverted-hull ink outline. Used as next_pass on toon materials.
//
// radial_expand: box meshes have split normals at their edges, so expanding along
// NORMAL leaves gaps at every corner. Expanding along normalize(VERTEX) instead
// pushes the 8 corner verts diagonally outward and keeps the shell watertight.
// Turn it off for organic/smooth-normal meshes.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec4 ink_color : source_color = vec4(0.07, 0.06, 0.10, 1.0);
// With screen_constant = 1 this is roughly an angular width, so ~0.0045 lands at
// a 2-3 px line at 1080p. It is not a world-space distance.
uniform float thickness : hint_range(0.0, 0.05) = 0.0045;
uniform bool radial_expand = true;
// 1.0 = constant thickness on screen regardless of distance (comic ink weight).
// 0.0 = thickness in world units, lines thin out with distance.
uniform float screen_constant : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	vec3 dir = radial_expand ? normalize(VERTEX + vec3(1e-5)) : NORMAL;

	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_dir = normalize((MODELVIEW_MATRIX * vec4(dir, 0.0)).xyz);

	float dist = mix(1.0, max(-view_pos.z, 0.05), screen_constant);
	view_pos.xyz += view_dir * thickness * dist;

	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	ALBEDO = ink_color.rgb;
}
