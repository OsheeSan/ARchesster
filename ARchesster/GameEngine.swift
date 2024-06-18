//
//  GameEngine.swift
//  ARchesster
//
//  Created by Danylo Burliai on 14.06.2024.
//

import Foundation
import ARKit
import MultipeerConnectivity

class GameEngine: NSObject {
    public static var Instance: GameEngine {
        get {
            return .instance
        }
    }
    
    private override init() {
        super.init()
        
        GestureRecognizer.shared.watcher = self
        multipeerSession = MultipeerSession(delegate: self)
    }
    
    private static let instance = GameEngine()
    
    private var sceneView: ARSCNView! // don't kill me I don't want to write guard let in every func
    private var cameraRotation: simd_float3?
    
    private var movableNode: SCNNode?
    private var prevLocation = CGPointZero
    
    private var spawnedAnchors: [ARAnchor] = []
    
    private var multipeerSession: MultipeerSession!
    
    public static func setSceneView(_ sceneView: ARSCNView) {
        instance.setSceneView(sceneView)
    }
    
    public func setSceneView(_ sceneView: ARSCNView) {
        sceneView.delegate = self
        sceneView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onTap(_:))))
        sceneView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(onPan(_:))))
        self.sceneView = sceneView
    }
    
    public static func setCameraRotation(_ rotation: simd_float3) {
        instance.setCameraRotation(rotation)
    }
    
    public func setCameraRotation(_ rotation: simd_float3) {
        cameraRotation = rotation
    }
    
    public static func spawn(node named: String, atScreenLocation location: CGPoint) -> ARAnchor? {
        guard let res = instance.sceneView.hitTest(location, types: .existingPlaneUsingExtent).first else {
            return nil
        }
        
        let anchor = ARAnchor(name: "rook-dark", transform: res.worldTransform)
        instance.sceneView.session.add(anchor: anchor)
        
        return anchor
    }
    
    public static func loadNodeModel(node named: String) -> SCNReferenceNode {
        let sceneURL = Bundle.main.url(forResource: named, withExtension: "scn", subdirectory: "Assets.scnassets")!
        let referenceNode = SCNReferenceNode(url: sceneURL)!
        referenceNode.load()
        
        return referenceNode
    }
    
    @objc
    private func onTap(_ gestureRecognizer: UITapGestureRecognizer) {
        if let anchor = GameEngine.spawn(node: "rook-dark", atScreenLocation: gestureRecognizer.location(in: sceneView)) {
            spawnedAnchors.append(anchor)
            sceneView.session.add(anchor: anchor)
            multipeerSession.sendToAllPeers(anchor, with: .reliable)
        }
    }
    
    @objc
    private func onPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        let location = gestureRecognizer.location(in: sceneView)
        switch gestureRecognizer.state { // add trace and camera rotation
        case .began:
            let hit = sceneView.hitTest(location, options: nil)
            if let node = hit.first?.node,
                let anchor = sceneView.anchor(for: node),
                spawnedAnchors.contains(anchor) {
                movableNode = node
                prevLocation = location
            }
        case .changed:
            guard let movableNode else {
                return
            }
            
            var delta = (location - prevLocation).unit() / 100
            delta = delta.rotate(by: (cameraRotation?.y ?? 0) * -1)
            movableNode.position.x += Float(delta.x)
            movableNode.position.z += Float(delta.y) // why th z is not corresponding for height
        case .ended, .cancelled, .failed:
            movableNode = nil
            prevLocation = CGPointZero
        default:
            return
        }
    }
}

extension GameEngine: GestureWatcher {
    func gestureSwitched(to: Bool) {
        
    }
    
    func startPosition(on point: CGPoint?) {
        guard let point else {
            print("no point")
            return
        }
        
        let hit = sceneView.hitTest(point, options: nil)
        //print(hit.count)
        if let res = hit.first, let _ = res.node.name {
            movableNode = res.node
            let nodePos = CGPoint(x: CGFloat(res.node.position.x), y: CGFloat(res.node.position.z))
            let worldPos = CGPoint(x: CGFloat(res.worldCoordinates.x), y: CGFloat(res.worldCoordinates.z))
            prevLocation = nodePos - worldPos
        }
    }
    
    func updatePosition(on point: CGPoint?) {
        guard let point else {
            print("no point")
            return
        }
        
        guard let res = sceneView.hitTest(point, types: .existingPlaneUsingExtent).first else {
            return
        }
        
        movableNode?.position.x = res.worldTransform.columns.3[0] + Float(prevLocation.x)
        movableNode?.position.z = res.worldTransform.columns.3[2] + Float(prevLocation.y)
    }
    
    func finishPosition(on point: CGPoint?) {
        movableNode = nil
        prevLocation = CGPointZero
    }
}

extension GameEngine: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let planeAnchor = anchor as? ARPlaneAnchor {
            let plane = Plane(anchor: planeAnchor, in: sceneView)
            node.addChildNode(plane)
            return
        }
        
        if let name = anchor.name {
            let spawnedRef = GameEngine.loadNodeModel(node: name)
            node.addChildNode(spawnedRef)
        }
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

extension GameEngine: MultipeerSessionDelegate {
    func receivedData(_ data: Data, from peer: MCPeerID) {
        if let decoded = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARAnchor.self, from: data) {
            anchorReceived(decoded)
        }
    }
    
    func anchorReceived(_ anchor: ARAnchor) {
        sceneView.session.add(anchor: anchor)
    }
}
