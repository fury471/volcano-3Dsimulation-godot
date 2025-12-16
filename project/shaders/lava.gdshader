shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform float intensity = 8.0;
uniform float lava_count_f = 24.0;

uniform float cycle = 3.0;                 
uniform float gravity = 0.6;   
uniform float speed_y = 1.0;   
uniform float speed_x = 1.0;

uniform float sim_scale = 0.35; //把抛物线缩进UV范围

uniform vec3 hot_color = vec3(1.0, 0.45, 0.08);
uniform vec3 cool_color = vec3(0.25, 0.05, 0.02);

float randomNum(float n) { //随机数生成函数
	return fract(sin(n) * 98765.4321); 
}

float soft_blob(vec2 p, float r) {
	float d = length(p) / max(r, 0.001);
	return exp(-d*d * 4.0);
}

void fragment() {
	float time = TIME;
	vec2 uv = UV * 2.0 - 1.0;
	uv += vec2(0.0, 0.7); 
	
	vec3 col = vec3(0.0);
	float alpha = 0.0;
	
	for (int i = 0; i < 80; i++) {
		if (i >= int(lava_count_f)) break;
		
		float fi = float(i);
		float tm = mod(time + 0.15 * (fi + 0.6 * randomNum(fi)), cycle);
		
		float rnd0 = randomNum(100.11 * fi);
		float ang = 2.0 * PI * rnd0;
		
		vec2 v0_xz = 0.7 * vec2(cos(ang), sin(ang)) * speed_x;
		float v0_y = (1.4 + 0.3 * randomNum(11.11 * fi)) * speed_y;
		
		vec2 p0 = 0.1 * v0_xz;
		float y0 = 0.0;
		
		vec2 pos;
		pos.x = p0.x + v0_xz.x * tm;
		pos.y = y0 + v0_y * tm - gravity * tm * tm;// 抛物线
		pos *= sim_scale;
		
		vec2 p = uv - pos;
		float life = tm / max(cycle, 0.001);
		float r = mix(0.09, 0.03, life) * (0.7 + 0.6 * randomNum(fi * 33.3));
		float b = soft_blob(p, r);
		
		if (b < 0.002) continue;
		
		vec3 c = mix(hot_color, cool_color, pow(life, 1.2));
		col += c * b * intensity;
		alpha = max(alpha, b);
	}
	ALBEDO = col;
	ALPHA  = clamp(alpha, 0.0, 1.0);
}
