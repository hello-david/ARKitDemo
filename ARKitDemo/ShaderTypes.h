//
//  ShaderTypes.h
//  ARKitDemo
//
//  Created by David.Dai on 2020/4/22.
//  Copyright © 2020 david.dai. All rights reserved.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

typedef enum BufferIndices {
    kBufferIndexPostionCoordinates = 0,
    kBufferIndexTextureCoordinates = 1,
    kBufferIndexFaceMeshUniforms = 2,
    kBufferIndexGenerics = 3
} BufferIndices;

typedef enum TextureIndices {
    kTextureIndexColor    = 0,
    kTextureIndexY        = 1,
    kTextureIndexCbCr     = 2
} TextureIndices;

typedef struct {
    simd_float4x4 projectionMatrix;
    simd_float4x4 viewMatrix;
    simd_float4x4 modelMatrix;
} FaceMeshUniforms;

#endif /* ShaderTypes_h */
