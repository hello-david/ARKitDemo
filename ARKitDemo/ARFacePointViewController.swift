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

let kARKitFacePointCount = 1220
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
        descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0, 0.0, 0.0)
        return descriptor
    }()
    
    private lazy var captureRenderView: MTKView = {
        let view = MTKView(frame: CGRect.zero, device: self.device)
        view.delegate = self
        view.isPaused = true
        return view
    }()
    
    private lazy var facePointRenderView: MTKView = {
        let view = MTKView(frame: CGRect.zero, device: self.device)
        view.delegate = self
        view.isPaused = true
        view.isOpaque = false
        return view
    }()
    
    private lazy var faceRenderPielineState: MTLRenderPipelineState? = {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = self.shaderLibrary??.makeFunction(name: "facePointVertex")
        descriptor.fragmentFunction = self.shaderLibrary??.makeFunction(name: "facePointFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add;
        descriptor.colorAttachments[0].alphaBlendOperation = .add;
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha;
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha;
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha;
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha;
        return (try? self.device?.makeRenderPipelineState(descriptor: descriptor)) ?? nil
    }()
    
    private lazy var faceRenderPassDecriptor: MTLRenderPassDescriptor = {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0, 0.0, 0.0)
        return descriptor
    }()
    
    private var faceMeshUniformBufferAddress: UnsafeMutableRawPointer!
    private var faceMeshUniformBuffer: MTLBuffer!
    private var facePointsBufferAddress: UnsafeMutableRawPointer!
    private var facePointsBuffer: MTLBuffer!
    private var indexLabels:[UILabel] = []
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        UIApplication.shared.isIdleTimerDisabled = true
        view.addSubview(captureRenderView)
        view.addSubview(facePointRenderView)
        session.run(ARFaceTrackingConfiguration(), options: [.resetTracking, .removeExistingAnchors])
        
        faceMeshUniformBuffer = self.device?.makeBuffer(length: (MemoryLayout<FaceMeshUniforms>.size & ~0xFF) + 0x100, options: .storageModeShared)
        faceMeshUniformBuffer.label = "FaceMeshUniformBuffer"
        
        facePointsBuffer = self.device?.makeBuffer(length: (MemoryLayout<vector_float3>.stride * kARKitFacePointCount), options: [])
        facePointsBuffer.label = "FacePointBuffer"
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        captureRenderView.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height)
        facePointRenderView.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height)
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
        guard let drawable = view.currentDrawable else { return }
        
        if view.isEqual(captureRenderView) {
            guard let textureY = capturedImageTextureY, let textureCbCr = capturedImageTextureCbCr else {
                return
            }
            
            renderPassDecriptor.colorAttachments[0].texture = drawable.texture
            guard let commandBuffer = commandQueue?.makeCommandBuffer() else { return }
            guard  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDecriptor) else { return }
            commandBuffer.enqueue()
            
            renderEncoder.setRenderPipelineState(renderPielineState!)
            renderEncoder.setVertexBuffer(positionCoordinateBuffer!, offset: 0, index: Int(kBufferIndexPostionCoordinates.rawValue))
            renderEncoder.setVertexBuffer(textureCoordinateBuffer!, offset: 0, index: Int(kBufferIndexTextureCoordinates.rawValue))
            renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureY), index: Int(kTextureIndexY.rawValue))
            renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureCbCr), index: Int(kTextureIndexCbCr.rawValue))
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
        if view.isEqual(facePointRenderView) {
            faceRenderPassDecriptor.colorAttachments[0].texture = drawable.texture
            guard let commandBuffer = commandQueue?.makeCommandBuffer() else { return }
            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: faceRenderPassDecriptor) else { return }
            commandBuffer.enqueue()
            
            renderEncoder.setRenderPipelineState(faceRenderPielineState!)
            renderEncoder.setVertexBuffer(facePointsBuffer, offset: 0, index: Int(kBufferIndexGenerics.rawValue))
            renderEncoder.setVertexBuffer(faceMeshUniformBuffer, offset: 0, index: Int(kBufferIndexFaceMeshUniforms.rawValue))
            renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: kARKitFacePointCount)
            renderEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
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
//        captureRenderView.draw()
        
        // 拿人脸拓扑
        if let faceAnchor = frame.anchors.first as? ARFaceAnchor {
            faceMeshUniformBufferAddress = faceMeshUniformBuffer.contents()
            let uniforms = faceMeshUniformBufferAddress.assumingMemoryBound(to: FaceMeshUniforms.self)
            uniforms.pointee.viewMatrix = frame.camera.viewMatrix(for: .portrait)
            uniforms.pointee.projectionMatrix = frame.camera.projectionMatrix(for: .portrait,
                                                                              viewportSize: facePointRenderView.frame.size,
                                                                              zNear: 0.001, zFar: 1000)
            uniforms.pointee.modelMatrix = faceAnchor.transform
            
            facePointsBufferAddress = facePointsBuffer.contents()
            for index in 0..<faceAnchor.geometry.vertices.count {
                let curPointAddr = facePointsBufferAddress.assumingMemoryBound(to: vector_float3.self).advanced(by: index)
                curPointAddr.pointee = faceAnchor.geometry.vertices[index]
            }
            facePointRenderView.draw()
            
            for label in indexLabels {
                label.removeFromSuperview()
            }
            indexLabels.removeAll()
            for index in 0..<faceAnchor.geometry.vertices.count {
                let facePoint = uniforms.pointee.projectionMatrix * uniforms.pointee.viewMatrix * uniforms.pointee.modelMatrix * vector_float4(faceAnchor.geometry.vertices[index], 1.0)
                let label = UILabel(frame: CGRect.zero)
                label.text = String(format: "%ld", index)
                label.font = UIFont(name: "PingFangSC-Regular", size: 5)
                label.sizeToFit()
                label.center = CGPoint(x: CGFloat(facePoint.x/facePoint.w + 1.0)/2.0 * facePointRenderView.frame.size.width,
                                       y: CGFloat(-facePoint.y/facePoint.w + 1.0)/2.0 * facePointRenderView.frame.size.height)
                view.addSubview(label)
                indexLabels.append(label)
            }
        }
    }
}
