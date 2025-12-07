shader_type spatial;
render_mode unshaded; // No lighting calculations (flat colors)

// --- Settings: Shape ---
group_uniforms Shape_Settings;
uniform float volcano_height : hint_range(1.0, 50.0) = 14.0;
uniform float base_radius    : hint_range(1.0, 50.0) = 11.0;
uniform float crater_radius  : hint_range(0.01, 1.0) = 0.15;
uniform float crater_depth   : hint_range(0.0, 5.0)  = 0.15;
uniform float slope_steepness: hint_range(1.0, 5.0)  = 2.0; // Controls the curve of the cone

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
	f = f * f * (3.0 - 2.0 * f);

	float a = random(dot(i, vec2(1.0, 57.0)));
	float b = random(dot(i + vec2(1.0, 0.0), vec2(1.0, 57.0)));
	float c = random(dot(i + vec2(0.0, 1.0), vec2(1.0, 57.0)));
	float d = random(dot(i + vec2(1.0, 1.0), vec2(1.0, 57.0)));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion (FBM) - Layers noise for detail
float fbm(vec2 uv) {
	float total_value = 0.0;
	float amplitude = 0.5;

	// Layer the noise 4 times
	for (int i = 0; i < 4; i++) {
		total_value += amplitude * value_noise(uv);
		uv *= 2.3;      // Increase frequency (detail)
		amplitude *= 0.5; // Decrease strength
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
	float erosion = fbm(pos_normalized * noise_scale) - 0.5;
	final_shape += noise_amount * erosion;

	return final_shape * volcano_height;
}

void vertex() {
	// Normalize world coordinates to roughly [-1, 1] range based on base_radius
	vec2 pos_xz_normalized = VERTEX.xz / base_radius;

	// Calculate and apply height
	float h = calculate_volcano_height(pos_xz_normalized);
	VERTEX.y = h;

	// Pass the normalized height (0.0 to 1.0) to the fragment shader
	// We use clamp to ensure colors don't glitch if noise pushes it slightly out of bounds
	v_local_height_normalized = clamp(h / volcano_height, 0.0, 1.0);
}

void fragment() {
	// --- Coloring Logic ---

	// 1. Base Gradient: Mix Rock and Snow based on height
	vec3 base_color = mix(color_rock, color_snow, smoothstep(snow_line - 0.1, snow_line + 0.1, v_local_height_normalized));

	// 2. Lava Center: If we are very low (crater bottom), show lava
	// We check if height is very low (crater is usually the lowest point aside from the base)
	// Note: This assumes the crater digs deep enough to be distinct.
	float lava_factor = 1.0 - smoothstep(0.0, 0.1, v_local_height_normalized);
	vec3 final_color = mix(base_color, color_lava, lava_factor);

	ALBEDO = final_color;
}


//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
