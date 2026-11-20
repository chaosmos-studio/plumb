shader_type canvas_item;

// The street's ground, painted from where each pixel lies on the strip (MATH.md section 25). The mesh is already bent
// by StreetProjection on the CPU and never moves: UV.x is the point's distance along the strip from the near edge and
// UV.y its distance across, so scrolling only changes `scroll` here. The sway constants come from StreetPath.

uniform float scroll = 0.0;
uniform float radius = 1200.0;
uniform float sway_a = 115.0;
uniform float sway_a_length = 1730.0;
uniform float sway_b = 40.0;
uniform float sway_b_length = 610.0;
uniform float sway_b_phase = 1.3;
uniform float road_half = 64.0;
uniform vec4 grass_near : source_color = vec4(0.42, 0.74, 0.25, 1.0);
uniform vec4 grass_far : source_color = vec4(0.62, 0.84, 0.38, 1.0);
uniform vec4 grass_stripe : source_color = vec4(0.36, 0.68, 0.22, 1.0);
uniform vec4 road : source_color = vec4(0.96, 0.69, 0.47, 1.0);
uniform vec4 road_joint : source_color = vec4(0.88, 0.56, 0.36, 1.0);
uniform vec4 road_rim : source_color = vec4(0.99, 0.86, 0.66, 1.0);
uniform vec4 haze : source_color = vec4(0.80, 0.92, 0.98, 1.0);
// Cobbles: the length and width of one, in strip pixels.
uniform vec2 cobble = vec2(44.0, 26.0);

float road_x(float s) {
	return sway_a * sin(TAU * s / sway_a_length) + sway_b * sin(TAU * s / sway_b_length + sway_b_phase);
}

void fragment() {
	float s = scroll + UV.x;
	float x = UV.y;
	float t = UV.x / radius;
	float across = x - road_x(s);
	float d = abs(across);
	// A pixel's footprint on the strip, so every edge is antialiased and fine patterns fade before they shimmer.
	float px = max(fwidth(d), 0.001);
	float stripes = 0.5 + 0.5 * sin(TAU * s / 160.0);
	vec3 grass = mix(grass_near.rgb, grass_far.rgb, smoothstep(0.2, 1.4, t));
	grass = mix(grass, grass_stripe.rgb, 0.35 * stripes * (1.0 - smoothstep(4.0, 12.0, px)));
	// A soft shadow on the grass along the road's edge.
	grass *= 1.0 - 0.12 * (1.0 - smoothstep(road_half, road_half + 22.0, d));
	float row = floor(s / cobble.y);
	float along = across + mod(row, 2.0) * cobble.x * 0.5;
	vec2 cell = vec2(fract(along / cobble.x), fract(s / cobble.y));
	vec2 edge = min(cell, 1.0 - cell) * vec2(cobble.x, cobble.y);
	float joint = 1.0 - smoothstep(0.0, 2.2 + px, min(edge.x, edge.y));
	joint *= 1.0 - smoothstep(3.0, 9.0, px);
	vec3 street = mix(road.rgb, road_joint.rgb, joint);
	street = mix(street, road_rim.rgb, smoothstep(road_half - 12.0 - px, road_half - 8.0, d));
	float on_road = 1.0 - smoothstep(road_half - px, road_half + px, d);
	vec3 colour = mix(grass, street, on_road);
	colour = mix(colour, haze.rgb, 0.55 * smoothstep(1.05, 1.57, t));
	COLOR = vec4(colour, 1.0);
}
