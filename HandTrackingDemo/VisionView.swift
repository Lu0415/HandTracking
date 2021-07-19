//
//  VisionView.swift
//  HandTrackingDemo
//
//  Created by 盧彥辰 on 2021/7/13.
//

import UIKit
import AVFoundation

class VisionView: UIView {
    
    private var overlayThumbLayer = CAShapeLayer()
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupOverlay()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOverlay()
    }
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        if layer == previewLayer {
            overlayThumbLayer.frame = layer.bounds
        }
    }
    
    private func setupOverlay() {
        
        previewLayer.addSublayer(overlayThumbLayer)
    }
    
    func showPoints(_ points: [CGPoint]) {
        
        guard let wrist: CGPoint = points.last else {
            // Clear all CALayers
            clearLayers()
            return
        }
        let thumbColor = UIColor.green
        drawFinger(overlayThumbLayer, Array(points[0...1]), thumbColor, wrist)
    }
    
    func drawFinger(_ layer: CAShapeLayer, _ points: [CGPoint], _ color: UIColor, _ wrist: CGPoint) {
        let fingerPath = UIBezierPath()
        print("這裏 2 [CGPoint] = ", points)
        for point in points {
            fingerPath.move(to: point)
            fingerPath.addArc(withCenter: point, radius: 5, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        }
        
        fingerPath.move(to: points[0])
        fingerPath.addLine(to: points[points.count - 1])
        
        layer.fillColor = color.cgColor
        layer.strokeColor = color.cgColor
        layer.lineWidth = 5.0
        layer.lineCap = .round
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.path = fingerPath.cgPath
        CATransaction.commit()
        
        self.layer.addSublayer(layer)
    }
    
    func clearLayers() {
        let emptyPath = UIBezierPath()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        overlayThumbLayer.path = emptyPath.cgPath
        CATransaction.commit()
    }
    
    
}
