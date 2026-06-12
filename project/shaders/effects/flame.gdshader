shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform bool use_emission = false;

uniform float intensity = 4.0;
uniform float core_tightness = 3.5;
uniform float base_falloff = 1.7;

uniform float noise_scale = 10.0;
uniform float noise_speed = 4.0;

uniform vec3 col_core = vec3(1.0, 0.55, 0.20);
uniform vec3 col_red = vec3(0.95, 0.12, 0.05);
uniform vec3 col_dark = vec3(0.20, 0.02, 0.02);

varying vec3 v_world_pos;


float random_num(float n) {
	return fract(sin(n) * 98765.4321);
}


float value_noise(vec2 x) {
	vec2 p = floor(x);
	vec2 f = fract(x);
	float n = p.x + p.y * 50.0;

	float bottom = mix(random_num(n + 0.0), random_num(n + 1.0), f.x);
	float top = mix(random_num(n + 50.0), random_num(n + 51.0), f.x);
	return mix(bottom, top, f.y);
}


float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;

	for (int i = 0; i < 5; i++) {
		total += amplitude * value_noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}

	return total;
}


void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float y = UV.y;

	float horizontal_fade = exp(-abs(x) * core_tightness);
	float vertical_fade = pow(1.0 - y, base_falloff);

	vec2 noise_position = vec2(x * noise_scale, y * noise_scale - TIME * noise_speed);
	float noise_value = fbm(noise_position);
	noise_value *= noise_value;

	float flame_density = horizontal_fade * vertical_fade * (0.20 + 1.60 * noise_value);
	flame_density *= 1.0 - y * y;

	float heat = horizontal_fade * (1.0 - y);
	heat = pow(clamp(heat, 0.0, 1.0), 2.0);

	vec3 base_color = mix(col_dark, col_red, clamp(flame_density * 1.2, 0.0, 1.0));
	base_color = mix(base_color, col_core, heat);

	vec3 final_color = base_color * flame_density * intensity;

	if (v_world_pos.y < 0.0) {
		discard;
	}

	ALBEDO = final_color;
	ALPHA = clamp(flame_density * intensity, 0.0, 1.0);

	if (use_emission) {
		EMISSION = final_color;
	}
}
