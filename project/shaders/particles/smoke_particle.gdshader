shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform float opacity = 0.9;

varying float life_ratio;

void vertex() {
	// The script sends Color(size, life_ratio, 0, 0)
	life_ratio = INSTANCE_CUSTOM.g;

	// Add billboard logic so smoke always faces camera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float u = life_ratio;

	// Fade in quickly, fade out slowly
	float fade_in  = smoothstep(0.0, 0.08, u);
	float fade_out = smoothstep(1.0, 0.6, u);
	float a = opacity * fade_in * fade_out;

	// Dark -> lighter over life (smoke disperses)
	vec3 c0 = vec3(0.10, 0.10, 0.10);
	vec3 c1 = vec3(0.35, 0.35, 0.35);
	ALBEDO = mix(c0, c1, u);

	ALPHA = a;
}