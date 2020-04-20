//
//  ARFacePointViewController.swift
//  ARKitDemo
//
//  Created by David.Dai on 2020/4/20.
//  Copyright © 2020 david.dai. All rights reserved.
//

import UIKit
import ARKit
import Metal
import MetalKit

class ARFacePointViewController: UIViewController {
    // MARK: - ARKit
    private lazy var session: ARSession = {
        let arSession = ARSession()
        arSession.delegate = self
        return arSession
    }()
    private var capturedImageTextureY: CVMetalTexture?
    private var capturedImageTextureCbCr: CVMetalTexture?
    private lazy var capturedImageTextureCache: CVMetalTextureCache? = {
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device!, nil, &textureCache)
        return textureCache
    }()
    
    // MARK: - Metal渲染
    private lazy var device =  { return MTLCreateSystemDefaultDevice() }()
    private lazy var commandQueue = { return self.device?.makeCommandQueue() }()
    private lazy var shaderLibrary = { return try? self.device?.makeLibrary(URL: Bundle.main.url(forResource: "default", withExtension: "metallib")!) }()
    private var arFrameSize: CGSize = CGSize(width: 1080, height: 1920)
    
    private lazy var positionCoordinateBuffer: MTLBuffer? = {
        let position = texturePosition(fromSize: arFrameSize, toSize: UIScreen.main.bounds.size, contenMode: .scaleAspectFill)
        let positionCoordinateData = [position.bottomLeft.0, position.bottomLeft.1,
                                      position.bottomRight.0, position.bottomRight.1,
                                      position.topLeft.0, position.topLeft.1,
                                      position.topRight.0, position.topRight.1]
        
        let count = positionCoordinateData.count * MemoryLayout<Float>.size
        return self.device?.makeBuffer(bytes: positionCoordinateData,
                                       length: count,
                                       options: [])
    }()
    
    private lazy var textureCoordinateBuffer: MTLBuffer? = {
        // 直接填上旋转后的纹理坐标
        let textureCoordinateData: [Float] = [1.0, 1.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0]
        let count = textureCoordinateData.count * MemoryLayout<Float>.size
        return self.device?.makeBuffer(bytes: textureCoordinateData,
                                       length: count,
                                       options: [])
    }()
    
    private lazy var renderPielineState: MTLRenderPipelineState? = {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = self.shaderLibrary??.makeFunction(name: "oneInputVertex")
        descriptor.fragmentFunction = self.shaderLibrary??.makeFunction(name: "capturedImageFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        return (try? self.device?.makeRenderPipelineState(descriptor: descriptor)) ?? nil
    }()
    
    private lazy var renderPassDecriptor: MTLRenderPassDescriptor = {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0, 0.0, 1.0)
        return descriptor
    }()
    
    private lazy var renderView: MTKView = {
        let view = MTKView(frame: CGRect.zero, device: self.device)
        view.delegate = self
        view.isPaused = true
        return view
    }()
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        UIApplication.shared.isIdleTimerDisabled = true
        view.addSubview(renderView)
        session.run(ARFaceTrackingConfiguration(), options: [.resetTracking, .removeExistingAnchors])
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        renderView.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height)
    }
}

extension ARFacePointViewController {
    private func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        
        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, capturedImageTextureCache!,
                                                               pixelBuffer, nil, pixelFormat,
                                                               width, height, planeIndex, &texture)
        if status != kCVReturnSuccess {
            texture = nil
        }
        return texture
    }
}

extension ARFacePointViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        // 渲染流程
        guard let drawable = view.currentDrawable else { return }
        guard let textureY = capturedImageTextureY, let textureCbCr = capturedImageTextureCbCr else {
            return
        }
        
        renderPassDecriptor.colorAttachments[0].texture = drawable.texture
        let commandBuffer = commandQueue?.makeCommandBuffer()
        let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDecriptor)
        commandBuffer?.enqueue()
        
        renderEncoder?.setRenderPipelineState(renderPielineState!)
        renderEncoder?.setVertexBuffer(positionCoordinateBuffer!, offset: 0, index: 0)
        renderEncoder?.setVertexBuffer(textureCoordinateBuffer!, offset: 0, index: 1)
        renderEncoder?.setFragmentTexture(CVMetalTextureGetTexture(textureY), index: 1)
        renderEncoder?.setFragmentTexture(CVMetalTextureGetTexture(textureCbCr), index: 2)
        renderEncoder?.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder?.endEncoding()
        
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
}

extension ARFacePointViewController: ARSessionDelegate {
    // 获取ARKit相机画面
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let pixelBuffer = frame.capturedImage
        if CVPixelBufferGetPlaneCount(pixelBuffer) < 2 {
            return
        }
        
        capturedImageTextureY = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .r8Unorm, planeIndex: 0)
        capturedImageTextureCbCr = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .rg8Unorm, planeIndex: 1)
        
        // 图像是旋转的，需要把宽高换一下
        arFrameSize = CGSize(width: CVPixelBufferGetHeight(frame.capturedImage), height: CVPixelBufferGetWidth(frame.capturedImage))
        renderView.draw()
    }
}
