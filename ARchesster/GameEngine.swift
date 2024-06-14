//
//  GameEngine.swift
//  ARchesster
//
//  Created by Danylo Burliai on 14.06.2024.
//

import Foundation
import ARKit

class GameEngine: NSObject {
    public static var Instance: GameEngine {
        get {
            return .instance
        }
    }
    
    private override init() { super.init() }
    private static let instance = GameEngine()
    
    private var sceneView: ARSCNView! // don't kill me I don't want to write guard let in every func
    
    public static func setSceneView(_ sceneView: ARSCNView) {
        instance.setSceneView(sceneView)
    }
    
    public func setSceneView(_ sceneView: ARSCNView) {
        sceneView.delegate = self
        sceneView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap(_:))))
        self.sceneView = sceneView
    }
    
    public static func spawn(node named: String, atScreenLocation location: CGPoint) -> SCNNode? {
        guard let res = instance.sceneView.hitTest(location, types: .existingPlaneUsingExtent).first else {
            print("no res trace")
            return nil
        }
        
        return spawn(node: named, atWorldTransform: res.worldTransform)
    }
    
    public static func spawn(node named: String, atWorldTransform transform: simd_float4x4) -> SCNNode? {
        let vec = SCNVector3(transform.columns.3[0], transform.columns.3[1], transform.columns.3[2])
        
        return spawn(node: named, atLocation: vec)
    }
    
    public static func spawn(node named: String, atLocation location: SCNVector3) -> SCNNode? {
        let scene = SCNScene(named: "Assets.scnassets/\(named).scn")
        
        guard let node = scene?.rootNode.childNodes.first else {
            print("can't extract node")
            return nil
        }
        
        node.position = location
        //node.setWorldTransform(SCNMatrix4(res.worldTransform)) // but why does this not work....
        instance.sceneView.scene.rootNode.addChildNode(node)
        return node
    }
    
    @objc
    private func onTap(_ gestureRecognizer: UITapGestureRecognizer) {
        let _ = GameEngine.spawn(node: "rook-dark", atScreenLocation: gestureRecognizer.location(in: sceneView))
    }
}

extension GameEngine: GestureWatcher {
    func gestureSwitched(to: Bool) {
        
    }
    
    func startPosition(on point: CGPoint?) {
        
    }
    
    func updatePosition(on point: CGPoint?) {
        
    }
    
    func finishPosition(on point: CGPoint?) {
        
    }
}

extension GameEngine: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor, let sceneView else { return }
        
        let plane = Plane(anchor: planeAnchor, in: sceneView)
        
        node.addChildNode(plane)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Update only anchors and nodes set up by `renderer(_:didAdd:for:)`.
        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let plane = node.childNodes.first as? Plane
            else { return }
        
        // Update ARSCNPlaneGeometry to the anchor's new estimated shape.
        if let planeGeometry = plane.meshNode.geometry as? ARSCNPlaneGeometry {
            planeGeometry.update(from: planeAnchor.geometry)
        }

        // Update extent visualization to the anchor's new bounding rectangle.
        if let extentGeometry = plane.extentNode.geometry as? SCNPlane {
            extentGeometry.width = CGFloat(planeAnchor.extent.x)
            extentGeometry.height = CGFloat(planeAnchor.extent.z)
            plane.extentNode.simdPosition = planeAnchor.center
        }
    }
}
