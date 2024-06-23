//
//  ARAnchorExtension.swift
//  ARchesster
//
//  Created by Danylo Burliai on 23.06.2024.
//

import Foundation
import ARKit

extension ARAnchor {
    var rotationAngle: Float {
        simd_quatf(transform).angle
    }
}
