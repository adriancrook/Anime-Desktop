shader_type spatial;
// depth_prepass_alpha = Alpha Hash (Smooth dithering, no Z-fighting)
render_mode cull_disabled, depth_prepass_alpha;

uniform sampler2D main_texture : source_color;
uniform sampler2D toon_ramp : source_color;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Specific control for the fishnets
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.1;

// Rim Light settings
uniform float rim_amount : hint_range(0.0, 1.0) = 0.5;
uniform float rim_sharpness : hint_range(0.0, 5.0) = 2.0;

void fragment() {
    vec4 albedo_tex = texture(main_texture, UV);
    ALBEDO = albedo_tex.rgb * tint_color.rgb;
    ALPHA = albedo_tex.a; // Let the engine handle the hashing automatically
}

void light() {
    // Exact same lighting logic as the body
    float dot_product = dot(NORMAL, LIGHT);
    float sample_pos = (dot_product + 1.0) / 2.0;
    sample_pos = clamp(sample_pos, 0.05, 0.95);
    vec3 ramp_color = texture(toon_ramp, vec2(sample_pos, 0.0)).rgb;
    
    float rim_dot = 1.0 - dot(VIEW, NORMAL);
    float rim = pow(rim_dot, rim_sharpness) * rim_amount * dot_product; 
    
    vec3 final_light = LIGHT_COLOR * ramp_color * ATTENUATION;
    final_light += vec3(rim);
    
    DIFFUSE_LIGHT += clamp(final_light * ALBEDO, 0.0, 1.0);
}