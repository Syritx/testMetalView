import Cocoa
import MetalKit

class ViewController: NSViewController {
    
    //MARK: VARS
    var mtkView: MTKView!
    var renderer: Rendering!
    
    override var acceptsFirstResponder: Bool { return true }
    override func becomeFirstResponder() -> Bool { return true }
    override func resignFirstResponder() -> Bool { return true }
    
    //MARK: KEYBOARD
    override func keyDown(with event: NSEvent) {
        if (event.keyCode == 13) {
            print("w")
            renderer.position.z += 1*renderer.speed
        }
        else if (event.keyCode == 1) {
            print("s")
            renderer.position.z -= 1*renderer.speed
        }
    }
    
    //MARK: MAIN
    override func viewDidLoad() {
        super.viewDidLoad()
                
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (aEvent) -> NSEvent? in
            self.keyDown(with: aEvent)
            return nil
        }
        
        mtkView = MTKView()
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(mtkView)
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[mtkView]|", options: [], metrics: nil, views: ["mtkView" : mtkView]))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[mtkView]|", options: [], metrics: nil, views: ["mtkView" : mtkView]))
        
        title = "Rotating Container"
        preferredContentSize.width = 1000
        preferredContentSize.height = 720
        
        let device = MTLCreateSystemDefaultDevice()!
        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm
        
        renderer = Rendering(view: mtkView, device: device)
        mtkView.delegate = renderer
    }
    
    override var representedObject: Any? {
        didSet {}
    }
}
