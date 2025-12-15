shader_type spatial;
// render_mode unshaded;
render_mode cull_back;

// --- Settings: Shape ---
group_uniforms Shape_Settings;
uniform float pool_radius: hint_range(1.0, 50.0) = 2.74;
uniform float edge_softness: hint_range(0.0, 1.0)  = 0.618;// Percentage of radius to fade out

// --- Settings: Noise & Flow ---
group_uniforms Noise_Settings;
uniform float noise_scale: hint_range(0.1, 10.0) = 1.618;
uniform float flow_speed: hint_range(0.0, 2.0)  = 0.35;
uniform float distortion_level: hint_range(0.0, 2.0)  = 0.05;// How much the UVs warp

// --- Settings: Colors ---
group_uniforms Color_Settings;
uniform vec3 color_lava_cool: source_color = vec3(0.25, 0.04, 0.03);// Crust
uniform vec3 color_lava_hot: source_color = vec3(1.2, 0.35, 0.06);// Magma
uniform float emission_energy: hint_range(0.0, 16.0) = 6.0;

// --- Settings: Phong Shading ---
group_uniforms Phong_Settings;
uniform vec3 ambient_color: source_color = vec3(0.02, 0.02, 0.02);
uniform float ambient_strength: hint_range(0.0, 1.0) = 0.15;
uniform vec3 specular_color: source_color = vec3(1.2, 0.35, 0.06);
uniform float specular_strength : hint_range(0.0, 4.0) = 1.0;
uniform float shininess: hint_range(0.0, 256.0) = 1.0;

// --- Settings: Normal Mapping ---
group_uniforms NormalMapping_Settings;
uniform bool use_normal_mapping = true;
uniform sampler2D texture_normal: hint_normal;
uniform float normal_strength: hint_range(0.0, 2.0) = 0.618;
uniform float normal_uv_scale: hint_range(0.1, 10.0) = 0.1;
uniform vec2 normal_scroll_0 = vec2(0.02, 0.015);
uniform vec2 normal_scroll_1 = vec2(0.01, -0.015);

// --- Varyings ---
varying vec3 v_local_position;

// --- Helper Functions: Randomness---
// This part is same as volcano's
float random(float n) {
	return fract(sin(n) * 43758.5453123);
}

float value_noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);

	f = smoothstep(0.0, 1.0, f);
	float a = random(dot(i, vec2(1.0, 57.0)));
	float b = random(dot(i + vec2(1.0, 0.0), vec2(1.0, 57.0)));
	float c = random(dot(i + vec2(0.0, 1.0), vec2(1.0, 57.0)));
	float d = random(dot(i + vec2(1.0, 1.0), vec2(1.0, 57.0)));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 uv) {
	float total_value = 0.0;
	float amplitude = 0.5;
	float lambda = 2.0;
	float omega = 0.5;

	for (int i = 0; i < 4; i++) {
		total_value += amplitude * value_noise(uv);
		uv *= lambda;
		amplitude *= omega;
	}
	return total_value;
}

// --- Main Logic: Lava Veins ---
float calculate_lava_veins(vec2 pos_xz) {
	// 1. Base uv scaling
	vec2 uv = pos_xz * noise_scale;

	// 2. Domain warping (distortion)
	// Offset the uv by another noise layer moving in a different direction
	vec2 flow_offset = vec2(TIME * flow_speed, TIME * flow_speed);
	float warp_noise = fbm(uv + flow_offset);

	// Apply the warp
	uv += (warp_noise * 2.0 - 1.0) * distortion_level;

	// 3. Main flow movement
	uv += vec2(TIME * flow_speed, 0.0);

	// 4. Calculate final noise pattern
	float final_noise = fbm(uv * 3.09);
	
	float veins = smoothstep(0.2, 0.8, final_noise); // 0..1, bright streaks

	return veins;
}

// --- Lava Waves ---
struct WaveSample {
	float height;
	vec2 gradxz;
};

WaveSample wave(vec2 pos_xz, vec2 direction, float amplitude, float frequency, float phase, float sharpness) {
	float params= (pos_xz.x * direction.x + pos_xz.y * direction.y) * frequency + phase * TIME;
	float alpha = sin(params) * 0.5 + 0.5;
	WaveSample wave;
	wave.height = amplitude * pow(alpha, sharpness);
	float gradx = 0.5 * sharpness * frequency * amplitude * pow(alpha, sharpness - 1.0) * cos(params) * direction.x;
	float gradz = 0.5 * sharpness * frequency * amplitude * pow(alpha, sharpness - 1.0) * cos(params) * direction.y;
	wave.gradxz = vec2(gradx, gradz);
	
	return wave;
}

// --- Normal Mapping Helper ---
vec3 sample_lava_normal(vec2 uv) {
    vec2 scaled_uv = uv * normal_uv_scale;
    vec2 uv0 = scaled_uv + normal_scroll_0 * TIME;
    vec2 uv1 = scaled_uv * 2.0 + normal_scroll_1 * 2.0 * TIME;
    vec3 n0 = texture(texture_normal, uv0).xyz * 2.0 - 1.0;
    vec3 n1 = texture(texture_normal, uv1).xyz * 2.0 - 1.0;

    // blend toward flat normal(0, 0, 1), it is in tangent space!!
    vec3 n = normalize(n0 + n1);
    n = normalize(mix(vec3(0.0, 0.0, 1.0), n, normal_strength));

    return n;
}

void vertex() {
	WaveSample w1 = wave(VERTEX.xz, vec2(-1.54, 2.0), 0.309, 0.618, 0.3, 1.618);
	WaveSample w2 = wave(VERTEX.xz, vec2(3.0, -2.0), 0.309, 0.618, 1.0, 1.618);
	VERTEX.y += w1.height;
	VERTEX.y += w2.height;
	
	v_local_position = VERTEX;
	// Compute normal, binormal and tangent
	vec2 sum_gradxz = w1.gradxz + w2.gradxz;
	vec3 local_n = normalize(vec3(-sum_gradxz.x, 1, -sum_gradxz.y));
	vec3 local_t = normalize(vec3(1, sum_gradxz.x, 0));
	vec3 local_b = normalize(cross(local_n, local_t));
	
	TANGENT = local_t;
	BINORMAL = local_b;
	NORMAL = local_n;
}

void fragment() {
	// --- Lava veins and color ---
	// 1. Calculate distance mask
	float dist = length(v_local_position.xz);
	// Calculate smooth fade at the edge
	float edge_start = pool_radius * (1.0 - edge_softness);
	float rim_mask = 1.0 - smoothstep(edge_start, pool_radius, dist);

	// 2. Generate flow pattern
	float veins = calculate_lava_veins(v_local_position.xz);

	// 3. Mix colors
	vec3 final_color = mix(color_lava_cool, color_lava_hot, veins);

	// 4. Output
	// Multiply albedo by rim_mask to control the fadeoff effect of the edge
	ALBEDO = final_color * rim_mask;

	// Emission glows only on the hot veins and fades at the rim
	EMISSION = final_color * emission_energy * veins * rim_mask;
	
	// Made the pool to fade out
	ALPHA = rim_mask;

    // --- Normal Mapping ---
    if (use_normal_mapping) {
        vec3 lava_normal = sample_lava_normal(v_local_position.xz);
        NORMAL_MAP = lava_normal;
    }

    // --- Phong Shading ---
    EMISSION += ambient_color * ambient_strength;
}

void light() {
    vec3 N = normalize(NORMAL);
    vec3 L = normalize(LIGHT);
    vec3 V = normalize(VIEW);

    // Diffuse
    float NdotL = max(dot(N, L), 0.0);
    vec3 diffuse = ALBEDO * NdotL;

    // Specular
    vec3 R = reflect(-L, N);
    float RdotV = max(dot(R, V), 0.0);
    float spec_factor = pow(RdotV, shininess) * specular_strength;

    DIFFUSE_LIGHT += diffuse * LIGHT_COLOR * ATTENUATION;
    SPECULAR_LIGHT += specular_color * spec_factor * LIGHT_COLOR * ATTENUATION;

}