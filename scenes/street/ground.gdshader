shader_type canvas_item;

// The street's ground, painted from where each pixel lies on the strip (MATH.md section 25). The mesh is already bent
// by StreetProjection on the CPU and never moves: UV.x is the point's distance along the strip from the near edge and
// UV.y its distance across, so scrolling only changes `scroll` here. The sway constants come from StreetPath, and the
// grass and road are Codex's tiles (art/street/), repeated over the strip.

uniform float scroll = 0.0;
uniform float radius = 1150.0;
uniform float sway_a = 115.0;
uniform float sway_a_length = 1730.0;
uniform float sway_a_phase = 0.0;
uniform float sway_b = 40.0;
uniform float sway_b_length = 610.0;
uniform float sway_b_phase = 1.3;
uniform float road_half = 64.0;
uniform sampler2D grass : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D road : source_color, filter_linear_mipmap, repeat_enable;
// One grass tile covers this many strip pixels each way.
uniform float grass_size = 300.0;
// The road tile is twice as long as it is wide, kerb to kerb.
uniform float road_aspect = 2.0;
uniform vec4 haze : source_color = vec4(0.80, 0.92, 0.98, 1.0);
uniform vec4 sun : source_color = vec4(0.92, 0.95, 0.62, 1.0);
uniform float sun_share = 0.55;
uniform vec4 kerb_shadow : source_color = vec4(0.18, 0.35, 0.08, 1.0);

float road_x(float s) {
	return sway_a * sin(TAU * s / sway_a_length + sway_a_phase) + sway_b * sin(TAU * s / sway_b_length + sway_b_phase);
}

// How steeply the road runs across, so its width is measured square to it and a bend is as wide as a straight.
float road_slope(float s) {
	return sway_a * TAU / sway_a_length * cos(TAU * s / sway_a_length + sway_a_phase)
		+ sway_b * TAU / sway_b_length * cos(TAU * s / sway_b_length + sway_b_phase);
}

void fragment() {
	float s = scroll + UV.x;
	float x = UV.y;
	float t = UV.x / radius;
	float slope = road_slope(s);
	float across = (x - road_x(s)) / sqrt(1.0 + slope * slope);
	float d = abs(across);
	float px = max(fwidth(d), 0.001);
	vec3 lawn = texture(grass, vec2(x, s) / grass_size).rgb;
	// Warmed toward the concepts' sunny yellow-green.
	lawn = mix(lawn, lawn * sun.rgb * 1.3, sun_share);
	// A soft shadow on the grass along the road's edge.
	lawn = mix(lawn, lawn * kerb_shadow.rgb * 2.2, 0.22 * (1.0 - smoothstep(road_half, road_half + 20.0, d)));
	float width = 2.0 * road_half;
	vec3 street = texture(road, vec2(across / width + 0.5, s / (width * road_aspect))).rgb;
	float on_road = 1.0 - smoothstep(road_half - px, road_half + px, d);
	vec3 colour = mix(lawn, street, on_road);
	colour = mix(colour, haze.rgb, 0.45 * smoothstep(1.1, 1.57, t));
	COLOR = vec4(colour, 1.0);
}
