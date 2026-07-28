shader_type spatial;
render_mode blend_add, cull_front, depth_draw_never, unshaded, shadows_disabled;

// Atmospheric rim glow: rendered on a sphere ~3% larger than Earth with
// front-face culling, so only the limb (edge) is visible from outside —
// the classic "atmospheric scattering" trick used in space-visualization
// tools without a full physical scattering model.

uniform vec3 atmosphere_color : source_color = vec3(0.30, 0.55, 1.0);
uniform vec3 sun_direction = vec3(1.0, 0.15, 0.3);
uniform float intensity : hint_range(0.0, 5.0) = 1.8;
uniform float rim_power : hint_range(0.5, 8.0) = 2.6;

varying vec3 world_normal;
varying vec3 view_dir;

void vertex() {
	world_normal = NORMAL;
	view_dir = normalize((VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 v = normalize(view_dir);
	float fresnel = pow(1.0 - clamp(abs(dot(n, v)), 0.0, 1.0), rim_power);

	vec3 sun_dir = normalize(sun_direction);
	float sun_side = smoothstep(-0.5, 1.0, dot(n, sun_dir));

	ALBEDO = atmosphere_color;
	EMISSION = atmosphere_color * fresnel * intensity * mix(0.25, 1.0, sun_side);
	ALPHA = fresnel;
}
