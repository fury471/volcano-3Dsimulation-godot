shader_type spatial;

uniform float cone_height = 3.0;
uniform float cone_radius = 4.0;
uniform float cone_steepness = 2.0; // 圆锥陡峭度，>1 越上越陡

uniform float crater_depth = 1.0;
uniform float crater_radius = 1.0;

uniform sampler2D noise_tex;
uniform float noise_scale = 1.0; 
uniform float noise_strength = 0.3;
uniform float terrain_radius = 15.0; // 噪声影响的最大半径，超出就变平

float volcano_height(vec3 pos){ //高度函数，用来建模火山圆锥和火山口，同时计算一点的高度值
	float r = length(pos.xz); //一个点到(0,0)的距离，用作r
	float h = 0.0;
	
	if (r<cone_radius){	 // 圆锥半径以内的地方抬起
		float t = 1.0 - smoothstep(0.0, cone_radius, r);  // r越小，离中心越近，t越接近1，同时加smooth过度
		t = clamp(t, 0.0, 1.0);
		float t_cone = pow(t, cone_steepness);
		h = t_cone * cone_height;		
		
		if (r<crater_radius){  //火山口
			float t_crater = 1.0 - r/crater_radius;
			t_crater = clamp(t_crater, 0.0, 1.0);
			float crater_h = -t_crater * crater_depth;
			
			h =  h + crater_h;
		}
	}	
	return h;
}

float get_noise_height(vec3 pos){ 
	
	float h = volcano_height(pos);	
	float r = length(pos.xz);
	float noise_factor = 1.0 - clamp(r / terrain_radius, 0.0, 1.0); // 噪声强度因子,中心 = 1，半径 >= terrain_radius 时 = 0，线性减弱
	
	vec2 noise_uv = pos.xz * noise_scale; //用噪声生成复杂地形
	float n = texture(noise_tex, noise_uv).r; //查表生成一个0到1的数字
	n = n * 2.0 - 1.0; //映射到-1 1 满足上下起伏
	
	h = h + n * noise_strength * noise_factor;
	return h;
}

void vertex() {
	// Called for every vertex the material is visible on.
	vec3 base_pos = VERTEX;
    float h = get_noise_height(base_pos);

	vec3 pos = base_pos;	
	pos.y = h + pos.y;	
	
	float eps = 0.1; //计算某个点周围四个点高度值
	float heightL = get_noise_height(base_pos + vec3(-eps, 0.0, 0.0));
	float heightR = get_noise_height(base_pos + vec3( eps, 0.0, 0.0));
	float heightD = get_noise_height(base_pos + vec3(0.0, 0.0, -eps));
	float heightU = get_noise_height(base_pos + vec3(0.0, 0.0,  eps));
	
	// 用四个高度值构造附近的四个点的确切位置
	vec3 pointL = vec3(base_pos.x - eps, heightL, base_pos.z); // 左 
	vec3 pointR = vec3(base_pos.x + eps, heightR, base_pos.z); // 右
	vec3 pointD = vec3(base_pos.x, heightD, base_pos.z - eps); // 后 -z
	vec3 pointU = vec3(base_pos.x, heightU, base_pos.z + eps); // 前 +z
	
	vec3 tangent = pointR - pointL; //x方向切线
	vec3 binormal = pointU - pointD; //z方向切线,副切线
	vec3 normal = normalize(cross(binormal, tangent)); //算出法线
	
	NORMAL = normal;
	
	VERTEX = pos;
}

void fragment() {
	// Called for every pixel the material is visible on.
	ALBEDO = vec3(1.0, 1.0, 1.0);
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
