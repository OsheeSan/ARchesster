//
//  ViewController.swift
//  ARchesster
//
//  Created by admin on 06.06.2024.
//

import UIKit
import SceneKit
import ARKit
import Vision
import AVFoundation

let USE_DEPTH = false
let TIME_OUT = 100

class ViewController: UIViewController, ARSessionDelegate {
    
    var sceneView: ARSCNView!
    
    let viewBackgroundColor: UIColor = UIColor.black
    
    var configuration: ARWorldTrackingConfiguration?
    
    var gestureRecognizer = GestureRecognizer.shared
    
    // Hand Detection
    var currentBuffer: CVPixelBuffer?
    var handPoseRequest = VNDetectHumanHandPoseRequest()
    let visionQueue = DispatchQueue(label: "handVisionQueue")
    
    var lefthandnode: HandNode?
    var righthandnode: HandNode?
    
    var timeoutleft = TIME_OUT
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        sceneView = ARSCNView(frame: view.frame)
        view.addSubview(sceneView)
        GameEngine.Instance.setSceneView(sceneView)
        sceneView.session.delegate = self
        sceneView.showsStatistics = false
        
        self.view.backgroundColor = viewBackgroundColor
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        configuration = ARWorldTrackingConfiguration()
        
        configuration!.planeDetection = .horizontal
        
        if USE_DEPTH && ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration?.frameSemantics.insert(.personSegmentationWithDepth)
        } else {
            print("No people occlusion supported.")
        }
        
        configuration?.isCollaborationEnabled = true
        
        configuration?.environmentTexturing = .automatic
        
        sceneView.session.run(configuration!)
        
        handPoseRequest.maximumHandCount = 1        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard currentBuffer == nil, case .normal = frame.camera.trackingState else {
            return
        }
        
        self.currentBuffer = frame.capturedImage
        classifyHand()
    }
    
    func classifyHand() {
        var templefthandobs: VNHumanHandPoseObservation?
        let handler = VNImageRequestHandler(cvPixelBuffer: currentBuffer!, orientation: .left)
        visionQueue.async {
            do {
                defer {
                    self.currentBuffer = nil
                    
                    self.processPoints(newhandobs: templefthandobs, handnode: &self.lefthandnode, timeout: &self.timeoutleft, color: UIColor.white)
                }
                
                try handler.perform([self.handPoseRequest])
                guard let obs1 = self.handPoseRequest.results?.first else {
                    return
                }
                
                if obs1.chirality == .left {
                    templefthandobs = obs1
                    
                    if self.isOKGesture(handObservation: templefthandobs) {
                        if !self.gestureRecognizer.isHolding {
                            self.gestureRecognizer.grab(on: self.gesturePoint(handObservation: templefthandobs))
                        } else {
                            self.gestureRecognizer.move(on: self.gesturePoint(handObservation: templefthandobs))
                        }
                    } else {
                        if self.gestureRecognizer.isHolding {
                            self.gestureRecognizer.ungrab(on: self.gesturePoint(handObservation: templefthandobs))
                        }
                    }
                    
                }
                
                if self.handPoseRequest.results?.count == 1 {
                    return
                }
                
            } catch {
                print("Error: Vision request failed with error \"\(error)\"")
            }
        }
        
    }
    
    func gesturePoint(handObservation: VNHumanHandPoseObservation?) -> CGPoint? {
        guard let handObservation = handObservation else {
            print("Error gesture")
            return nil
        }
        
        do {
            let thumbTip = try handObservation.recognizedPoint(.thumbTip)
            let indexTip = try handObservation.recognizedPoint(.indexTip)
            
            let midX = (thumbTip.x + indexTip.x) / 2
            let midY = (thumbTip.y + indexTip.y) / 2
            
            return CGPoint(x: midX, y: midY)
        } catch {
            print("Error pos")
            return nil
        }
    }
    
    func isOKGesture(handObservation: VNHumanHandPoseObservation?) -> Bool {
        guard let handObservation = handObservation else {
            print("Error hand")
            return false
        }
        
        do {
            let thumbTip = try handObservation.recognizedPoint(.thumbTip)
            let indexTip = try handObservation.recognizedPoint(.indexTip)
            
            let distance = hypot(thumbTip.location.x - indexTip.location.x, thumbTip.location.y - indexTip.location.y)
            
            return distance < 0.1
        } catch {
            print("Error pos")
            return false
        }
    }
    
    func processPoints(newhandobs: VNHumanHandPoseObservation?, handnode: inout HandNode?, timeout: inout Int, color: UIColor) {
        if newhandobs != nil {
            if handnode == nil {
                handnode = HandNode(color: color)
            }
            
            if handnode!.parent == nil {
                self.sceneView.scene.rootNode.addChildNode(handnode!)
            }
            let (newconst, _) = handnode!.createConstraints(pose: newhandobs!, camera: sceneView.session.currentFrame!.camera)
            handnode!.addConstraint(peerID: "", constraints: newconst)
            handnode!.applyConstraints()
            
            timeout = TIME_OUT
        } else if handnode != nil {
            if timeout > 0 {
                timeout -= 1
            } else {
                handnode!.removeFromParentNode()
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.resetTracking()
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func resetTracking() {
        guard let configuration = sceneView.session.configuration else { print("A configuration is required"); return }
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    private func removeAllAnchorsOriginatingFromARSessionWithID(_ identifier: String) {
        guard let frame = sceneView.session.currentFrame else { return }
        for anchor in frame.anchors {
            guard let anchorSessionID = anchor.sessionIdentifier else { continue }
            if anchorSessionID.uuidString == identifier {
                sceneView.session.remove(anchor: anchor)
            }
        }
    }
}

