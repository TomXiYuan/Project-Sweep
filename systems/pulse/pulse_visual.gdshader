shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never;

// Pulse data
global uniform sampler2D pulse_data : filter_nearest;
global uniform int pulse_count;

// Screen textures
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D normal_texture : hint_normal_roughness_texture, filter_nearest;

// Pulse settings
uniform float pulse_brightness = 2.0;

// Edge settings
uniform float edge_brightness = 1.0;
uniform float edge_duration = 2.0;
uniform float edge_thickness : hint_range(0.0, 8.0, 1.0) = 1.0;   // outline width in pixels (Roystan's "scale")
uniform float depth_threshold : hint_range(0.0, 5.0, 0.01) = 1.5;
uniform float normal_threshold : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float depth_normal_threshold : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float depth_normal_threshold_scale : hint_range(0.0, 20.0, 0.1) = 7.0;
// true  = sky/background pixels next to an edge are outlined too (same thickness as against a floor)
// false = only geometry pixels are outlined (thin against sky, thick against a floor)
uniform bool outline_sky = true;


// Reconstruct view position
vec3 get_view_pos(vec2 uv, mat4 inv_proj) {
	// Sky has depth 0 (reversed-Z). Clamp it so it becomes a finite, very distant "wall"
	// instead of a divide-by-zero.
	float depth = max(texture(depth_texture, uv).r, 0.000001);
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);

	vec4 view = inv_proj * vec4(ndc, 1.0);
	return view.xyz / view.w;
}

// Detect geometry edges (Roberts Cross on depth + view-space normals, after Roystan's outline shader).
// anchor_view_pos returns the view-space position of the NEAREST surface touching this edge pixel.
// The pulse timing for the edge uses that position instead of the pixel's own, so both sides of an
// edge light up together with the closer surface and never fire a second time when the pulse later
// reaches whatever is behind it (e.g. the floor).
float detect_edges(vec2 uv, mat4 inv_proj, out vec3 anchor_view_pos) {
	vec2 texel = 1.0 / vec2(textureSize(depth_texture, 0));

	float half_floor = floor(edge_thickness * 0.5);
	float half_ceil = ceil(edge_thickness * 0.5);

	// Roberts Cross sample positions
	vec2 bl_uv = clamp(uv - texel * half_floor, vec2(0.001), vec2(0.999));
	vec2 tr_uv = clamp(uv + texel * half_ceil, vec2(0.001), vec2(0.999));
	vec2 br_uv = clamp(uv + vec2(texel.x * half_ceil, -texel.y * half_floor), vec2(0.001), vec2(0.999));
	vec2 tl_uv = clamp(uv + vec2(-texel.x * half_floor, texel.y * half_ceil), vec2(0.001), vec2(0.999));

	// View-space positions (linear depth = -z)
	vec3 center_pos = get_view_pos(uv, inv_proj);
	vec3 p0 = get_view_pos(bl_uv, inv_proj);
	vec3 p1 = get_view_pos(tr_uv, inv_proj);
	vec3 p2 = get_view_pos(br_uv, inv_proj);
	vec3 p3 = get_view_pos(tl_uv, inv_proj);
	float d0 = -p0.z;
	float d1 = -p1.z;
	float d2 = -p2.z;
	float d3 = -p3.z;

	// Nearest surface among the center and the four samples
	anchor_view_pos = center_pos;
	float nearest = -center_pos.z;
	if (d0 < nearest) { nearest = d0; anchor_view_pos = p0; }
	if (d1 < nearest) { nearest = d1; anchor_view_pos = p1; }
	if (d2 < nearest) { nearest = d2; anchor_view_pos = p2; }
	if (d3 < nearest) { nearest = d3; anchor_view_pos = p3; }

	// View-space normals
	vec3 n0 = texture(normal_texture, bl_uv).xyz * 2.0 - 1.0;
	vec3 n1 = texture(normal_texture, tr_uv).xyz * 2.0 - 1.0;
	vec3 n2 = texture(normal_texture, br_uv).xyz * 2.0 - 1.0;
	vec3 n3 = texture(normal_texture, tl_uv).xyz * 2.0 - 1.0;

	// Raise the depth threshold on surfaces seen at grazing angles
	// so flat floors at shallow angles don't light up.
	vec3 view_dir = normalize(-center_pos);
	float n_dot_v = 1.0 - dot(normalize(n0), view_dir);
	float normal_threshold_01 = clamp((n_dot_v - depth_normal_threshold) / (1.0 - depth_normal_threshold), 0.0, 1.0);
	float normal_threshold_mod = normal_threshold_01 * depth_normal_threshold_scale + 1.0;

	// Depth edge
	float edge_depth = sqrt(pow(d1 - d0, 2.0) + pow(d3 - d2, 2.0)) * 100.0;
	float depth_thresh = depth_threshold * d0 * normal_threshold_mod;
	edge_depth = edge_depth > depth_thresh ? 1.0 : 0.0;

	// Normal edge
	vec3 nd0 = n1 - n0;
	vec3 nd1 = n3 - n2;
	float edge_normal = sqrt(dot(nd0, nd0) + dot(nd1, nd1));
	edge_normal = edge_normal > normal_threshold ? 1.0 : 0.0;

	return max(edge_depth, edge_normal);
}


void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}


void fragment() {
	vec3 scene_color = texture(screen_texture, SCREEN_UV).rgb;
	ALBEDO = scene_color;
	float depth = texture(depth_texture, SCREEN_UV).r;
	bool is_sky = depth <= 0.00001;

	if (!is_sky || outline_sky) {
		vec3 view_pos = get_view_pos(SCREEN_UV, INV_PROJECTION_MATRIX);
		vec3 world_pos = (INV_VIEW_MATRIX * vec4(view_pos, 1.0)).xyz;
		
		float edges = 0.0;
		vec3 anchor_world_pos = world_pos;
		
		int count = min(max(pulse_count, 0), textureSize(pulse_data, 0).x);
        
		if (count > 0) {
			vec3 anchor_view_pos;
			edges = detect_edges(SCREEN_UV, INV_PROJECTION_MATRIX, anchor_view_pos);
			if (edges > 0.0) {
				anchor_world_pos = (INV_VIEW_MATRIX * vec4(anchor_view_pos, 1.0)).xyz;
			}
		}

		vec3 pulse_glow = vec3(0.0);
		vec3 edge_glow = vec3(0.0);
		
		for (int i = 0; i < count; i++) {
			// Row 0: Origin + current radius
			vec4 pulse = texelFetch(pulse_data, ivec2(i, 0), 0);
			// Row 1: Color + width
			vec4 appearance = texelFetch(pulse_data, ivec2(i, 1), 0);
			// Row 2: Max radius + speed
			vec4 properties = texelFetch(pulse_data, ivec2(i, 2), 0);
			// Unpack pulse properties
			vec3 origin = pulse.xyz;
			float radius = pulse.w;
			vec3 color = appearance.rgb;
			float width = appearance.a;
			float max_radius = properties.r;
			float speed = properties.g;
			
			float dist = distance(world_pos, origin);
			float fade = 1.0 - clamp(radius / max(max_radius, 0.0001), 0.0, 1.0);
			
			// Expanding ring
			float ring = 1.0 - smoothstep(0.0, max(width, 0.0001), abs(dist - radius));
			
			// Sky never receives the expanding ring.
			if (!is_sky) {
				pulse_glow += color * ring * fade;
			}
			
			// Lingering edge highlighting
			if (edges > 0.0) {
				float edge_dist = distance(anchor_world_pos, origin);
				float behind = radius - edge_dist;
				
				// Each pulse has its own speed.
				float trail_distance = max(speed * edge_duration, 0.001);
				float lead = smoothstep(0.0, max(width, 0.0001), behind);
				float decay = 1.0 - smoothstep(0.0, trail_distance, behind);
				float trail = lead * pow(decay, 2.0);
				
				// Each pulse contributes its own color.
				edge_glow += color * trail * fade;
			}
		}
		
		pulse_glow *= pulse_brightness;
		edge_glow *= edges * edge_brightness;
		ALBEDO = scene_color + pulse_glow + edge_glow;
	}
}