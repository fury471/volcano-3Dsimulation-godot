shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform float intensity = 1.0; //烟雾浓度
uniform int smoke_count = 90; //烟团数量
uniform vec3 smoke_color = vec3(0.18, 0.18, 0.18); //烟颜色
uniform vec3 star_color = vec3(0.55, 0.22, 0.05); //小火星颜色
uniform float rise_speed = 0.5; //烟上升速度

uniform float top_fade_start = 0.65; //上方的渐变消失，不然会有一个直线
uniform float top_fade_end = 0.98;
uniform float side_fade_width = 0.10; //左右

float randomNum(float n) { //随机数生成函数
	return fract(sin(n) * 98765.4321);
}

float noise(vec2 x) { //噪声生成函数
	vec2 p = floor(x);
	vec2 f = fract(x);
	float n = p.x + p.y*50.0;
	return mix( mix( randomNum(n+0.0), randomNum(n+1.0), f.x), mix(randomNum(n+50.0), randomNum(n+51.0), f.x), f.y);
}

float SmokeParticle(vec2 pos, vec2 uv, float square_radius, float round_num, float time) { 
	vec2 radius =pos - uv;
	float edge = dot(radius, radius) / square_radius;
	if (edge > 1.0) return 0.0;

	float r = time * round_num * 1.85;
	float si = sin(r);
	float co = cos(r);

	mat2 rot_matrix = mat2(vec2(co, si), vec2(-si, co));
	vec2 rotated_offset = rot_matrix * radius.xy;

	float n = noise(randomNum(round_num *828.0)*83.1 + rotated_offset * 2.0 / max(uv.y * 0.16, 0.05));
	float density = n * pow(1.0 - edge, 5.0) * 0.7;

	return density;
}

void fragment() {
	float time = TIME * rise_speed;

	vec2 uv = UV * 2.0 - 1.0;

	uv += vec2(0.1, 1.1);
	vec3 final_color = vec3(0.0);
	float alpha = 0.0;

	for (int i = 0; i < 140; i++) {
		if (i >= smoke_count) break;

		float fi = float(i);
		float t  = time + fi * (2.0 + randomNum(fi * -1234.5));
		float rise_pos = mod(t, 10.0) * 0.5;
		float round_num = floor(t / 10.0);

		vec2 pos = vec2(0.0, rise_pos) * 0.5;
		pos.x += (randomNum(fi) - 0.5) * uv.y;

		float density = SmokeParticle(
			pos, uv,
			0.03 * randomNum(fi * 4321.12 + round_num) + rise_pos * 0.03 +0.001,
			randomNum(fi * round_num * 1234.56),
			time
		);

		density = density * max((3.0 - (randomNum(fi * 123.4) * 1.5) - rise_pos * 0.5), 0.001);
		float a = clamp(density, 0.0, 1.0);
		alpha = 1.0 - (1.0 - alpha) * (1.0 - a); //烟团堆叠，越多越浓，但是不会超过1
		final_color = mix(final_color, smoke_color, a);
		final_color = mix(final_color, star_color, max((density - 1.1) * 8.0, 0.0));
	}

	float top_fade = 1.0 - smoothstep(top_fade_start, top_fade_end, UV.y);
	
	float left_fade  = smoothstep(0.0, side_fade_width, UV.x);
	float right_fade = 1.0 - smoothstep(1.0 - side_fade_width, 1.0, UV.x);
	float side_fade  = left_fade * right_fade;
	
	float a_out = clamp(alpha * intensity, 0.0, 1.0) * top_fade * side_fade;

	ALBEDO = final_color * intensity;
	ALPHA  = a_out;
}
