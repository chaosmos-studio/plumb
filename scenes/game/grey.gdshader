// The screen in black and white for the memorial (MATH.md section 19), in one pass over what is already drawn.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
// 0 is the screen as it is, 1 fully grey.
uniform float amount : hint_range(0.0, 1.0) = 1.0;
// How much the grey screen dims toward its edges, so the eye goes to the middle.
uniform float dusk : hint_range(0.0, 1.0) = 0.38;

// The 2D canvas holds sRGB values. Luminance is a sum of linear light, so each channel is decoded first and the
// grey is encoded back, which keeps a red and a teal marble of equal brightness the same grey.
vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float to_srgb(float y) {
	return y <= 0.0031308 ? y * 12.92 : 1.055 * pow(y, 1.0 / 2.4) - 0.055;
}

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float grey = to_srgb(dot(to_linear(c), vec3(0.2126, 0.7152, 0.0722)));
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.0, 0.8);
	float edge = smoothstep(0.18, 0.75, length(d));
	vec3 tone = mix(c, vec3(grey), amount);
	COLOR = vec4(tone * (1.0 - dusk * amount * (0.45 + 0.55 * edge)), 1.0);
}
