shader_type canvas_item;
// QuadMesh UVs run bottom-up in 2D; flip them so sprites drawn through a MultiMesh stay upright.

void vertex() {
	UV.y = 1.0 - UV.y;
}
