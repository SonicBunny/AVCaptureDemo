//
//  ViewController.swift
//  AVCaptureDemo
//
//  Created by Jay Lyerly on 11/29/23.
//

import Cocoa
import CoreImage
import AVFoundation

class ViewController: NSViewController {

    @IBOutlet var containerView: NSView!
    @IBOutlet var popup: NSPopUpButton!
    var imageView: MetalImageView!
    var avController: AVController?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        imageView = MetalImageView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        containerView.addSubViewEdgeToEdge(imageView)

        checkPermissions()
    }

    func setupPopup() {
        guard let avController else { return }
        
        popup.removeAllItems()
        
        avController.devices.forEach { device in
            popup.addItem(withTitle: device.localizedName)
        }
    }
    
    @IBAction func popupDidUpdate(_ sender: Any?) {
        let idx = popup.indexOfSelectedItem
        
        avController?.change(toDevice: avController?.devices[idx])
    }

    func setupAfterPermission() {
        avController = AVController()
        avController?.delegate = self
        setupPopup()
        avController?.start()
    }
    
}

extension ViewController: AVControllerDelegate {
    
    func didCaptureImage(_ image: CIImage) {
        imageView.image = image
    }
    
}

extension ViewController {
    
    func checkPermissions() {
        let auth = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch auth {
            case .authorized:
                setupAfterPermission()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { (permissionGranted) in
                    if permissionGranted {
                        self.setupAfterPermission()
                    } else {
                        self.showPermissionAlert()
                    }
                }
            case .restricted, .denied:
                showPermissionAlert()
            @unknown default:
                break
        }
    }
    
    func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Camera access denied."
            alert.informativeText = "This app does not have access to the camera.  "
            + "Please open the privacy settings and grant access to the app."
            alert.addButton(withTitle: "Open Privacy Settings")
            alert.addButton(withTitle: "Ignore")
            
            let response = alert.runModal()
            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                self.openCameraPermission()
            }
        }
    }

    func openCameraPermission() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else {
            print("Failed to create URL for camera privacy preferences pane.")
            return
        }
        NSWorkspace.shared.open(url)
    }
    
}
