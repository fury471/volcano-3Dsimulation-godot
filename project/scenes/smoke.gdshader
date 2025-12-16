shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform float intensity = 1.0; //烟雾浓度
uniform int smoke_count = 90; //烟团数量
uniform vec3 smoke_color = vec3(0.18, 0.18, 0.18); //烟颜色
uniform vec3 star_color = vec3(0.55, 0.22, 0.05); //小火星颜色

uniform float top_fade_start = 0.65; //上方的渐变消失，不然会有一个直线
uniform float top_fade_end = 0.98;

float randomNum(float n) { //随机数生成函数
	return fract(sin(n) * 98765.4321);
}

float noise(vec2 x) { //噪声生成函数
	vec2 p = floor(x);
	vec2 f = fract(x);
	float n = p.x + p.y*50.0;
	return mix( mix( randomNum(n+0.0), randomNum(n+1.0), f.x), mix(randomNum(n+50.0), randomNum(n+51.0), f.x), f.y);
}

float SmokeParticle(vec2 loc, vec2 pos, float size, float rnd, float time) { //
	loc = loc - pos;
	float d = dot(loc, loc) / size;
	if (d > 1.0) return 0.0;

	float r = time * rnd * 1.85;
	float si = sin(r);
	float co = cos(r);

	mat2 rotm = mat2(vec2(co, si), vec2(-si, co));
	vec2 rot = rotm * loc.xy;

	float n = noise(randomNum(rnd*828.0)*83.1 + rot * 2.0 / max(pos.y * 0.16, 0.05));
	d = n * pow(1.0 - d, 3.0) * 0.7;

	return d;
}

void fragment() {
	float time = TIME + 1.0;

	vec2 uv = UV * 2.0 - 1.0;

	uv += vec2(0.1, 1.1);
	vec3 col = vec3(0.0);
	float alpha = 0.0;

	for (int i = 0; i < 140; i++) {
		if (i >= smoke_count) break;

		float fi = float(i);

		float t  = time + fi * (2.0 + randomNum(fi * -1234.5));
		float sm = mod(t, 8.6) * 0.5;
		float rnd = floor(t / 8.6);

		vec2 pos = vec2(0.0, sm) * 0.5;
		pos.x += (randomNum(fi) - 0.5) * 0.2 * uv.y * 5.13;

		float d = SmokeParticle(
			pos, uv,
			0.03 * randomNum(fi * 1332.23 + rnd) + 0.001 + sm * 0.03,
			randomNum(fi * rnd * 2242.13) - 0.5,
			time
		);

		if (d <= 0.0) continue;

		d = d * max((3.0 - (randomNum(fi * 127.0) * 1.5) - sm * 0.63), 0.001);
		float a = clamp(d, 0.0, 1.0);
		alpha = 1.0 - (1.0 - alpha) * (1.0 - a);
		col = mix(col, smoke_color, a);
		col = mix(col, star_color, max((d - 1.05) * 8.0, 0.0));
	}

	float top_fade = 1.0 - smoothstep(top_fade_start, top_fade_end, UV.y);
	float a_out = clamp(alpha * intensity, 0.0, 1.0) * top_fade;

	ALBEDO = col * intensity;
	ALPHA  = a_out;
}
