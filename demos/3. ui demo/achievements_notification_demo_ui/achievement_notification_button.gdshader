shader_type canvas_item;

// Offset parameters for positioning
uniform vec2 offset = vec2(0.0, 0.0);

void vertex() {
	VERTEX += offset;
}

void fragment() {
}
