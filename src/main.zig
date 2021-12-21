const std = @import("std");
const builtin = @import("builtin");

const c = @import("c.zig");
const darwin = @import("darwin.zig");
const metal = @import("metal.zig");
const simd = @import("simd.zig");
    
pub fn main() anyerror!void {
    if (c.glfwInit() != 1) {
        std.log.info("Failed to initialize GLFW", .{});
        return;
    }
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);

    const width = 640;
    const height = 480;
    const window: *c.GLFWwindow = c.glfwCreateWindow(width, height, "Metal Triangle", null, null) orelse return;
    defer c.glfwDestroyWindow(window);

    const content_view = metal.createContentView(darwin.glfwGetCocoaWindow(window).?);

    const device = metal.createSystemDefaultDevice();
    const queue = device.newCommandQueue();

    const metal_layer = metal.createMetalLayer();
    metal_layer.setDevice(device);

    content_view.setMetalLayer(metal_layer);

    const library = device.newDefaultLibrary();
    const vertex_function = library.newFunction("render_vertex");
    const fragment_function = library.newFunction("render_fragment");


    // Parse and load GLTF
    const file_path = "/Users/nicolaslangley/Developer/metal_projects/metal-base-project/data/Box.glb";
    const options = std.mem.zeroes(c.cgltf_options);
    var gltf_data: *c.cgltf_data = undefined;
    var result = c.cgltf_parse_file(&options, file_path, @ptrCast([*c][*c]c.cgltf_data, &gltf_data));
    result = c.cgltf_load_buffers(&options, gltf_data, file_path);
    result = c.cgltf_validate(gltf_data);

    const indices: *c.cgltf_accessor = gltf_data.*.meshes[0].primitives[0].indices;
    const index_stride = indices.*.stride;
    const indices_ptr = @alignCast(4, @ptrCast([*]const u8, indices.*.buffer_view.*.buffer.*.data) + indices.*.offset + indices.*.buffer_view.*.offset);
    const indices_count = indices.count;

    const index_buffer = device.newBufferWithBytes(indices_ptr, indices_count * index_stride, metal.ResourceOptions.StorageModeShared);

    // Vertex data
    const attributes: [*]c.cgltf_attribute = gltf_data.*.meshes[0].primitives[0].attributes;
    const vertex_count = attributes[1].data.*.count;
    const position_data = attributes[1].data;
    const position_stride = position_data.*.stride;
    const position_ptr = @alignCast(4, @ptrCast([*]const u8, position_data.*.buffer_view.*.buffer.*.data) + position_data.*.offset + position_data.*.buffer_view.*.offset);
    const position_buffer = device.newBufferWithBytes(position_ptr, vertex_count * position_stride, metal.ResourceOptions.StorageModeShared);

    const normal_data = attributes[0].data;
    const normal_stride = normal_data.*.stride;
    const normal_ptr = @alignCast(4, @ptrCast([*]const u8, normal_data.*.buffer_view.*.buffer.*.data) + normal_data.*.offset + normal_data.*.buffer_view.*.offset);
    const normal_buffer = device.newBufferWithBytes(normal_ptr, vertex_count * normal_stride, metal.ResourceOptions.StorageModeShared);

    const vertex_desc = metal.createVertexDescriptor();
    vertex_desc.attributes().objectAt(0).setFormat(metal.VertexFormat.Float3);
    vertex_desc.attributes().objectAt(0).setOffset(0);
    vertex_desc.attributes().objectAt(0).setBufferIndex(0);
    vertex_desc.attributes().objectAt(1).setFormat(metal.VertexFormat.Float3);
    vertex_desc.attributes().objectAt(1).setOffset(position_stride);
    vertex_desc.attributes().objectAt(1).setBufferIndex(0);
    vertex_desc.layouts().objectAt(0).setStride(position_stride);
    vertex_desc.layouts().objectAt(0).setStride(normal_stride);

    const pipeline_desc = metal.createRenderPipelineDescriptor();
    pipeline_desc.setVertexFunction(vertex_function);
    pipeline_desc.setFragmentFunction(fragment_function);
    pipeline_desc.setVertexDescriptor(vertex_desc);
    pipeline_desc.colorAttachments().objectAt(0).setPixelFormat(metal.PixelFormat.BGRA8Unorm);

    const pipeline_state = device.newRenderPipelineState(pipeline_desc);
     
    const view_matrix = simd.matrixTranslation(0.0, -2.0, -8.0);
    const projection_matrix = simd.matrixPerspectiveRightHand(65.0 * (std.math.pi / 180.0), @intToFloat(f32, width) / @intToFloat(f32, height), 0.1, 100.0);
    const mvp_matrix = simd.matrixMultiply(projection_matrix, view_matrix);

    while (c.glfwWindowShouldClose(window) != 1) {
        c.glfwPollEvents();

        const command_buffer = queue.commandBuffer();
        const current_drawable = metal_layer.nextDrawable();

        const pass_desc = metal.createRenderPassDescriptor();
        const color_attachment_desc = pass_desc.colorAttachments().objectAt(0);
        color_attachment_desc.setTexture(current_drawable.texture());
        color_attachment_desc.setLoadAction(metal.LoadAction.Clear);
        color_attachment_desc.setStoreAction(metal.StoreAction.Store);
        color_attachment_desc.setClearColor(metal.ClearColor{ .red = 0.0, .blue = 0.0, .green = 0.0, .alpha = 1.0 });

        const render_encoder = command_buffer.renderCommandEncoder(pass_desc);
        render_encoder.setRenderPipelineState(pipeline_state);
        render_encoder.setVertexBuffer(position_buffer, 0, 0);
        render_encoder.setVertexBuffer(normal_buffer, 0, 1);
        render_encoder.setVertexBytes(@ptrCast(*const c_void, &mvp_matrix), @sizeOf(simd.Mat4), 2);
        render_encoder.drawIndexedPrimitives(metal.PrimitiveType.Triangle, indices_count, metal.IndexType.UInt16, index_buffer, 0);
        render_encoder.endEncoding();

        command_buffer.presentDrawable(current_drawable);
        command_buffer.commit();
    }
}
