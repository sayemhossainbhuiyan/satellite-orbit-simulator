shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Procedurally shaded Earth: land/ocean mask, cloud layer, specular ocean
// glint, and a day/night terminator with city-light emission on the dark
// side. No texture assets are sampled — everything is generated from
// layered value noise so the project has zero external binary
// dependencies and looks correct at any resolution.

uniform vec3 ocean_color : source_color = vec3(0.043, 0.161, 0.31);
uniform vec3 ocean_deep : source_color = vec3(0.02, 0.075, 0.165);
uniform vec3 land_color : source_color = vec3(0.16, 0.32, 0.19);
uniform vec3 land_color_alt : source_color = vec3(0.30, 0.40, 0.22);
uniform vec3 mountain_color : source_color = vec3(0.42, 0.38, 0.32);
uniform vec3 ice_color : source_color = vec3(0.85, 0.90, 0.93);
uniform vec3 city_light_color : source_color = vec3(1.0, 0.83, 0.47);
uniform vec3 sun_direction = vec3(1.0, 0.15, 0.3);

uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.46;
uniform float cloud_speed : hint_range(0.0, 0.05) = 0.006;
uniform float time_offset = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

// --- hash / value noise ------------------------------------------------
float hash13(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i + vec3(0,0,0));
	float n100 = hash13(i + vec3(1,0,0));
	float n010 = hash13(i + vec3(0,1,0));
	float n110 = hash13(i + vec3(1,1,0));
	float n001 = hash13(i + vec3(0,0,1));
	float n101 = hash13(i + vec3(1,0,1));
	float n011 = hash13(i + vec3(0,1,1));
	float n111 = hash13(i + vec3(1,1,1));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);
	return mix(nxy0, nxy1, f.z);
}

float fbm(vec3 p, int octaves) {
	float v = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < octaves; i++) {
		v += amp * vnoise(p * freq);
		amp *= 0.5;
		freq *= 2.05;
	}
	return v;
}

void vertex() {
	world_pos = VERTEX;
	world_normal = NORMAL;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 p = n * 3.2;

	// --- continents mask ---
	float continent = fbm(p, 5);
	float detail = fbm(p * 4.3 + 11.0, 4);
	float landmask = smoothstep(0.52, 0.58, continent * 0.75 + detail * 0.25);

	// polar ice caps by latitude
	float lat = abs(n.y);
	float ice = smoothstep(0.82, 0.94, lat);

	vec3 ocean = mix(ocean_deep, ocean_color, smoothstep(0.0, 0.6, continent));
	float mountains = smoothstep(0.66, 0.85, continent);
	vec3 land = mix(land_color, land_color_alt, detail);
	land = mix(land, mountain_color, mountains);

	vec3 surface = mix(ocean, land, landmask);
	surface = mix(surface, ice_color, ice * (0.5 + 0.5 * landmask));

	// --- clouds ---
	vec3 cp = p * 1.7 + vec3(TIME * cloud_speed + time_offset, 0.0, TIME * cloud_speed * 0.6);
	float clouds = fbm(cp, 5);
	clouds = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + 0.22, clouds);

	// --- day / night terminator ---
	vec3 sun_dir = normalize(sun_direction);
	float ndotl = dot(n, sun_dir);
	float day_amount = smoothstep(-0.08, 0.08, ndotl);

	vec3 night_lights = city_light_color * step(0.5, landmask) * smoothstep(0.62, 0.95, hash13(floor(p * 40.0))) * (1.0 - day_amount);

	vec3 lit_surface = mix(surface * 0.05 + night_lights * 1.4, surface, day_amount);
	vec3 lit_clouds = mix(vec3(0.02), vec3(0.92), day_amount);

	vec3 final_color = mix(lit_surface, lit_clouds, clouds * (0.55 + 0.35 * day_amount));

	ALBEDO = final_color;
	EMISSION = night_lights * (1.0 - day_amount) * 1.6;
	ROUGHNESS = mix(0.15, 0.92, landmask);
	SPECULAR = mix(0.9, 0.05, landmask);
}
