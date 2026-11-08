shader_type spatial;
render_mode depth_test_disabled, depth_draw_never;

uniform sampler2D albedo_texture : source_color;

void fragment() {
    ALBEDO = texture(albedo_texture, UV).rgb;
    ROUGHNESS = 0.8;
}