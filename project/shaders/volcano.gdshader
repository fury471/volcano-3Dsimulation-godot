shader_type spatial;
//render_mode unshaded; // No lighting calculations (flat colors)
render_mode cull_back;

// --- Settings: Shape ---
group_uniforms Shape_Settings;
uniform float volcano_height: hint_range(1.0, 50.0) = 22.0;
uniform float base_radius: hint_range(1.0, 50.0) = 14.177;
uniform float crater_radius: hint_range(0.01, 1.0) = 0.268;
uniform float crater_depth: hint_range(0.0, 5.0)  = 0.654;
uniform float slope_steepness: hint_range(1.0, 5.0)  = 1.587; // Controls the curve of the cone
uniform float lava_level: hint_range(0.0, 1.0)  = 0.52;

// --- Settings: Noise (Detail) ---
group_uniforms Noise_Settings;
uniform float noise_amount: hint_range(0.0, 2.0)  = 0.2;
uniform float noise_scale: hint_range(1.0, 20.0) = 6.0;

// --- Settings: Colors ---
group_uniforms Color_Settings;
uniform vec3 color_lava_cool: source_color = vec3(0.25, 0.04, 0.03); // Crust
uniform vec3 color_lava_hot: source_color = vec3(1.2, 0.35, 0.06);  // Magma
uniform vec3 color_rock: source_color = vec3(0.1, 0.1, 0.1);
uniform vec3 color_snow: source_color = vec3(0.9, 0.9, 0.9);
uniform float snow_line: hint_range(0.0, 1.0) = 0.6; // Height % where snow starts

// --- Settings: Phong Shading ---
group_uniforms Phong_Settings;
uniform vec3 ambient_color: source_color = vec3(0.02, 0.02, 0.02);
uniform float ambient_strength: hint_range(0.0, 1.0) = 0.15;
uniform vec3 specular_color: source_color = vec3(1.0);
uniform float specular_strength : hint_range(0.0, 4.0) = 1.0;
uniform float shininess: hint_range(0.0, 256.0) = 1.0;

// --- Settings: Normal Mapping ---
group_uniforms NormalMapping_Settings;
uniform bool use_normal_mapping = true;
uniform sampler2D rocks_normal: hint_normal;
uniform sampler2D snows_normal: hint_normal;
uniform float normal_strength: hint_range(0.0, 2.0) = 0.618;
uniform float normal_uv_scale: hint_range(0.1, 200.0) = 4.0;

// --- Varyings ---
// Used to pass data from Vertex -> Fragment shader
varying float v_local_height_normalized;
varying vec3 v_local_position;
varying vec3 v_local_normal;

// --- Helper Functions: Randomness ---
// Standard pseudo-random hash
float random(float n) {
	return fract(sin(n) * 43758.5453123);
}

// 2D value noise
float value_noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);

	// Cubic smoothing (hermite interpolation) for smoother noise
	f = smoothstep(0.0, 1.0, f);
	float a = random(dot(i, vec2(1.0, 57.0)));
	float b = random(dot(i + vec2(1.0, 0.0), vec2(1.0, 57.0)));
	float c = random(dot(i + vec2(0.0, 1.0), vec2(1.0, 57.0)));
	float d = random(dot(i + vec2(1.0, 1.0), vec2(1.0, 57.0)));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion (FBM) - noise for detail
float fbm(vec2 uv) {
	float total_value = 0.0;
	float amplitude = 0.5;
	float lambda = 2.0;
	float omega = 0.5;

	// Layer the noise 4 times
	for (int i = 0; i < 4; i++) {
		total_value += amplitude * value_noise(uv);
		uv *= lambda;		// Increase frequency (detail)
		amplitude *= omega;	// Decrease strength
	}
	return total_value;
}

// --- Main Logic: Height Calculation ---
float calculate_volcano_height(vec2 pos_normalized) {
	// 1. Calculate distance from center (0.0 to 1.0)
	float dist_from_center = length(pos_normalized);

	// 2. Invert distance so center is 1.0 and edge is 0.0
	float base_shape = clamp(1.0 - dist_from_center, 0.0, 1.0);

	// 3. Apply power function to curve the sides (make it cone-like)
	float cone_shape = pow(base_shape, slope_steepness);

	// 4. Create the Crater
	// smoothstep creates a value from 0 to 1 based on radius
	float crater_factor = smoothstep(0.0, crater_radius, dist_from_center);
	// Invert logic: We want to subtract height inside the crater
	float crater_cutout = (1.0 - crater_factor) * crater_depth;

	float final_shape = cone_shape - crater_cutout;

	// 5. Apply Noise (Erosion)
	float erosion = fbm(pos_normalized * noise_scale) * 2.0 - 1.0;
	final_shape += noise_amount * erosion;

	return final_shape * volcano_height;
}

// --- Normal calculation ---
vec3 calculate_normal(vec3 pos_normalized) {
	// Numerical approximation of normal using small offsets
	float delta = 0.01;
	float hx0 = calculate_volcano_height((pos_normalized.xz - vec2(delta, 0.0)));
	float hx1 = calculate_volcano_height((pos_normalized.xz + vec2(delta, 0.0)));
	float hz0 = calculate_volcano_height((pos_normalized.xz - vec2(0.0, delta)));
	float hz1 = calculate_volcano_height((pos_normalized.xz + vec2(0.0, delta)));
	vec3 dx = vec3(1.0, (hx1 - hx0)/(2.0 * delta), 0.0);
	vec3 dz = vec3(0.0, (hz1 - hz0)/(2.0 * delta), 1.0);
	vec3 local_normal = normalize(cross(dz, dx));
	if (local_normal.y < 0.0) {
		local_normal = -local_normal;
	}

	return local_normal;
}

// --- Lava mask calculation ---
float calculate_lava_mask(vec2 pos_normalized, float height_normalized) {
	float dist_from_center = length(pos_normalized);
	// 1 inside crater, 0 outside
	float crater_mask = 1.0 - smoothstep(crater_radius * 0.9, crater_radius * 0.95, dist_from_center);
	float below_level = 1.0 - smoothstep(lava_level - 0.02, lava_level + 0.02, height_normalized);
	return crater_mask * below_level;
}

// --- Faking Lava flow veins ---
float lava_flow_veins(vec2 pos_normalized){
	float lava_noise_scale = 1.618;
	float distortion_level = 0.01;
	float flow_speed = 0.05;

	vec2 uv = pos_normalized * lava_noise_scale;
    uv += vec2(TIME * flow_speed, TIME * flow_speed);
    float warp_noise = fbm(uv);
	uv += (warp_noise * 2.0 - 1.0) * distortion_level;
	uv += vec2(TIME * flow_speed, 0.0);
	float final_noise = fbm(uv * 6.18);
    float veins = smoothstep(0.2, 0.8, final_noise); // 0..1, bright streaks

    return veins;
}

// --- Calculate Tangent, Binormal, Normal ---
void calculate_tbn(vec3 normal, out vec3 tangent, out vec3 binormal) {
	vec3 up = abs(normal.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	// gram-schmidt orthogonalization
	tangent = normalize(up - normal * dot(up, normal));
	binormal = normalize(cross(normal, tangent));
}

void vertex() {
	v_local_position = VERTEX;
	// Calculate and set normal
	v_local_normal = calculate_normal(v_local_position / base_radius);
	NORMAL = v_local_normal;

	// Normalize world coordinates to roughly [-1, 1] range based on base_radius
	vec2 pos_xz_normalized = VERTEX.xz / base_radius;

	// Calculate and apply height
	float h = calculate_volcano_height(pos_xz_normalized);
	VERTEX.y = h;
	v_local_position.y = h;

	// Pass the normalized height (0.0 to 1.0) to the fragment shader
	// We use clamp to ensure colors don't glitch if noise pushes it slightly out of bounds
	v_local_height_normalized = clamp(h/volcano_height, 0.0, 1.0);

	// Compute normal, binormal and tangent
	vec3 local_t, local_b;
	calculate_tbn(v_local_normal, local_t, local_b);
	TANGENT = local_t;
	BINORMAL = local_b;
}

void fragment() {
	// Base Gradient: Mix Rock and Snow based on height
	float snow_blend_factor = smoothstep(snow_line - 0.1, snow_line + 0.1, v_local_height_normalized);
	vec2 pos_normalized = v_local_position.xz / base_radius;
	vec3 base_color = mix(color_rock, color_snow, snow_blend_factor);

	// Lava Mask: inside crater and below lava level
	float lava_mask = calculate_lava_mask(pos_normalized, v_local_height_normalized);

	// Faking Lava flow (animated)
	// Color variation: darker crust + brighter hot veins
	float veins = lava_flow_veins(pos_normalized);
	vec3 lava_color = mix(color_lava_cool, color_lava_hot, veins);

	vec3 final_color = mix(base_color, lava_color, lava_mask);

	ALBEDO = final_color;
	EMISSION = lava_color * lava_mask * veins * 6.18;

	// Planar uv from local xz
	vec2 uv = pos_normalized * normal_uv_scale;
	vec2 offset_uv = uv + 0.1 * vec2(value_noise(uv), value_noise(uv));
	// --- Normal Mapping ---
	if (use_normal_mapping) {
		vec3 n_rock = texture(rocks_normal, uv).xyz * 2.0 - 1.0;
		vec3 n_rock_offset = texture(rocks_normal, offset_uv).xyz * 2.0 - 1.0;
		vec3 n_snow = texture(snows_normal, uv).xyz * 2.0 - 1.0;
		vec3 n_snow_offset = texture(snows_normal, offset_uv).xyz * 2.0 - 1.0;
		n_rock = mix(n_rock, n_rock_offset, value_noise(uv));
		n_snow = mix(n_snow, n_snow_offset, value_noise(uv));
		// Blend normals in tangent space, then normalize
		vec3 n = normalize(mix(n_rock, n_snow, snow_blend_factor));
		// Blend toward flat normal(0, 0, 1)
		n = normalize(mix(vec3(0.0, 0.0, 1.0), n, normal_strength));

		NORMAL_MAP = n;
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
    float spec_factor = pow(RdotV, shininess) * specular_strength * 0.1;

    DIFFUSE_LIGHT += diffuse * LIGHT_COLOR * ATTENUATION;
    SPECULAR_LIGHT += specular_color * spec_factor * LIGHT_COLOR * ATTENUATION;

	
}
