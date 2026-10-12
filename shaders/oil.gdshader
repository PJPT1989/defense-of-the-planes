shader_type spatial;
// Glistening oil: pools, drips and Realmbreaker sap. Black with a slow iridescent sheen.
render_mode cull_disabled;

uniform vec3 tint : source_color = vec3(0.02, 0.02, 0.03);
uniform float sheen = 0.7;

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.0);
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * 0.4 + wp.x * 0.35 + wp.z * 0.25;
	vec3 rainbow = 0.5 + 0.5 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + t));
	ALBEDO = tint * COLOR.rgb;
	ROUGHNESS = 0.05;
	METALLIC = 0.6;
	SPECULAR = 1.0;
	EMISSION = rainbow * (0.08 + fres * 0.35) * sheen;
	ALPHA = COLOR.a;
}
