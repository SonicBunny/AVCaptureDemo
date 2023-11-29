//
//  AVController.swift
//  AVCaptureDemo
//
//  Created by Jay Lyerly on 11/29/23.
//

import Foundation
import AVFoundation
import CoreImage

protocol AVControllerDelegate: AnyObject {
    func didCaptureImage(_ image: CIImage)
}

class AVController: NSObject {
    
    private var device: AVCaptureDevice
    var devices: [AVCaptureDevice]
    private var session = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    var dataOutput = AVCaptureVideoDataOutput()
    private let camQueue = DispatchQueue(label: "CameraQueue", qos: .userInteractive)
    
    weak var delegate: AVControllerDelegate?
    
    override init() {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [ .builtInWideAngleCamera, .external ],
            mediaType: .video,
            position: .unspecified
        )
        devices = deviceDiscoverySession.devices
        device = devices.first!
        
        super.init()
    }
        
    func start() {
        prepForCapture()
        session.startRunning()
    }
    
    func stop() {
        session.stopRunning()
    }
    
    func change(toDevice device: AVCaptureDevice?) {
        guard let device else { return }
        
        stop()
        self.device = device
        start()
    }
    
}

extension AVController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ captureOutput: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
                
        autoreleasepool {
            if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
                
                let image = CIImage(cvPixelBuffer: imageBuffer)
                delegate?.didCaptureImage(image)
                
                CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
            }
        }
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput,
                       didDrop sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        assertionFailure("Failed to capture output.")
    }
}


extension AVController {
    private func prepForCapture() {
        dataOutput = AVCaptureVideoDataOutput()
        session = AVCaptureSession()
        
        dataOutput.alwaysDiscardsLateVideoFrames = true
        dataOutput.setSampleBufferDelegate(self, queue: camQueue)
        
        if session.canAddOutput(dataOutput) {
            session.addOutput(dataOutput)
        } else {
            print("Can't add dataOutput to session")
        }
        
        session.beginConfiguration()
        
        if let videoDeviceInput = videoDeviceInput {
            session.removeInput(videoDeviceInput)
        }
        
        videoDeviceInput = try? AVCaptureDeviceInput(device: device)
        
        guard let videoDeviceInput = videoDeviceInput else {
            print("Failed to create videoDeviceInput")
            session.commitConfiguration()
            return
        }
        
        session.sessionPreset = AVCaptureSession.Preset.high
        if session.canAddInput(videoDeviceInput) {
            session.addInput(videoDeviceInput)
        }
        
        configureGeneric()
        configureFrameRate()
        session.commitConfiguration()
    }
    
    func configureFrameRate() {
        // call this _after_ setting a preferred format
        do {
            try device.lockForConfiguration()
            
            let frameRates = device.activeFormat.videoSupportedFrameRateRanges
            let sortedFrameRates = frameRates.sorted {
                return $0.maxFrameRate < $1.maxFrameRate
            }
            
            if let selectedFrameRate = sortedFrameRates.last {
                device.activeVideoMinFrameDuration = selectedFrameRate.minFrameDuration
                device.activeVideoMaxFrameDuration = selectedFrameRate.maxFrameDuration
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Failed to configure framerate:\(device)")
        }
    }
    
    func findPreferredFormat(device: AVCaptureDevice) -> AVCaptureDevice.Format? {
                
        var prefFormat: AVCaptureDevice.Format?

        if let firstFormat = device.formats.first {
            var selectedFormat = firstFormat
            var selectedSize = CMVideoFormatDescriptionGetDimensions(firstFormat.formatDescription)
            var selectedPixelCount = selectedSize.height * selectedSize.width
            for format in device.formats {
                // Get the max frame rate associated with the available frame rate ranges for this format
                let maxFrameRate = format.videoSupportedFrameRateRanges.reduce(0) { partialResult, frameRateRange in
                    max(partialResult, frameRateRange.maxFrameRate)
                }
                
                let formatSize = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let formatPixelCount = formatSize.height * formatSize.width
                
                // If the pixel count is bigger and the frame rate can stay above 29, select this one
                if (formatPixelCount > selectedPixelCount) && (maxFrameRate > 29) {
                    selectedFormat = format
                    selectedSize = formatSize
                    selectedPixelCount = formatPixelCount
                }
            }
            prefFormat = selectedFormat
        }

        return prefFormat
    }
    
    func configureGeneric() {
        do {
            try device.lockForConfiguration()
            
            guard let format = findPreferredFormat(device: device) else {
                assertionFailure()
                return
            }
            device.activeFormat = format
            
            let activeSize = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
            
            func str(_ cString: CFString) -> String {
                return (cString as NSString) as String
            }
            
            self.dataOutput.videoSettings = [
                str(kCVPixelBufferPixelFormatTypeKey): NSNumber(value: kCVPixelFormatType_32BGRA),
                str(kCVPixelBufferWidthKey): activeSize.width,
                str(kCVPixelBufferHeightKey): activeSize.height
            ]
            
            device.unlockForConfiguration()
        } catch {
            print("Failed to configure AVCaptureDevice:\(device)")
        }
    }
}
