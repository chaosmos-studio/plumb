shader_type canvas_item;

// Dims the screen except inside up to four soft-edged circles. The rect covers the viewport, so UV times
// its size is the viewport position the game gives the holes in.

uniform vec4 scrim : source_color = vec4(0.0, 0.0, 0.0, 0.5);
uniform vec2 rect_size = vec2(720.0, 1280.0);
uniform vec4 holes[4];
uniform int count = 0;
uniform float strength = 1.0;

void fragment() {
	vec2 p = UV * rect_size;
	float a = 1.0;
	for (int i = 0; i < 4; i++) {
		if (i >= count) {
			break;
		}
		float d = distance(p, holes[i].xy);
		a = min(a, smoothstep(holes[i].z, holes[i].z + holes[i].w, d));
	}
	COLOR = vec4(scrim.rgb, scrim.a * a * strength);
}
