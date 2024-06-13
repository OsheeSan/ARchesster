//
//  GestureRecognizer.swift
//  ARchesster
//
//  Created by admin on 13.06.2024.
//

import Foundation

protocol GestureWatcher {
    func gestureSwitched(to: Bool)
}

class GestureRecognizer {
    
    static let shared = GestureRecognizer()
    
    var isHolding = false
    
    var gestureGrabPoint: CGPoint?
    
    var gestureUngrabPoint: CGPoint?
    
    var watcher: GestureWatcher?
    
    func grab(on point: CGPoint?) {
        isHolding = true
        gestureGrabPoint = point
        watcher?.gestureSwitched(to: true)
    }
    
    func ungrab(on point: CGPoint?) {
        isHolding = false
        gestureUngrabPoint = point
        watcher?.gestureSwitched(to: false)
    }
    
}
