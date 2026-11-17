shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.15, 0.15, 1.0);
uniform float outline_width : hint_range(0.0, 15.0) = 0.0;

void fragment() {
	// Only draws the outline around transparent edges when outline_width > 0
	// Leaves interior colors, white flashes and death fades untouched!
	if (outline_width > 0.0 && COLOR.a < 0.1) {
		vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
		float alpha = 0.0;
		alpha += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
		alpha += texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
		alpha += texture(TEXTURE, UV + vec2(0.0, size.y)).a;
		alpha += texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
		alpha += texture(TEXTURE, UV + vec2(size.x, size.y)).a;
		alpha += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
		alpha += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
		alpha += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
		if (alpha > 0.0) {
			COLOR = outline_color;
		}
	}
}