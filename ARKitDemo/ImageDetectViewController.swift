//
//  ImageDetectViewController.swift
//  ARKitDemo
//
//  Created by David.Dai on 2019/2/22.
//  Copyright © 2019 david.dai. All rights reserved.
//

import UIKit
import ARKit

class ImageDetectViewController: UIViewController {
    // 这个是一个整合SceneKit渲染和ARKit检测的视图
    private lazy var arSceneView: ARSCNView = {
        let view = ARSCNView()
        view.delegate = self
        view.session.delegate = self
        return view
    }()
    
    private var session: ARSession {
        return arSceneView.session
    }
    
    let renderQueue = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".ImageRenderQueue")
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        UIApplication.shared.isIdleTimerDisabled = true
        
        view.addSubview(arSceneView)
        arSceneView.frame = view.frame
        
        let apple = UIImage.init(data: NSData.init(contentsOfFile: Bundle.main.path(forResource: "apple", ofType: "png", inDirectory: "Resource/Images")!)! as Data)
        let google = UIImage.init(data: NSData.init(contentsOfFile: Bundle.main.path(forResource: "google", ofType: "png", inDirectory: "Resource/Images")!)! as Data)
        
        // 配置ARKit Session
        let arImages = detectImages([apple!, google!], name: ["apple", "google"])
        let configure = ARWorldTrackingConfiguration()
        configure.detectionImages = arImages
        session.run(configure, options: [.resetTracking, .removeExistingAnchors])
    }
    
    // MARK: - Private
    private func detectImages(_ images: [UIImage], name: [String]) -> Set<ARReferenceImage> {
        var refrenceImages: Set<ARReferenceImage> = Set()
        for image in images {
            let referenceImage = ARReferenceImage.init(image.cgImage!, orientation: CGImagePropertyOrientation.up, physicalWidth: image.size.width)
            referenceImage.name = name[images.firstIndex(of: image)!]
            refrenceImages.insert(referenceImage)
        }
        return refrenceImages
    }
}

// MARK: - Delegate
extension ImageDetectViewController: ARSessionDelegate {    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }
}

extension ImageDetectViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // 获取当前识别到的特征图像
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        let referenceImage = imageAnchor.referenceImage
        
        renderQueue.async {
            // 获取当前检测到的平面
            let plane = SCNPlane(width: referenceImage.physicalSize.width, height: referenceImage.physicalSize.height)
            
            // 创建一个效果节点
            let effectNode = SCNNode(geometry: plane)
            effectNode.opacity = 0.25
            
            /*
             `SCNPlane` is vertically oriented in its local coordinate space, but
             `ARImageAnchor` assumes the image is horizontal in its local space, so
             rotate the plane to match.
             */
            effectNode.eulerAngles.x = -.pi / 2
            
            // 添加节点动作(动画)
            effectNode.opacity = 0.25
            effectNode.runAction(self.imageHighlightAction)
            effectNode.name = referenceImage.name
            
            // 添加这个节点到空间中
            node.addChildNode(effectNode)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // 获取当前识别到的特征图像
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        let referenceImage = imageAnchor.referenceImage
        
        // 获取附着在这个特征图像平面上的效果节点
        let effectNode = node.childNode(withName: referenceImage.name ?? "", recursively: true)
        effectNode?.opacity = 0.25
        effectNode?.runAction(self.imageHighlightAction)
    }
    
    var imageHighlightAction: SCNAction {
        return .sequence([
            .wait(duration: 0.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOpacity(to: 0.15, duration: 0.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOut(duration: 0.5)])
    }
}
