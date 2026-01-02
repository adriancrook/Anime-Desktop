shader_type spatial;

// 1. INPUTS
uniform sampler2D main_texture : source_color;
uniform sampler2D toon_ramp : source_color; // This is where we drag our gradient
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// 2. RIM LIGHT (The glowing edge effect from the video)
uniform float rim_amount : hint_range(0.0, 1.0) = 0.5;
uniform float rim_sharpness : hint_range(0.0, 5.0) = 2.0;

void fragment() {
    // Get the color from your texture (skin, clothes, etc)
    vec4 albedo_tex = texture(main_texture, UV);
    ALBEDO = albedo_tex.rgb * tint_color.rgb;
}

void light() {
    // ---------------------------------------------------------
    // THE MATH (The "Dot Product" trick)
    // ---------------------------------------------------------
    
    // Calculate the angle between the light and the surface
    // Result is between -1 (dark) and 1 (light)
    float dot_product = dot(NORMAL, LIGHT);
    
    // Convert that range to 0.0 -> 1.0 so we can read the texture
    float sample_pos = (dot_product + 1.0) / 2.0;
    
    // Clamp it slightly to avoid weird artifacts
    sample_pos = clamp(sample_pos, 0.05, 0.95);
    
    // Read the color from your Gradient Ramp based on the light angle
    vec3 ramp_color = texture(toon_ramp, vec2(sample_pos, 0.0)).rgb;
    
    // ---------------------------------------------------------
    // RIM LIGHT (Fresnel)
    // ---------------------------------------------------------
    float rim_dot = 1.0 - dot(VIEW, NORMAL);
    float rim = pow(rim_dot, rim_sharpness) * rim_amount * dot_product; // Only rim light on the lit side
    
    // ---------------------------------------------------------
    // COMBINE IT ALL
    // ---------------------------------------------------------
    // Light Color * Ramp Color * Shadow Attenuation (supports casting shadows)
    vec3 final_light = LIGHT_COLOR * ramp_color * ATTENUATION;
    
    // Add the rim light
    final_light += vec3(rim);
    
    DIFFUSE_LIGHT += clamp(final_light * ALBEDO, 0.0, 1.0);
}