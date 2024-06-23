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
    
    private var panMovableNode: SCNNode?
    private var panPrevLocation = CGPointZero
    
    private var gestureMovableNode: SCNNode?
    private var gestureOffset = CGPointZero
    
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
        
        let anchor = ARAnchor(name: named, transform: res.worldTransform)
        instance.sceneView.session.add(anchor: anchor)
        
        return anchor
    }
    
    public static func loadChessBoard() -> SCNNode {
        let box = SCNBox(width: 1, height: 0.1, length: 1, chamferRadius: 0)
        
        let material = SCNMaterial()
        material.diffuse.contents = UIImage(named: "chessboard")
        
        let node = SCNNode()
        node.geometry = box
        node.geometry?.materials = [material]
        return node
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
                panMovableNode = node
                panPrevLocation = location
            }
        case .changed:
            guard let panMovableNode,
                  let anchor = sceneView.anchor(for: panMovableNode)
            else {
                return
            }
            
            var delta = (location - panPrevLocation).unit() / 100
            delta = delta.rotate(by: (cameraRotation?.y ?? 0) * -1)
            delta = delta.rotate(by: -anchor.rotationAngle)
            panMovableNode.position.x += Float(delta.x)
            panMovableNode.position.z += Float(delta.y) // why th z is not corresponding for height
            multipeerSession.sendToAllPeers(PositionUpdate(anchor: anchor, position: panMovableNode.position), with: .unreliable)
        case .ended, .cancelled, .failed:
            guard let panMovableNode,
                  let anchor = sceneView.anchor(for: panMovableNode)
            else {
                return
            }
            
            multipeerSession.sendToAllPeers(PositionUpdate(anchor: anchor, position: panMovableNode.position), with: .reliable)
            self.panMovableNode = nil
            panPrevLocation = CGPointZero
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
        if let res = hit.first,
           let anchor = sceneView.anchor(for: res.node),
           spawnedAnchors.contains(anchor) {
            gestureMovableNode = res.node
            let nodePos = CGPoint(x: CGFloat(res.node.position.x), y: CGFloat(res.node.position.z))
            let worldPos = CGPoint(x: CGFloat(res.worldCoordinates.x), y: CGFloat(res.worldCoordinates.z))
            gestureOffset = nodePos - worldPos
        }
    }
    
    func updatePosition(on point: CGPoint?) {
        guard let point else {
            print("no point")
            return
        }
        
        guard let gestureMovableNode,
              let anchor = sceneView.anchor(for: gestureMovableNode)
        else {
            return
        }
        
        guard let res = sceneView.hitTest(point, types: .existingPlaneUsingExtent).first else {
            return
        }
        
        var newLocation = CGPoint(x: CGFloat(res.worldTransform.columns.3[0] + Float(gestureOffset.x)),
                                  y: CGFloat(res.worldTransform.columns.3[2] + Float(gestureOffset.y)))
        newLocation = newLocation.rotate(by: -anchor.rotationAngle)
        gestureMovableNode.position.x = Float(newLocation.x)
        gestureMovableNode.position.z = Float(newLocation.y)
        multipeerSession.sendToAllPeers(PositionUpdate(anchor: anchor, position: gestureMovableNode.position), with: .unreliable)
    }
    
    func finishPosition(on point: CGPoint?) {
        guard let gestureMovableNode,
              let anchor = sceneView.anchor(for: gestureMovableNode)
        else {
            return
        }
        
        multipeerSession.sendToAllPeers(PositionUpdate(anchor: anchor, position: gestureMovableNode.position), with: .reliable)
        self.gestureMovableNode = nil
        gestureOffset = CGPointZero
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
            return
        }
        if let decoded = try? NSKeyedUnarchiver.unarchivedObject(ofClass: PositionUpdate.self, from: data) {
            positionUpdateReceived(decoded)
            return
        }
    }
    
    func anchorReceived(_ anchor: ARAnchor) {
        sceneView.session.add(anchor: anchor)
    }
    
    func positionUpdateReceived(_ positionUpdate: PositionUpdate) {
        if let node = sceneView.node(for: positionUpdate.anchor)?.childNodes.first {
            node.position = positionUpdate.position
        }
    }
}
