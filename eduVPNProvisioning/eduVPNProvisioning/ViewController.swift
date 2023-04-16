//
//  ViewController.swift
//  eduVPNProvisioning
//
//  Created by Roopesh Chander on 24/02/23.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var appLogPathLabel: NSTextField!
    @IBOutlet weak var tunnelLogPathLabel: NSTextField!

    private var appLogPath = ""
    private var tunnelLogPath = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        if let bundleId = Bundle.main.bundleIdentifier {
            appLogPath = "~/Library/Containers/\(bundleId)/Data/Library/\(bundleId).log"
            tunnelLogPath = "/var/root/Library/Containers/\(bundleId).TunnelExtension/Data/Library/\(bundleId).TunnelExtension.log"
        }

        appLogPathLabel.stringValue = appLogPath
        tunnelLogPathLabel.stringValue = tunnelLogPath
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func installSystemExtensionClicked(_ sender: Any) {
        NSLog("installSystemExtensionClicked")
    }

    @IBAction func enableOnDemandVPNClicked(_ sender: Any) {
        NSLog("enableOnDemandVPNClicked")
    }

    @IBAction func copyAppLogPathClicked(_ sender: Any) {
        NSLog("copyAppLogPathClicked")
    }

    @IBAction func copyTunnelLogPathClicked(_ sender: Any) {
        NSLog("copyTunnelLogPathClicked")
    }
}

