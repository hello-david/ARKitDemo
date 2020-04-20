//
//  Shader.metal
//  ARKitDemo
//
//  Created by David.Dai on 2020/4/20.
//  Copyright © 2020 david.dai. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct SingleInputVertexIO {
    float4 position [[position]];
    float2 textureCoordinate [[user(texturecoord)]];
};

float4 ycbcrToRGBTransform(float4 y, float4 CbCr) {
    const float4x4 ycbcrToRGBTransform = float4x4(
      float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
      float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
      float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
      float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
    );

    float4 ycbcr = float4(y.r, CbCr.rg, 1.0);
    return ycbcrToRGBTransform * ycbcr;
}

vertex SingleInputVertexIO oneInputVertex(const device packed_float2 *position [[buffer(0)]],
                                          const device packed_float2 *texturecoord [[buffer(1)]],
                                          uint vid [[vertex_id]]) {
    SingleInputVertexIO outputVertices;
    outputVertices.position = float4(position[vid], 0, 1.0);
    outputVertices.textureCoordinate = texturecoord[vid];
    return outputVertices;
}

// 直接渲染yuv
fragment float4 capturedImageFragment(SingleInputVertexIO in [[stage_in]],
                                      texture2d<float, access::sample> capturedImageTextureY [[ texture(1) ]],
                                      texture2d<float, access::sample> capturedImageTextureCbCr [[ texture(2) ]]) {
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);
    
    return ycbcrToRGBTransform(capturedImageTextureY.sample(colorSampler, in.textureCoordinate),
                               capturedImageTextureCbCr.sample(colorSampler, in.textureCoordinate));
}

// 渲染纹理
fragment half4 passthroughFragment(SingleInputVertexIO fragmentInput [[stage_in]],
                                   texture2d<half> inputTexture [[texture(0)]]) {
    constexpr sampler quadSampler;
    half4 color = inputTexture.sample(quadSampler, fragmentInput.textureCoordinate);
    return color;
}
