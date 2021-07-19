//
//  PermissionController.swift
//  HandTrackingDemo
//
//  Created by 盧彥辰 on 2021/7/13.
//

import Foundation
import Photos
import UIKit

class PermissionController: NSObject {
    var permissionCompletionBlock: ((Bool?) -> Void)?
}

extension PermissionController {
    
    
    func checkPermission(completion: @escaping (Bool?) -> Void) {
        self.permissionCompletionBlock = completion
    }
    
    //確認相機權限
    func cameraPermission() {
        let mediaType = AVMediaType.video
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: mediaType)
        switch authorizationStatus {
        case .notDetermined: //沒做選擇
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (granted: Bool) in
                DispatchQueue.main.async(execute: { () -> Void in
                    self.cameraPermission()
                })
            })
            break
        case .authorized: //已授權
            self.permissionCompletionBlock?(true)
            break
        case .denied: //拒絕授權
            self.permissionCompletionBlock?(false)
            break
        default:
            break
        }
    }
    
    func settingPermission() -> UIAlertController {

        let alertController = UIAlertController(title: "",
                                                message: "請開啟相機權限",
                                                preferredStyle: .alert)
        
        let okAction = UIAlertAction(title:"確認", style: .default, handler: {
            (action) -> Void in
            
        })
        
        alertController.addAction(okAction)
            
        return alertController
    }
}
