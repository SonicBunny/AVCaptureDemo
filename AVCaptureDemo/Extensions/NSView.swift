//
//  NSView.swift
//  AVCaptureDemo
//
//  Created by Jay Lyerly on 11/29/23.
//

import Cocoa

extension NSView {
    func addSubViewEdgeToEdge(_ subview: NSView) {
        self.addSubview(subview)
        subview.translatesAutoresizingMaskIntoConstraints = false
        
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[subview]|",
                                                           options: [],
                                                           metrics: nil,
                                                           views: ["subview": subview]))
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[subview]|",
                                                           options: [],
                                                           metrics: nil,
                                                           views: ["subview": subview]))
    }
    
    func removeSubViews() {
        for subview in subviews {
            subview.removeFromSuperview()
        }
    }
    
}
