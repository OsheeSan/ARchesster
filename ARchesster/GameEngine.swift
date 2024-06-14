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
    
    private override init() {
        super.init()
        
        GestureRecognizer.shared.watcher = self
    }
    
    private static let instance = GameEngine()
    
    private var sceneView: ARSCNView! // don't kill me I don't want to write guard let in every func
    
    private var movableNode: SCNNode?
    private var prevLocation = CGPointZero
    
    public static func setSceneView(_ sceneView: ARSCNView) {
        instance.setSceneView(sceneView)
    }
    
    public func setSceneView(_ sceneView: ARSCNView) {
        sceneView.delegate = self
        sceneView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap(_:))))
        sceneView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(onPan(_:))))
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
        if let movableNode {
            return
        }
        
        print(gestureRecognizer.location(in: sceneView))
        movableNode = GameEngine.spawn(node: "rook-dark", atScreenLocation: gestureRecognizer.location(in: sceneView))
    }
    
    @objc
    private func onPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let location = gestureRecognizer.location(in: sceneView)
        switch gestureRecognizer.state { // add trace and camera rotation
        case .began:
            prevLocation = location
        case .changed:
            let delta = (prevLocation - location) / 200.0
            movableNode?.position.x += Float(delta.x)
            movableNode?.position.z += Float(delta.y)
        case .ended, .cancelled, .failed:
            print("end")
        default:
            return
        }
    }
}

extension GameEngine: GestureWatcher {
    func gestureSwitched(to: Bool) {
        
    }
    
    func startPosition(on point: CGPoint?) {
        print(point!)
        guard let movableNode, let point else {
            print("no figure")
            return
        }
        
        let hit = sceneView.hitTest(point, options: [SCNHitTestOption.searchMode : 1])
        //print(hit.count)
        if movableNode == hit.first?.node {
            print("found")
        }
        // trace and try to find movable node
    }
    
    func updatePosition(on point: CGPoint?) {
        // calc delta and update position (take camera rotation into consideration)
    }
    
    func finishPosition(on point: CGPoint?) {
        // end??
    }
}

extension GameEngine: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
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
