shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always;

// FIXED: Changed '#' to '//'
uniform float thickness : hint_range(0.0, 0.1) = 0.003; 
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void vertex() {
    // Grow the mesh slightly along the normals
    VERTEX += NORMAL * thickness;
}

void fragment() {
    // Make it solid color
    ALBEDO = outline_color.rgb;
}