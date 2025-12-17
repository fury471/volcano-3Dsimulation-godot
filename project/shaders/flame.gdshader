shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform bool use_emission = false;

uniform float intensity = 4.0;
uniform float core_tightness = 3.5;
uniform float base_falloff = 1.7;

uniform float noise_scale = 10.0;
uniform float noise_speed = 4.0;

uniform vec3 col_core = vec3(1.0, 0.55, 0.20); // 核心
uniform vec3 col_red = vec3(0.95, 0.12, 0.05); // 主体
uniform vec3 col_dark = vec3(0.20, 0.02, 0.02); // 边缘

varying vec3 v_world_pos;

float randomNum(float n) { //随机数生成函数
	return fract(sin(n) * 98765.4321);
}

float noise(vec2 x) { //噪声生成函数
	vec2 p = floor(x);
	vec2 f = fract(x);
	float n = p.x + p.y * 50.0;
	return mix( mix( randomNum(n+0.0), randomNum(n+1.0), f.x), mix(randomNum(n+50.0), randomNum(n+51.0), f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return s;
}

void vertex() {
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float y = UV.y;

	float fr = exp(-abs(x) * core_tightness);
	float fh = pow(1.0 - y, base_falloff);

	vec2 np = vec2(x * noise_scale, y * noise_scale - TIME * noise_speed);
	float n = fbm(np);
	n = n * n;

	float g = fr * fh * (0.20 + 1.60 * n);
	g *= (1.0 - y*y);

	float heat = fr * (1.0 - y);

	heat = pow(clamp(heat, 0.0, 1.0), 2.2);
	vec3 c = mix(col_dark, col_red, clamp(g * 1.2, 0.0, 1.0));
	c = mix(c, col_core, heat);

	vec3 out_col = c * g * intensity;

	float hidden_factor = 1.0;

	if (v_world_pos.y < 0.0){
		discard;
	}

	ALBEDO = out_col;
	ALPHA =  hidden_factor * clamp(g * intensity, 0.0, 1.0);
}
