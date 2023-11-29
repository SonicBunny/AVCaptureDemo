//
//  MetalImageView.swift
//  AVCaptureDemo
//
//  Created by Jay Lyerly on 11/29/23.
//

import MetalKit

// Adapted from https://gist.github.com/muukii/fbb523538e14bc4c75a2

class MetalImageView: MTKView {
    
    // Cache the bounds for use off the main thread
    private var cachedBounds = CGRect.zero
    override var frame: NSRect {
        didSet {
            cachedBounds = bounds
        }
    }
    
    var image: CIImage? {
        didSet {
            DispatchQueue.main.async {
                self.draw()
            }
        }
    }
    
    let context: CIContext
    let commandQueue: MTLCommandQueue?
    
    var scaleFactor: CGFloat { window?.backingScaleFactor ?? 1.0 }
    
    convenience init(frame: CGRect) {
        let device = MTLCreateSystemDefaultDevice()
        self.init(frame: frame, device: device)
    }
    
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        guard let device = device else {
            fatalError("Can't use Metal")
        }
        commandQueue = device.makeCommandQueue(maxCommandBufferCount: 5)
        context = CIContext(mtlDevice: device, options: [CIContextOption.useSoftwareRenderer: false])
        super.init(frame: frameRect, device: device)
        
        framebufferOnly = false
        enableSetNeedsDisplay = false
        isPaused = true
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        autoResizeDrawable = true
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    override func draw(_ rect: CGRect) {
        
        guard let image = self.image else {
            return
        }
        
        let scaledRect = rect
            .applying(CGAffineTransform(scaleX: scaleFactor,
                                        y: scaleFactor))
        
        let scaleX = scaledRect.width / image.extent.width
        let scaleY = scaledRect.height / image.extent.height
        let scale = min(scaleX, scaleY)
        let drawImage = image
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        let imageRect = drawImage.extent
        
        // Calculate the targetRect, centered in the view
        let targetRect: CGRect
        if scaleX > scaleY {
            let deltaX = (scaledRect.width - imageRect.width) / 2.0
            targetRect = scaledRect.insetBy(dx: -1 * deltaX, dy: 0)
        } else {
            let deltaY = (scaledRect.height - imageRect.height) / 2.0
            targetRect = scaledRect.insetBy(dx: 0, dy: -1 * deltaY)
        }
 
        let commandBuffer = commandQueue?.makeCommandBufferWithUnretainedReferences()
        guard let texture = currentDrawable?.texture else {
            return
        }
        let colorSpace = drawImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()

        // draw solid black background over the whole rect first
        let backgroundSize = CGRect(origin: .zero, size: drawableSize)
            .applying(CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
        let blackImage = CIImage(color: CIColor(red: 0, green: 0, blue: 0))
            .cropped(to: backgroundSize)
        context.render(blackImage,
                       to: texture,
                       commandBuffer: commandBuffer,
                       bounds: backgroundSize,
                       colorSpace: colorSpace)

        // draw our image centered (targetRect) in the space (rect)
        context.render(drawImage, to: texture, commandBuffer: commandBuffer, bounds: targetRect, colorSpace: colorSpace)
        
        if let drawable = currentDrawable {
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
    }
    
}
