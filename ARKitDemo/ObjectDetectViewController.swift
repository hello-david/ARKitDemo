//
//  ObjectDetectViewController.swift
//  ARKitDemo
//
//  Created by David.Dai on 2019/2/22.
//  Copyright © 2019 david.dai. All rights reserved.
//

import UIKit
import ARKit

class ObjectDetectViewController: UIViewController {
    // 这个是一个整合SceneKit渲染和ARKit检测的视图
    private lazy var arSceneView: ARSCNView = {
        let view = ARSCNView()
        return view
    }()
    
    private var session: ARSession {
        return arSceneView.session
    }
}
