shader_type spatial;
// Ground and road: vertex colour broken up by world-space noise at two scales, so the ground
// stays crisp up close (grit, pebbles, cracks) without any texture files. CUSTOM0.x (stored in
// UV.x) is how much of the road a vertex is: roads get cobble cells, the rest gets grass blades.

uniform float detail = 1.0;
uniform float cobble = 1.0;
uniform vec3 cobble_dark : source_color = vec3(0.2, 0.18, 0.16);

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// distance to the nearest cell edge of a jittered grid: dark seams between stones
float cells(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + 17.0)) * 0.8 + 0.1;
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = COLOR.rgb;
	float road = UV.x;
	float n1 = noise(wpos.xz * 1.7);
	float n2 = noise(wpos.xz * 7.0);
	float n3 = noise(wpos.xz * 23.0);
	float grain = (n1 - 0.5) * 0.22 + (n2 - 0.5) * 0.18 + (n3 - 0.5) * 0.14;
	c *= 1.0 + grain * detail;
	if (road > 0.02 && cobble > 0.0) {
		float e = cells(wpos.xz * 1.6);
		float seam = 1.0 - smoothstep(0.02, 0.12, e);
		c = mix(c, cobble_dark, seam * road * cobble * 0.75);
		c *= 1.0 + (hash(floor(wpos.xz * 1.6)) - 0.5) * 0.18 * road * cobble;
	}
	ALBEDO = c;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
}
