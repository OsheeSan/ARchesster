//
//  PositionUpdate.swift
//  ARchesster
//
//  Created by Danylo Burliai on 18.06.2024.
//

import Foundation
import ARKit

class PositionUpdate: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { return true }
    
    func encode(with coder: NSCoder) {
        guard let encodedAnchor = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) else {
            return
        }
        
        coder.encode(encodedAnchor, forKey: "anchor")
        coder.encode(position.x, forKey: "x")
        coder.encode(position.y, forKey: "y")
        coder.encode(position.z, forKey: "z")
    }
    
    required convenience init?(coder: NSCoder) {
        guard let decodedAnchor = coder.decodeObject(forKey: "anchor") as? Data,
              let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARAnchor.self, from: decodedAnchor)
        else {
            return nil
        }
        
        let position = SCNVector3(x: coder.decodeFloat(forKey: "x"),
                                  y: coder.decodeFloat(forKey: "y"),
                                  z: coder.decodeFloat(forKey: "z"))
        
        self.init(anchor: anchor, position: position)
    }
    
    init(anchor: ARAnchor, position: SCNVector3) {
        self.anchor = anchor
        self.position = position
        
        super.init()
    }
    
    public let anchor: ARAnchor
    public let position: SCNVector3
}
