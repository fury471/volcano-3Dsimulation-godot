shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform float intensity = 1.0;
uniform int smoke_count = 90;
uniform vec3 smoke_color = vec3(0.18, 0.18, 0.18);
uniform vec3 star_color = vec3(0.55, 0.22, 0.05);
uniform float rise_speed = 0.5;

uniform float top_fade_start = 0.65;
uniform float top_fade_end = 0.98;
uniform float side_fade_width = 0.10;


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


float smoke_particle(vec2 pos, vec2 uv, float square_radius, float round_num, float time) {
	vec2 radius = pos - uv;
	float edge = dot(radius, radius) / square_radius;

	if (edge > 1.0) {
		return 0.0;
	}

	float rotation = time * round_num * 1.85;
	float sine_value = sin(rotation);
	float cosine_value = cos(rotation);

	mat2 rotation_matrix = mat2(vec2(cosine_value, sine_value), vec2(-sine_value, cosine_value));
	vec2 rotated_offset = rotation_matrix * radius.xy;

	float noise_value = value_noise(
		random_num(round_num * 828.0) * 83.1
		+ rotated_offset * 2.0 / max(uv.y * 0.16, 0.05)
	);

	return noise_value * pow(1.0 - edge, 5.0) * 0.7;
}


void fragment() {
	float time = TIME * rise_speed;
	vec2 uv = UV * 2.0 - 1.0;
	uv += vec2(0.1, 1.1);

	vec3 final_color = vec3(0.0);
	float alpha = 0.0;

	for (int i = 0; i < 140; i++) {
		if (i >= smoke_count) {
			break;
		}

		float fi = float(i);
		float t = time + fi * (2.0 + random_num(fi * -1234.5));
		float rise_pos = mod(t, 10.0) * 0.5;
		float round_num = floor(t / 10.0);

		vec2 pos = vec2(0.0, rise_pos) * 0.5;
		pos.x += (random_num(fi) - 0.5) * uv.y;

		float density = smoke_particle(
			pos,
			uv,
			0.03 * random_num(fi * 4321.12 + round_num) + rise_pos * 0.03 + 0.001,
			random_num(fi * round_num * 1234.56),
			time
		);

		density *= max(3.0 - random_num(fi * 123.4) * 1.5 - rise_pos * 0.5, 0.001);

		float particle_alpha = clamp(density, 0.0, 1.0);
		alpha = 1.0 - (1.0 - alpha) * (1.0 - particle_alpha);
		final_color = mix(final_color, smoke_color, particle_alpha);
		final_color = mix(final_color, star_color, max((density - 1.1) * 8.0, 0.0));
	}

	float top_fade = 1.0 - smoothstep(top_fade_start, top_fade_end, UV.y);
	float left_fade = smoothstep(0.0, side_fade_width, UV.x);
	float right_fade = 1.0 - smoothstep(1.0 - side_fade_width, 1.0, UV.x);
	float side_fade = left_fade * right_fade;
	float output_alpha = clamp(alpha * intensity, 0.0, 1.0) * top_fade * side_fade;

	ALBEDO = final_color * intensity;
	ALPHA = output_alpha;
}
