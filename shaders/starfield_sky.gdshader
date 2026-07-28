shader_type sky;

// Procedural deep-space background: layered stars of varying brightness
// plus soft nebula color bands. Generated entirely from hashed noise so
// no skybox texture asset is required.

uniform vec3 nebula_color_a : source_color = vec3(0.22, 0.10, 0.32);
uniform vec3 nebula_color_b : source_color = vec3(0.06, 0.16, 0.30);
uniform float star_density : hint_range(0.9, 0.999) = 0.987;

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

float fbm(vec3 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * vnoise(p);
		p *= 2.07;
		amp *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;

	// stars: sharp hashed points, several density bands for brightness variety
	vec3 sp = dir * 400.0;
	float starfield = hash13(floor(sp));
	float star = step(star_density, starfield);
	float twinkle = 0.7 + 0.3 * hash13(floor(sp) + 7.0);
	vec3 star_color = vec3(1.0) * star * twinkle;

	vec3 sp2 = dir * 900.0 + 91.0;
	float star2 = step(0.997, hash13(floor(sp2)));
	star_color += vec3(0.8, 0.9, 1.0) * star2;

	// nebula: low-frequency fbm bands tinted and faded
	float neb = fbm(dir * 2.2 + 5.0);
	vec3 nebula = mix(nebula_color_a, nebula_color_b, neb) * smoothstep(0.35, 0.9, neb) * 0.35;

	COLOR = star_color + nebula + vec3(0.01, 0.012, 0.018);
}
