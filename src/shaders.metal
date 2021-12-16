#include <metal_stdlib>

using namespace metal;

struct VertexIn
{
  float3 position [[attribute(0)]];
};

struct VertexOut
{
  float4 position [[position]];
};

vertex VertexOut render_vertex(VertexIn v_in [[stage_in]],
                               constant float4x4& mvp_matrix [[buffer(1)]])
{
  VertexOut out;
  out.position = mvp_matrix * float4(v_in.position, 1.0);
  return out;
}

fragment float4 render_fragment(VertexOut f_in [[stage_in]]) 
{
  return float4(0.0, 1.0, 0.0, 1.0);
}
