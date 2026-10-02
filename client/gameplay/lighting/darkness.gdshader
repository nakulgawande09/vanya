shader_type canvas_item;
// The bible's darkness layer: a night-ink veil over the room with soft light holes cut through it
// (hunter largest, torches, cages, open gate, orbs). One full-screen quad, no textures.

const int MAX_HOLES = 16;

uniform vec4 veil : source_color = vec4(0.11, 0.063, 0.086, 0.74);
// xy = screen position (px), z = radius (px), w = strength (0-1)
uniform vec4 holes[MAX_HOLES];
uniform int hole_count = 0;

void fragment() {
	vec2 p = FRAGCOORD.xy;
	float light = 0.0;
	for (int i = 0; i < MAX_HOLES; i++) {
		if (i >= hole_count) {
			break;
		}
		vec4 h = holes[i];
		float d = distance(p, h.xy) / max(h.z, 1.0);
		// Matches the bible's wHole gradient: opaque centre, 75% at 0.55, gone at the edge.
		float hole = d < 0.55 ? mix(1.0, 0.75, d / 0.55) : mix(0.75, 0.0, clamp((d - 0.55) / 0.45, 0.0, 1.0));
		light = max(light, hole * h.w);
	}
	COLOR = vec4(veil.rgb, veil.a * (1.0 - light));
}
