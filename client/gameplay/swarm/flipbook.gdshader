shader_type canvas_item;
// Swarm flipbook: one MultiMesh draw for every unit. INSTANCE_CUSTOM per unit:
// x = frame index, y = facing (+1 / -1), z = hit flash (0-1), w = alpha.

uniform float stride_uv = 1.0;  // cell stride / sheet width
uniform float cell_uv = 1.0;    // cell width / sheet width

varying vec4 custom;

void vertex() {
	custom = INSTANCE_CUSTOM;
	VERTEX.x *= custom.y;
	UV = vec2(custom.x * stride_uv + UV.x * cell_uv, 1.0 - UV.y);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(c.rgb, vec3(1.0), custom.z);
	COLOR = vec4(c.rgb, c.a * custom.w);
}
