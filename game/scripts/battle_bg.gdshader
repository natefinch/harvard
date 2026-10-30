shader_type canvas_item;

uniform vec4 c1 : source_color = vec4(0.12, 0.05, 0.25, 1.0);
uniform vec4 c2 : source_color = vec4(0.35, 0.12, 0.45, 1.0);
uniform vec4 c3 : source_color = vec4(0.05, 0.3, 0.35, 1.0);
uniform float speed = 1.0;

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	float line = mod(FRAGCOORD.y, 4.0) < 2.0 ? 1.0 : -1.0;
	uv.x += sin(uv.y * 14.0 + t * 2.0) * 0.025 * line;
	uv.y += sin(uv.x * 9.0 + t * 1.3) * 0.03;
	float s = sin((uv.x + uv.y) * 22.0 + t * 2.5) + sin(length(uv - vec2(0.5, 0.45)) * 36.0 - t * 3.5);
	float v = 0.5 + 0.5 * sin(s * 1.6);
	float w = 0.5 + 0.5 * sin(uv.y * 30.0 - t * 1.7 + s);
	vec4 col = mix(mix(c1, c2, v), c3, w * 0.45);
	COLOR = vec4(col.rgb, 1.0);
}
