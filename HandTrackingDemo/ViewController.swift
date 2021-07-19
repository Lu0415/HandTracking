//
//  ViewController.swift
//  HandTrackingDemo
//
//  Created by 盧彥辰 on 2021/7/7.
//

import UIKit
import Vision
import AVFoundation

class ViewController: UIViewController {
    
    let permissionController = PermissionController()
    let cameraController = CameraController()
    //var m_visionView: VisionView!

    @IBOutlet var capturePreviewView: UIView!
    @IBOutlet var visionView: VisionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        configurPermissionController()
    }
    
    func configureCameraController() {
        cameraController.prepare { [self] (error) in
            if let error = error {
                print("configureCameraController Error", error)
            }
            
            try? cameraController.displayPreview(on: capturePreviewView)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1000)) { [self] in
            switchCamera()
        }
        
        drawVisionCGPoint()
    }

    func configurPermissionController() {
        
        permissionController.checkPermission { [self] (agree) in
            
            if agree! {
                configureCameraController()
            } else {
                showSettingPermissionAlert()
            }
        }
        permissionController.cameraPermission()
    }
    
    func showSettingPermissionAlert() {
        DispatchQueue.main.async(execute: { [self] () -> Void in
            present(permissionController.settingPermission(), animated: true, completion: nil)
        })
    }
    
    func switchCamera() {
        
        do {
            try cameraController.switchCameras()
        } catch {
            print(error)
        }
    }
    
    func drawVisionCGPoint() {
        cameraController.returnVisionCGPoint { [self] (pointArray) in
            //print("pointArray = ", pointArray)
            visionView.showPoints(pointArray ?? [])
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.navigationBar.isHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.navigationController?.navigationBar.isHidden = false
    }
    
    private let handPoseRequest: VNDetectHumanHandPoseRequest = {
        // 1
        let request = VNDetectHumanHandPoseRequest()
        
        // 2
        request.maximumHandCount = 2
        return request
    }()
}


extension ViewController {
    
}
