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

float fbm(vec2 p) { //fbm分型叠加噪声，更自然一些
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

	float horizontal_fade = exp(-abs(x) * core_tightness); //水平方向密度，越向边越淡
	float vertical_fade = pow(1.0 - y, base_falloff); //竖直方向密度，越高越淡

	vec2 np = vec2(x * noise_scale, y * noise_scale - TIME * noise_speed);
	float n = fbm(np);
	n = n * n;

	float flame_density = horizontal_fade * vertical_fade * (0.20 + 1.60 * n);
	flame_density *= (1.0 - y*y);

	float heat = horizontal_fade * (1.0 - y);

	heat = pow(clamp(heat, 0.0, 1.0), 2.0);
	vec3 base_color = mix(col_dark, col_red, clamp(flame_density * 1.2, 0.0, 1.0));
	base_color = mix(base_color, col_core, heat);

	vec3 final_color = base_color * flame_density * intensity;

	float hidden_factor = 1.0;

	if (v_world_pos.y < 0.0){
		discard;
	}

	ALBEDO = final_color;
	ALPHA =  hidden_factor * clamp(flame_density * intensity, 0.0, 1.0);
}
