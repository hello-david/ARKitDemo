//
//  ARFaceLipsViewController.swift
//  ARKitDemo
//
//  Created by David.Dai on 2019/3/12.
//  Copyright © 2019 david.dai. All rights reserved.
//

import UIKit
import ARKit

class ARFaceLipsViewController: UIViewController {
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
    
    let renderQueue = DispatchQueue(label: Bundle.main.bundleIdentifier! + ".ARFaceRenderQueue")
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        UIApplication.shared.isIdleTimerDisabled = true
        
        view.addSubview(arSceneView)
        arSceneView.frame = view.frame
        session.run(ARFaceTrackingConfiguration(), options: [.resetTracking, .removeExistingAnchors])
    }
}

// MARK: - Delegate
extension ARFaceLipsViewController: ARSessionDelegate {
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }
}

extension ARFaceLipsViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
       
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // 更新节点上的人脸拓扑
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        let currentFaceGeometry = node.geometry as! ARSCNFaceGeometry
        currentFaceGeometry.update(from: faceAnchor.geometry)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let device = self.arSceneView.device else { return nil }
        
        // 将获取的人脸拓扑结构换成SCNNode
        guard let faceSCNGeometry = ARSCNFaceGeometry(device: device, fillMesh: false) else { return nil }
        let node = SCNNode(geometry: faceSCNGeometry)
        
        // 1.将拓扑结构用线画出
        node.geometry?.firstMaterial?.fillMode = .lines

        // 2.基于wireframeTexture这张标准图(官方Demo中)，进行纹理贴图
        let path = Bundle.main.path(forResource: "mouse", ofType: "png", inDirectory: "Resource/Images")!
        let wireframeTexture = UIImage.init(data: NSData.init(contentsOfFile: path)! as Data)
        node.geometry?.firstMaterial?.diffuse.contents = wireframeTexture
        node.geometry?.firstMaterial?.lightingModel = .physicallyBased

        return node
    }
}
