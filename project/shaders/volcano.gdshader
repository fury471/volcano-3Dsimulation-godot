shader_type spatial;
render_mode unshaded; // No lighting calculations (flat colors)

// --- Settings: Shape ---
group_uniforms Shape_Settings;
uniform float volcano_height : hint_range(1.0, 50.0) = 14.0;
uniform float base_radius    : hint_range(1.0, 50.0) = 11.0;
uniform float crater_radius  : hint_range(0.01, 1.0) = 0.15;
uniform float crater_depth   : hint_range(0.0, 5.0)  = 0.25;
uniform float slope_steepness: hint_range(1.0, 5.0)  = 2.0; // Controls the curve of the cone
uniform float lava_level     : hint_range(0.0, 1.0)  = 0.6;

// --- Settings: Noise (Detail) ---
group_uniforms Noise_Settings;
uniform float noise_amount   : hint_range(0.0, 2.0)  = 0.2;
uniform float noise_scale    : hint_range(1.0, 20.0) = 6.0;

// --- Settings: Colors ---
group_uniforms Color_Settings;
uniform vec3 color_lava : source_color = vec3(0.6, 0.1, 0.1);
uniform vec3 color_rock : source_color = vec3(0.1, 0.1, 0.1);
uniform vec3 color_snow : source_color = vec3(0.9, 0.9, 0.9);
uniform float snow_line : hint_range(0.0, 1.0) = 0.6; // Height % where snow starts

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

// 2D Value Noise
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

// --- Normal Calculation ---
vec3 calculate_normal(vec3 pos_normalized) {
	// Numerical approximation of normal using small offsets
	float delta = 0.01;
	float hx0 = calculate_volcano_height((pos_normalized.xz - vec2(delta, 0.0)));
	float hx1 = calculate_volcano_height((pos_normalized.xz + vec2(delta, 0.0)));
	float hz0 = calculate_volcano_height((pos_normalized.xz - vec2(0.0, delta)));
	float hz1 = calculate_volcano_height((pos_normalized.xz + vec2(0.0, delta)));
	vec3 local_normal = normalize(vec3(hx1 - hx0, 2.0 * delta, hz1 - hz0));

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

// --- Faking lava flow veins ---
vec3 lava_flow_veins(vec2 pos_normalized){
	vec2 uv = pos_normalized * 27.0; // scale controls vein size
    uv += vec2(TIME, TIME);
    float noise = fbm(uv);
    float veins = smoothstep(0.2, 0.8, noise); // 0..1, bright streaks

    // Color variation: darker crust + brighter hot veins
    vec3 lava_cool = color_lava * 0.4;
    vec3 lava_hot  = color_lava * 1.5;
    return mix(lava_cool, lava_hot, veins);
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
	v_local_height_normalized = clamp(h / volcano_height, 0.0, 1.0);

}

void fragment() {
	// Base Gradient: Mix Rock and Snow based on height
	vec3 base_color = mix(color_rock, color_snow, smoothstep(snow_line - 0.1, snow_line + 0.1, v_local_height_normalized));

	// Lava Mask: inside crater and below lava level
	float lava_mask = calculate_lava_mask(v_local_position.xz / base_radius, v_local_height_normalized);

	// Faking Lava flow (animated)
	vec3 lava_color = lava_flow_veins(v_local_position.xz / base_radius);

	vec3 final_color = mix(base_color, lava_color, lava_mask);

	ALBEDO = final_color;
}


//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
