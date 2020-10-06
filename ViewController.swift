//
//  ViewController.swift
//  testmetalview2
//
//  Created by Dev on 2020-10-05.
//  Copyright © 2020 Novurix. All rights reserved.
//

import Cocoa
import MetalKit

class ViewController: NSViewController {

    var mtkView: MTKView!
    var renderer: Rendering!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mtkView = MTKView()
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(mtkView)
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[mtkView]|", options: [], metrics: nil, views: ["mtkView" : mtkView]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[mtkView]|", options: [], metrics: nil, views: ["mtkView" : mtkView]))
        
        let device = MTLCreateSystemDefaultDevice()!
        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm
        
        renderer = Rendering(view: mtkView, device: device)
        mtkView.delegate = renderer
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}
