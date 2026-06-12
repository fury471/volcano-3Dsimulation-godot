shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform float intensity = 8.0;
uniform float lava_count_f = 24.0;

uniform float cycle = 3.0;
uniform float gravity = 0.6;
uniform float speed_y = 1.0;
uniform float speed_x = 1.0;
uniform float sim_scale = 0.35;

uniform vec3 hot_color = vec3(1.0, 0.45, 0.08);
uniform vec3 cool_color = vec3(0.25, 0.05, 0.02);


float random_num(float n) {
	return fract(sin(n) * 98765.4321);
}


float soft_blob(vec2 p, float r) {
	float d = length(p) / max(r, 0.001);
	return exp(-d * d * 4.0);
}


void fragment() {
	float time = TIME;
	vec2 uv = UV * 2.0 - 1.0;
	uv += vec2(0.0, 0.7);

	vec3 color = vec3(0.0);
	float alpha = 0.0;

	for (int i = 0; i < 80; i++) {
		if (i >= int(lava_count_f)) {
			break;
		}

		float fi = float(i);
		float tm = mod(time + 0.15 * (fi + 0.6 * random_num(fi)), cycle);
		float angle = 2.0 * PI * random_num(100.11 * fi);

		vec2 horizontal_velocity = 0.7 * vec2(cos(angle), sin(angle)) * speed_x;
		float vertical_velocity = (1.4 + 0.3 * random_num(11.11 * fi)) * speed_y;

		vec2 start_position = 0.1 * horizontal_velocity;
		vec2 position;
		position.x = start_position.x + horizontal_velocity.x * tm;
		position.y = vertical_velocity * tm - gravity * tm * tm;
		position *= sim_scale;

		vec2 delta = uv - position;
		float life = tm / max(cycle, 0.001);
		float radius = mix(0.09, 0.03, life) * (0.7 + 0.6 * random_num(fi * 33.3));
		float blob = soft_blob(delta, radius);

		if (blob < 0.002) {
			continue;
		}

		vec3 particle_color = mix(hot_color, cool_color, pow(life, 1.2));
		color += particle_color * blob * intensity;
		alpha = max(alpha, blob);
	}

	ALBEDO = color;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
