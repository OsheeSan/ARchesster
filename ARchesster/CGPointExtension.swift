//
//  CGPointExtension.swift
//  ARchesster
//
//  Created by Danylo Burliai on 14.06.2024.
//

import Foundation

extension CGPoint {
    static func -(_ left: CGPoint, _ right: CGPoint) -> CGPoint {
        CGPoint(x: left.x - right.x, y: left.y - right.y)
    }
    
    static func /(_ left: CGPoint, _ right: Float) -> CGPoint {
        CGPoint(x: left.x / CGFloat(right), y: left.y / CGFloat(right))
    }
}
