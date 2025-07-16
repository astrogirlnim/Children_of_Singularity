shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, depth_test_disabled, blend_mix;

// Background texture input
uniform sampler2D background_texture : source_color, filter_linear, repeat_enable;

// Alpha and tinting controls
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Parallax and movement controls
uniform float parallax_strength : hint_range(0.0, 2.0) = 1.0;
uniform vec2 scroll_speed = vec2(0.0, 0.0);

// Depth fog controls for distance effect
uniform float fog_enabled : hint_range(0.0, 1.0) = 0.0;
uniform float fog_start : hint_range(0.0, 1000.0) = 100.0;
uniform float fog_end : hint_range(0.0, 1000.0) = 500.0;
uniform vec4 fog_color : source_color = vec4(0.05, 0.05, 0.1, 1.0);

// Animation controls
uniform float pulse_enabled : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 1.0;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.1;

varying vec3 world_position;
varying float vertex_distance;

void vertex() {
    // Calculate world position for fog effects
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

    // Calculate distance from camera for fog
    vec3 camera_pos = INV_VIEW_MATRIX[3].xyz;
    vertex_distance = distance(world_position, camera_pos);

    // Apply any vertex-level transformations here if needed
    POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
}

void fragment() {
    // Calculate UV coordinates with scrolling
    vec2 animated_uv = UV + scroll_speed * TIME;

    // Sample the background texture
    vec4 tex_color = texture(background_texture, animated_uv);

    // Apply tint color
    vec3 final_color = tex_color.rgb * tint_color.rgb;

    // Apply pulsing effect if enabled
    if (pulse_enabled > 0.5) {
        float pulse_factor = 1.0 + sin(TIME * pulse_speed) * pulse_strength;
        final_color *= pulse_factor;
    }

    // Calculate base alpha
    float final_alpha = tex_color.a * tint_color.a * alpha;

    // Apply distance fog if enabled
    if (fog_enabled > 0.5) {
        float fog_factor = clamp((vertex_distance - fog_start) / (fog_end - fog_start), 0.0, 1.0);
        final_color = mix(final_color, fog_color.rgb, fog_factor * fog_color.a);
        final_alpha = mix(final_alpha, fog_color.a, fog_factor * 0.5);
    }

    // Output final color
    ALBEDO = final_color;
    ALPHA = final_alpha;

    // Ensure proper depth sorting for background elements
    DEPTH = 0.999;
}
