shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 1.0;
// Allows mapping the liquid fill smoothly onto the head area even on full-body sprites
uniform float uv_top : hint_range(0.0, 1.0) = 0.0;
uniform float uv_bottom : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float normalized_y = clamp((UV.y - uv_top) / max(0.001, (uv_bottom - uv_top)), 0.0, 1.0);
	float fill_height = 1.0 - normalized_y;
	
	if (fill_height > progress) {
		// Unfilled portion: Desaturate to dark greyscale
		float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		COLOR = vec4(vec3(gray * 0.32), tex.a);
	} else {
		// Filled portion: Full vibrant color!
		COLOR = tex;
	}
}
