shader_type canvas_item;

uniform float green_intensity : hint_range(0.0, 1.0) = 0.7;
uniform float color_preservation : hint_range(0.0, 1.0) = 0.3;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
    // Get original pixel color from the sprite texture
    vec4 original_color = texture(TEXTURE, UV);

    // Create a green-tinted version of the color
    vec4 green_color = original_color;
    // Increase green channel while slightly reducing red and blue
    green_color.r *= (1.0 - green_intensity * 0.5);
    green_color.g = min(green_color.g * (1.0 + green_intensity * 0.7), 1.0);
    green_color.b *= (1.0 - green_intensity * 0.5);

    // Mix between the green color and original based on preservation factor
    vec4 final_color = mix(green_color, original_color, color_preservation);

    // Keep the original alpha (transparency)
    final_color.a = original_color.a;

    // Output the final color
    COLOR = final_color;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
