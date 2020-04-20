//
//  MetalTool.swift
//  ARKitDemo
//
//  Created by David.Dai on 2020/4/20.
//  Copyright © 2020 david.dai. All rights reserved.
//

import Foundation
import CoreGraphics

struct MetalCoordinate {
    let bottomLeft: (Float, Float)
    let bottomRight: (Float, Float)
    let topLeft: (Float, Float)
    let topRight: (Float, Float)
}

enum MetalContentMode {
    case scaleToFill     // 拉伸图像，铺满全部渲染空间
    case scaleAspectFit  // 缩放图像，保持比例，可能不会填充满整个区域
    case scaleAspectFill // 缩放图像，保持比例，会填充整个区域
}

func texturePosition(fromSize: CGSize, toSize: CGSize, contenMode: MetalContentMode) -> MetalCoordinate {
    var heightScaling: CGFloat = 0.0
    var widthScaling: CGFloat = 0.0
    let aspectSize = makeRectWithAspectRatio(fromSize, toSize).size
    switch contenMode {
    case .scaleToFill:
        widthScaling = 1.0
        heightScaling = 1.0
        break
        
    case .scaleAspectFit:
        widthScaling = aspectSize.width / toSize.width
        heightScaling = aspectSize.height / toSize.height
        break
        
    case .scaleAspectFill:
        widthScaling = toSize.height / aspectSize.height
        heightScaling = toSize.width / aspectSize.width
        break
    }

    return MetalCoordinate(bottomLeft: (Float(-widthScaling), Float(-heightScaling)),
                           bottomRight: (Float(widthScaling), Float(-heightScaling)),
                           topLeft: (Float(-widthScaling), Float(heightScaling)),
                           topRight: (Float(widthScaling), Float(heightScaling)))
}

func makeRectWithAspectRatio(_ srcSize: CGSize, _ destSize: CGSize) -> CGRect {
    let srcAspectRatio = srcSize.width / srcSize.height
    let destApectRatio = destSize.width / destSize.height
    
    var resultHeight: CGFloat = 0, resultWidth: CGFloat = 0
    if srcAspectRatio > destApectRatio {
        resultWidth = destSize.width
        resultHeight = srcSize.height / (srcSize.width / resultWidth)
    }
    else {
        resultHeight = destSize.height
        resultWidth = srcSize.width / (srcSize.height / resultHeight)
    }
    
    return CGRect(x: (destSize.width - resultWidth) / 2.0,
                  y: (destSize.height - resultHeight) / 2.0,
                  width: resultWidth,
                  height: resultHeight)
}
