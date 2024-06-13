//
//  GestureRecognizer.swift
//  ARchesster
//
//  Created by admin on 13.06.2024.
//

import Foundation

protocol GestureWatcher {
    func gestureSwitched(to: Bool)
    func startPosition(on point: CGPoint?)
    func updatePosition(on point: CGPoint?)
    func finishPosition(on point: CGPoint?)
}

class GestureRecognizer {
    
    static let shared = GestureRecognizer()
    
    var isHolding = false {
        didSet {
            watcher?.gestureSwitched(to: isHolding)
        }
    }
    
    var gesturePoint: CGPoint?
    
    var watcher: GestureWatcher?
    
    func grab(on point: CGPoint?) {
        isHolding = true
        gesturePoint = point
        watcher?.startPosition(on: point)
    }
    
    func move(on point: CGPoint?) {
        gesturePoint = point
        watcher?.updatePosition(on: point)
    }
    
    func ungrab(on point: CGPoint?) {
        isHolding = false
        gesturePoint = point
        watcher?.finishPosition(on: point)
    }
    
}
