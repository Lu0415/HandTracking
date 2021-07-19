//
//  CameraController.swift
//  HandTrackingDemo
//
//  Created by 盧彥辰 on 2021/7/7.
//

import UIKit
import AVFoundation
import Vision

class CameraController: NSObject {
    var captureSession: AVCaptureSession?
    
    var currentCameraPosition: CameraPosition?
    
    var frontCamera: AVCaptureDevice?
    var frontCameraInput: AVCaptureDeviceInput?
    
    var photoOutput: AVCapturePhotoOutput?
    
    var rearCamera: AVCaptureDevice?
    var rearCameraInput: AVCaptureDeviceInput?
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var flashMode = AVCaptureDevice.FlashMode.off
    var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
    
    private let videoDataOutputQueue = DispatchQueue(label: "CameraFeedDataOutput", qos: .userInteractive)
    var restingHand = true
    var visionCGPointBlock: (([CGPoint]?) -> Void)?
    var m_previewLayer = AVCaptureVideoPreviewLayer()
    
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
}

extension CameraController {
    
    func prepare(completionHandler: @escaping (Error?) -> Void) {
        func createCaptureSession() {
            self.captureSession = AVCaptureSession()
        }
        
        func configureCaptureDevices() throws {
            let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
//            let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera], mediaType: AVMediaType.video, position: .unspecified)
            
            let cameras = session.devices.compactMap { $0 }
            guard !cameras.isEmpty else { throw CameraControllerError.noCamerasAvailable }
            
            for camera in cameras {
                if camera.position == .front {
                    self.frontCamera = camera
                }
                
                if camera.position == .back {
                    self.rearCamera = camera
                    
                    try camera.lockForConfiguration()
                    camera.focusMode = .continuousAutoFocus
                    camera.unlockForConfiguration()
                }
            }
        }
        
        func configureDeviceInputs() throws {
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
            if let rearCamera = self.rearCamera {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                
                if captureSession.canAddInput(self.rearCameraInput!) {
                    captureSession.addInput(self.rearCameraInput!)
                }
                
                self.currentCameraPosition = .rear
            } else if let frontCamera = self.frontCamera {
                self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                
                if captureSession.canAddInput(self.frontCameraInput!) {
                    captureSession.addInput(self.frontCameraInput!)
                } else {
                    throw CameraControllerError.inputsAreInvalid
                }
                
                self.currentCameraPosition = .front
            } else {
                throw CameraControllerError.noCamerasAvailable
            }
        }
        
        func configurePhotoOutput() throws {
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
            self.photoOutput = AVCapturePhotoOutput()
            self.photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
            
            if captureSession.canAddOutput(self.photoOutput!) {
                captureSession.addOutput(self.photoOutput!)
            }
            captureSession.startRunning()
            
            ///
            let dataOutput = AVCaptureVideoDataOutput()
            if captureSession.canAddOutput(dataOutput) {
                captureSession.addOutput(dataOutput)
                // Add a video data output.
                dataOutput.alwaysDiscardsLateVideoFrames = true
                dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
                dataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            } else {
                //throw AppError.captureSessionSetup(reason: "Could not add video data output to the session")
                print("Could not add video data output to the session")
            }
            captureSession.commitConfiguration()
            ///
        }
        
        
        
        DispatchQueue(label: "prepare").async {
            do {
                createCaptureSession()
                try configureCaptureDevices()
                try configureDeviceInputs()
                try configurePhotoOutput()
            }
                
            catch {
                DispatchQueue.main.async {
                    completionHandler(error)
                }
                
                return
            }
            
            DispatchQueue.main.async {
                completionHandler(nil)
            }
        }
    }
    
    func displayPreview(on view: UIView) throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.previewLayer?.connection?.videoOrientation = .portrait
        
        view.layer.insertSublayer(self.previewLayer!, at: 0)
        self.previewLayer?.frame = view.frame
        
    }
    
    func switchCameras() throws {
        guard let currentCameraPosition = currentCameraPosition, let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        captureSession.beginConfiguration()
        
        func switchToFrontCamera() throws {
            
            guard let rearCameraInput = self.rearCameraInput, captureSession.inputs.contains(rearCameraInput),
                let frontCamera = self.frontCamera else { throw CameraControllerError.invalidOperation }
            
            self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            
            captureSession.removeInput(rearCameraInput)
            
            if captureSession.canAddInput(self.frontCameraInput!) {
                captureSession.addInput(self.frontCameraInput!)
                
                self.currentCameraPosition = .front
            } else {
                throw CameraControllerError.invalidOperation
            }
        }
        
        func switchToRearCamera() throws {
            
            guard let frontCameraInput = self.frontCameraInput, captureSession.inputs.contains(frontCameraInput),
                let rearCamera = self.rearCamera else { throw CameraControllerError.invalidOperation }
            
            self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
            
            captureSession.removeInput(frontCameraInput)
            
            if captureSession.canAddInput(self.rearCameraInput!) {
                captureSession.addInput(self.rearCameraInput!)
                
                self.currentCameraPosition = .rear
            } else {
                throw CameraControllerError.invalidOperation
            }
        }
        
        switch currentCameraPosition {
        case .front:
            try switchToRearCamera()
            
        case .rear:
            try switchToFrontCamera()
        }
        
        captureSession.commitConfiguration()
    }
    
    func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {
        guard let captureSession = captureSession, captureSession.isRunning else {
            completion(nil, CameraControllerError.captureSessionIsMissing); return
        }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
        self.photoCaptureCompletionBlock = completion
    }
    
    func returnVisionCGPoint(completion: @escaping ([CGPoint]?) -> Void) {
        self.visionCGPointBlock = completion
    }

}

extension CameraController: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error == nil {
            let imageData = photo.fileDataRepresentation()
            if let image = UIImage(data: imageData!) {
                self.photoCaptureCompletionBlock?(image, nil)
            } else {
                self.photoCaptureCompletionBlock?(nil, CameraControllerError.unknown)
            }
        } else {
            self.photoCaptureCompletionBlock?(nil, error)
        }
    }
    
    /*
    public func photoOutput(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?,
                        resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Swift.Error?) {
        if let error = error {
            self.photoCaptureCompletionBlock?(nil, error)
        } else if let buffer = photoSampleBuffer, let data = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: buffer, previewPhotoSampleBuffer: nil),
            let image = UIImage(data: data) {
            
            self.photoCaptureCompletionBlock?(image, nil)
        } else {
            self.photoCaptureCompletionBlock?(nil, CameraControllerError.unknown)
        }
    }
    */
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //print("有嗎")
        var thumbTip: CGPoint?
        var wrist: CGPoint?
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        do {
            // Perform VNDetectHumanHandPoseRequest
            try handler.perform([handPoseRequest])
            guard let observation = handPoseRequest.results?.first else {
//                cameraView.showPoints([])
                self.visionCGPointBlock?([])
                return
            }
            // Get points for all fingers
            let thumbPoints = try observation.recognizedPoints(.thumb)
            let wristPoints = try observation.recognizedPoints(.all)
            let indexFingerPoints = try observation.recognizedPoints(.indexFinger)
            let middleFingerPoints = try observation.recognizedPoints(.middleFinger)
            let ringFingerPoints = try observation.recognizedPoints(.ringFinger)
            let littleFingerPoints = try observation.recognizedPoints(.littleFinger)
            // Extract individual points from Point groups.
            guard let thumbTipPoint = thumbPoints[.thumbTip],
                  let indexTipPoint = indexFingerPoints[.indexTip],
                  let middleTipPoint = middleFingerPoints[.middleTip],
                  let ringTipPoint = ringFingerPoints[.ringTip],
                  let littleTipPoint = littleFingerPoints[.littleTip],
                  let wristPoint = wristPoints[.wrist]
            else {
//                cameraView.showPoints([])
                self.visionCGPointBlock?([])
                return
            }
            let confidenceThreshold: Float = 0.3
            guard   thumbTipPoint.confidence > confidenceThreshold &&
                        indexTipPoint.confidence > confidenceThreshold &&
                        middleTipPoint.confidence > confidenceThreshold &&
                        ringTipPoint.confidence > confidenceThreshold &&
                        littleTipPoint.confidence > confidenceThreshold &&
                        wristPoint.confidence > confidenceThreshold
            else {
//                cameraView.showPoints([])
                self.visionCGPointBlock?([])
                return
            }
            // Convert points from Vision coordinates to AVFoundation coordinates.
            thumbTip = CGPoint(x: thumbTipPoint.location.x, y: 1 - thumbTipPoint.location.y)
            wrist = CGPoint(x: wristPoint.location.x, y: 1 - wristPoint.location.y)
            DispatchQueue.main.async {
                self.processPoints([thumbTip, wrist])
            }
        } catch {
            captureSession?.stopRunning()
            print("VNImageRequestHandler Error = ", error)
        }
    }
    
    func processPoints(_ points: [CGPoint?]) {
        
        // Convert points from AVFoundation coordinates to UIKit coordinates.
//         = cameraView.previewLayer
        var pointsConverted: [CGPoint] = []
        for point in points {
            //pointsConverted.append(m_previewLayer.layerPointConverted(fromCaptureDevicePoint: point!))
            pointsConverted.append(previewLayer!.layerPointConverted(fromCaptureDevicePoint: point!))
        }
        
        let thumbTip = pointsConverted[0]
        let wrist = pointsConverted[pointsConverted.count - 1]
        
        //let xDistance  = thumbTip.x - wrist.x
        let yDistance  = thumbTip.y - wrist.y
        
        if (yDistance > 50) {
            
            
            if self.restingHand {
                print("👎")
                self.restingHand = false
                //self.handDelegate?.thumbsDown()
            }
            
        } else if (yDistance < -50) {
            
            if self.restingHand {
                
                print("👍")
                self.restingHand = false
                //self.handDelegate?.thumbsUp()
            }
        } else {
            print("✋")
            self.restingHand = true
        }
        
        //cameraView.showPoints(pointsConverted)
        self.visionCGPointBlock?(pointsConverted)
    }
}

extension CameraController {
    enum CameraControllerError: Swift.Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
    
    public enum CameraPosition {
        case front
        case rear
    }
}
