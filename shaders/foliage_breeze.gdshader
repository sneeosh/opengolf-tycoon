shader_type canvas_item;

// Vertex-only motion retains the original pixel art and anchors the trunk.
// World position supplies distinct phases with one shared material.
void vertex() {
	float phase = MODEL_MATRIX[3].x * 0.013 + MODEL_MATRIX[3].y * 0.021;
	float crown = pow(1.0 - UV.y, 2.0);
	VERTEX.x += (sin(TIME * 1.15 + phase) + sin(TIME * 1.9 + phase * 0.7) * 0.3) * crown * 1.15;
}
