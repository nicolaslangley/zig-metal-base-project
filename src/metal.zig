const c = @import("c.zig");

// Adapted from: https://github.com/mkeeter/rayray/blob/master/src/objc.zig
fn class(s: [*c]const u8) c.id {
    return @ptrCast(c.id, @alignCast(8, c.objc_lookUpClass(s)));
}

fn call(obj: c.id, sel_name: [*c]const u8) c.id {
    var f = @ptrCast(
        fn (c.id, c.SEL) callconv(.C) c.id,
        c.objc_msgSend,
    );
    return f(obj, c.sel_getUid(sel_name));
}

fn call_(obj: c.id, sel_name: [*c]const u8, args: anytype) c.id {
    //  objc_msgSend has the prototype "void objc_msgSend(void)",
    //  so we have to cast it based on the types of our arguments
    //  (https://www.mikeash.com/pyblog/objc_msgsends-new-prototype.html)
    if (args.len == 5) {
        var f = @ptrCast(
            fn (c.id, c.SEL, @TypeOf(args[0]), @TypeOf(args[1]), @TypeOf(args[2]), @TypeOf(args[3]), @TypeOf(args[4])) callconv(.C) c.id,
            c.objc_msgSend,
        );
        return f(obj, c.sel_getUid(sel_name), args[0], args[1], args[2], args[3], args[4]);
    }
    if (args.len == 4) {
        var f = @ptrCast(
            fn (c.id, c.SEL, @TypeOf(args[0]), @TypeOf(args[1]), @TypeOf(args[2]), @TypeOf(args[3])) callconv(.C) c.id,
            c.objc_msgSend,
        );
        return f(obj, c.sel_getUid(sel_name), args[0], args[1], args[2], args[3]);
    }
    if (args.len == 3) {
        var f = @ptrCast(
            fn (c.id, c.SEL, @TypeOf(args[0]), @TypeOf(args[1]), @TypeOf(args[2])) callconv(.C) c.id,
            c.objc_msgSend,
        );
        return f(obj, c.sel_getUid(sel_name), args[0], args[1], args[2]);
    }
    if (args.len == 2) {
        var f = @ptrCast(
            fn (c.id, c.SEL, @TypeOf(args[0]), @TypeOf(args[1])) callconv(.C) c.id,
            c.objc_msgSend,
        );
        return f(obj, c.sel_getUid(sel_name), args[0], args[1]);
    }
    if (args.len == 1) {
        var f = @ptrCast(
            fn (c.id, c.SEL, @TypeOf(args[0])) callconv(.C) c.id,
            c.objc_msgSend,
        );
        return f(obj, c.sel_getUid(sel_name), args[0]);
    }
}

fn createNSString(str: [*:0]const u8) c.id {
    const ns_string = class("NSString");
    return call_(call(ns_string, "alloc"), "initWithUTF8String:", .{str});
}

pub fn createMetalLayer() MetalLayer {
    const ca_metal = class("CAMetalLayer");
    return MetalLayer{ .objc_id = call(ca_metal, "layer") };
}

const MetalLayer = struct {
    objc_id: c.id,

    pub fn setDevice(self: MetalLayer, device: Device) void {
        _ = call_(self.objc_id, "setDevice:", .{device.objc_id});
    }

    pub fn nextDrawable(self: MetalLayer) MetalDrawable {
        return MetalDrawable{ .objc_id = call(self.objc_id, "nextDrawable") };
    }
};

const MetalDrawable = struct {
    objc_id: c.id,

    pub fn texture(self: MetalDrawable) c.id {
        return call(self.objc_id, "texture");
    }
};

pub fn createContentView(window: *c_void) ContentView {
    const ns_window = @ptrCast(c.id, @alignCast(8, window));
    const view = call(ns_window, "contentView");
    _ = call_(view, "setWantsLayer:", .{true});
    return ContentView{ .objc_id = view };
}

const ContentView = struct {
    objc_id: c.id,

    pub fn setMetalLayer(self: ContentView, layer: MetalLayer) void {
        _ = call_(self.objc_id, "setLayer:", .{layer.objc_id});
    }
};

pub extern fn MTLCreateSystemDefaultDevice() callconv(.C) c.id;

pub fn createSystemDefaultDevice() Device {
    return Device{ .objc_id = MTLCreateSystemDefaultDevice() };
}

pub const ResourceOptions = enum(u32) {
    StorageModeShared = 0 << 4,
    StorageModePrivate = 2 << 4,
};

const Device = struct {
    objc_id: c.id,

    pub fn newCommandQueue(self: Device) CommandQueue {
        return CommandQueue{ .objc_id = call(self.objc_id, "newCommandQueue") };
    }

    pub fn newBufferWithLength(self: Device, length: u32, options: ResourceOptions) Buffer {
        return Buffer{ .objc_id = call_(self.objc_id, "newBufferWithLength:options:", .{ length, @enumToInt(options) }) };
    }

    pub fn newBufferWithBytes(self: Device, bytes: *const c_void, length: u64, options: ResourceOptions) Buffer {
        return Buffer{ .objc_id = call_(self.objc_id, "newBufferWithBytes:length:options:", .{ bytes, length, @enumToInt(options) }) };
    }

    pub fn newDefaultLibrary(self: Device) Library {
        return Library{ .objc_id = call(self.objc_id, "newDefaultLibrary") };
    }

    pub fn newRenderPipelineState(self: Device, pipeline_descriptor: RenderPipelineDescriptor) RenderPipelineState {
        return RenderPipelineState{ .objc_id = call_(self.objc_id, "newRenderPipelineStateWithDescriptor:error:", .{pipeline_descriptor.objc_id, c.nil})};
    }
};

const CommandQueue = struct {
    objc_id: c.id,

    pub fn commandBuffer(self: CommandQueue) CommandBuffer {
        return CommandBuffer{ .objc_id = call(self.objc_id, "commandBuffer") };
    }
};

const CommandBuffer = struct {
    objc_id: c.id,

    pub fn renderCommandEncoder(self: CommandBuffer, descriptor: RenderPassDescriptor) RenderCommandEncoder {
        return RenderCommandEncoder{ .objc_id = call_(self.objc_id, "renderCommandEncoderWithDescriptor:", .{descriptor.objc_id}) };
    }

    pub fn presentDrawable(self: CommandBuffer, drawable: MetalDrawable) void {
        _ = call_(self.objc_id, "presentDrawable:", .{drawable.objc_id});
    }

    pub fn commit(self: CommandBuffer) void {
        _ = call(self.objc_id, "commit");
    }
};

pub fn createRenderPassDescriptor() RenderPassDescriptor {
    const mtl_render_pass_desc = class("MTLRenderPassDescriptor");
    return RenderPassDescriptor{ .objc_id = call(mtl_render_pass_desc, "renderPassDescriptor") };
}

const RenderPassDescriptor = struct {
    objc_id: c.id,

    pub fn colorAttachments(self: RenderPassDescriptor) RenderPassColorAttachmentDescriptorArray {
        return RenderPassColorAttachmentDescriptorArray{ .objc_id = call(self.objc_id, "colorAttachments") };
    }
};

const RenderPassColorAttachmentDescriptorArray = struct {
    objc_id: c.id,

    pub fn objectAt(self: RenderPassColorAttachmentDescriptorArray, index: u32) RenderPassColorAttachmentDescriptor {
        return RenderPassColorAttachmentDescriptor{ .objc_id = call_(self.objc_id, "objectAtIndexedSubscript:", .{index}) };
    }
};

// https://developer.apple.com/documentation/metal/mtlloadaction?language=objc#
pub const LoadAction = enum(u32) {
    DontCare = 0,
    Load = 1,
    Clear = 2,
};

// https://developer.apple.com/documentation/metal/mtlstoreaction?language=objc#
pub const StoreAction = enum(u32) {
    DontCare = 0,
    Store = 1,
};

pub const ClearColor = extern struct {
    red: f64,
    blue: f64,
    green: f64,
    alpha: f64,
};

const RenderPassColorAttachmentDescriptor = struct {
    objc_id: c.id,

    pub fn setTexture(self: RenderPassColorAttachmentDescriptor, texture: c.id) void {
        _ = call_(self.objc_id, "setTexture:", .{texture});
    }

    pub fn setClearColor(self: RenderPassColorAttachmentDescriptor, clear_color: ClearColor) void {
        _ = call_(self.objc_id, "setClearColor:", .{clear_color});
    }

    pub fn setLoadAction(self: RenderPassColorAttachmentDescriptor, load_action: LoadAction) void {
        _ = call_(self.objc_id, "setLoadAction:", .{@enumToInt(load_action)});
    }

    pub fn setStoreAction(self: RenderPassColorAttachmentDescriptor, store_action: StoreAction) void {
        _ = call_(self.objc_id, "setStoreAction:", .{@enumToInt(store_action)});
    }
};

// https://developer.apple.com/documentation/metal/mtlprimitivetype?language=objc#
pub const PrimitiveType = enum(u32) {
    Triangle = 3
};

// https://developer.apple.com/documentation/metal/mtlindextype?language=objc
pub const IndexType = enum(u32) {
    UInt16 = 0,
    UInt32 = 1,
};

const RenderCommandEncoder = struct {
    objc_id: c.id,

    pub fn setRenderPipelineState(self: RenderCommandEncoder, pipeline_state: RenderPipelineState) void {
        _ = call_(self.objc_id, "setRenderPipelineState:", .{pipeline_state.objc_id});
    }

    pub fn setVertexBuffer(self: RenderCommandEncoder, vertex_buffer: Buffer, offset: u32, index: u32) void {
        _ = call_(self.objc_id, "setVertexBuffer:offset:atIndex:", .{ vertex_buffer.objc_id, offset, index });
    }

    pub fn setVertexBytes(self: RenderCommandEncoder, bytes: *const c_void, length: u32, index: u32) void {
        _ = call_(self.objc_id, "setVertexBytes:length:atIndex:", .{ bytes, length, index });
    }

    pub fn drawIndexedPrimitives(self: RenderCommandEncoder, primitive_type: PrimitiveType, index_count: u64, index_type: IndexType, index_buffer: Buffer, index_buffer_offset: u32) void {
        _ = call_(self.objc_id, "drawIndexedPrimitives:indexCount:indexType:indexBuffer:indexBufferOffset:", .{ @enumToInt(primitive_type), index_count, @enumToInt(index_type), index_buffer.objc_id, index_buffer_offset });
    }

    pub fn endEncoding(self: RenderCommandEncoder) void {
        _ = call(self.objc_id, "endEncoding");
    }
};

const Buffer = struct {
    objc_id: c.id,

    pub fn contents(self: Buffer) *c_void {
        return call(self.objc_id, "contents");
    }
};

pub fn createVertexDescriptor() VertexDescriptor {
    const vertex_descriptor = class("MTLVertexDescriptor");
    return VertexDescriptor{ .objc_id = call(vertex_descriptor, "vertexDescriptor") };
}

const VertexDescriptor = struct {
    objc_id: c.id,

    pub fn attributes(self: VertexDescriptor) VertexAttributeDescriptorArray {
        return VertexAttributeDescriptorArray{ .objc_id = call(self.objc_id, "attributes") };
    }

    pub fn layouts(self: VertexDescriptor) VertexBufferLayoutDescriptorArray {
        return VertexBufferLayoutDescriptorArray{ .objc_id = call(self.objc_id, "layouts") };
    }
};

const VertexAttributeDescriptorArray = struct {
    objc_id: c.id,

    pub fn objectAt(self: VertexAttributeDescriptorArray, index: u32) VertexAttributeDescriptor {
        return VertexAttributeDescriptor{ .objc_id = call_(self.objc_id, "objectAtIndexedSubscript:", .{index}) };
    }
};

// https://developer.apple.com/documentation/metal/mtlvertexformat?language=objc
pub const VertexFormat = enum(u32) {
    Float3 = 30,
};

const VertexAttributeDescriptor = struct {
    objc_id: c.id,

    pub fn setFormat(self: VertexAttributeDescriptor, format: VertexFormat) void {
        _ = call_(self.objc_id, "setFormat:", .{@enumToInt(format)});
    }

    pub fn setOffset(self: VertexAttributeDescriptor, offset: u64) void {
        _ = call_(self.objc_id, "setOffset:", .{offset});
    }

    pub fn setBufferIndex(self: VertexAttributeDescriptor, buffer_index: u32) void {
        _ = call_(self.objc_id, "setBufferIndex:", .{buffer_index});
    }
};

const VertexBufferLayoutDescriptorArray = struct {
    objc_id: c.id,

    pub fn objectAt(self: VertexBufferLayoutDescriptorArray, index: u32) VertexBufferLayoutDescriptor {
        return VertexBufferLayoutDescriptor{ .objc_id = call_(self.objc_id, "objectAtIndexedSubscript:", .{index}) };
    }
};

// https://developer.apple.com/documentation/metal/mtlvertexstepfunction?language=objc
pub const VertexStepFunction = enum(u32) {
    Constant = 0,
    PerVertex = 1,
    PerInstance = 2,
};

const VertexBufferLayoutDescriptor = struct {
    objc_id: c.id,

    pub fn setStepFunction(self: VertexBufferLayoutDescriptor, step_function: VertexStepFunction) void {
        _ = call_(self.objc_id, "setStepFunction:", .{@enumToInt(step_function)});
    }

    pub fn setStepRate(self: VertexBufferLayoutDescriptor, step_rate: u32) void {
        _ = call_(self.objc_id, "setStepRate:", .{step_rate});
    }

    pub fn setStride(self: VertexBufferLayoutDescriptor, stride: u64) void {
        _ = call_(self.objc_id, "setStride:", .{stride});
    }
};

const Library = struct {
    objc_id: c.id,

    pub fn newFunction(self: Library, function_name: [*:0]const u8) Function {
        const string = createNSString(function_name);
        return Function{ .objc_id = call_(self.objc_id, "newFunctionWithName:", .{string})};
    }
};

const Function = struct {
    objc_id: c.id,
};

pub fn createRenderPipelineDescriptor() RenderPipelineDescriptor {
    const render_pipeline_descriptor = class("MTLRenderPipelineDescriptor");
    return RenderPipelineDescriptor{ .objc_id = call(call(render_pipeline_descriptor, "alloc"), "init")};
}

const RenderPipelineDescriptor = struct {
    objc_id: c.id,

    pub fn setVertexFunction(self: RenderPipelineDescriptor, vertex_function: Function) void {
        _ = call_(self.objc_id, "setVertexFunction:", .{vertex_function.objc_id});
    }

    pub fn setFragmentFunction(self: RenderPipelineDescriptor, fragment_function: Function) void {
        _ = call_(self.objc_id, "setFragmentFunction:", .{fragment_function.objc_id});
    }

    pub fn setVertexDescriptor(self: RenderPipelineDescriptor, vertex_descriptor: VertexDescriptor) void {
        _ = call_(self.objc_id, "setVertexDescriptor:", .{vertex_descriptor.objc_id});
    }

    pub fn colorAttachments(self: RenderPipelineDescriptor) RenderPipelineColorAttachmentDescriptorArray {
        return RenderPipelineColorAttachmentDescriptorArray{ .objc_id = call(self.objc_id, "colorAttachments") };
    }
};

const RenderPipelineColorAttachmentDescriptorArray = struct {
    objc_id: c.id,

    pub fn objectAt(self: RenderPipelineColorAttachmentDescriptorArray, index: u32) RenderPipelineColorAttachmentDescriptor {
        return RenderPipelineColorAttachmentDescriptor{ .objc_id = call_(self.objc_id, "objectAtIndexedSubscript:", .{index}) };
    }
};

// https://developer.apple.com/documentation/metal/mtlpixelformat?language=objc
pub const PixelFormat = enum(u32) {
    BGRA8Unorm = 80,
};

const RenderPipelineColorAttachmentDescriptor = struct {
    objc_id: c.id,

    pub fn setPixelFormat(self: RenderPipelineColorAttachmentDescriptor, pixel_format: PixelFormat) void {
        _ = call_(self.objc_id, "setPixelFormat:", .{@enumToInt(pixel_format)});
    }
};

const RenderPipelineState = struct {
    objc_id: c.id,
};



