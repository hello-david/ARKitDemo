//
//  ViewController.swift
//  ARKitDemo
//
//  Created by David.Dai on 2019/2/22.
//  Copyright © 2019 david.dai. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    private lazy var dataSource: [[String]] = {
        return [["图像检测", "嘴唇贴图"],
                ["人脸点位置"]]
    }()
    
    private let tableView: UITableView  = {
        let tableView = UITableView.init(frame: CGRect.zero, style: UITableView.Style.grouped)
        tableView.register(UITableViewCell.classForCoder(), forCellReuseIdentifier: "cell")
        return tableView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(tableView)
        tableView.frame = self.view.frame
        tableView.delegate = self
        tableView.dataSource = self
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource[section].count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "ARKit检测+SenKit渲染"
        }
        
        if section == 1 {
            return "ARKit检测+Metal渲染"
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = dataSource[indexPath.section][indexPath.row]
        cell.textLabel?.font = UIFont.init(name: "PingFangSC-Regular", size: 14)
        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.cellForRow(at: indexPath)?.setSelected(false, animated: true)
        
        if indexPath.section == 0 {
            switch indexPath.row {
            case 0:
                navigationController?.pushViewController(ImageDetectViewController(), animated: true)
                break
            case 1:
                navigationController?.pushViewController(ARFaceLipsViewController(), animated: true)
                break
            default: break
            }
        }
        
        if indexPath.section == 1 {
            switch indexPath.row {
            case 0:
                navigationController?.pushViewController(ARFacePointViewController(), animated: true)
                break
            default: break
            }
        }
    }
}
