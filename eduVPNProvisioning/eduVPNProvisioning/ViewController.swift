//
//  ViewController.swift
//  eduVPNProvisioning
//
//  Created by Roopesh Chander on 24/02/23.
//

import Cocoa

class ViewController: NSViewController {

    var systemExtensionInstaller: SystemExtensionInstaller? = nil

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
        guard let systemExtensionInstaller = systemExtensionInstaller else {
            fatalError("System Extension Installer is not set")
        }
        Task {
            var installError: Error?
            do {
                try await systemExtensionInstaller.installSystemExtension()
            } catch {
                installError = error
            }

            let alert = NSAlert()
            if let installError = installError {
                alert.messageText = "System Extension Installation Failed"
                if let systemExtensionInstallError = installError as? SystemExtensionInstallerError {
                    alert.informativeText = systemExtensionInstallError.rawValue
                } else {
                    alert.informativeText = installError.localizedDescription
                }
                alert.alertStyle = .critical
            } else {
                alert.messageText = "System Extension Installed"
                alert.informativeText = "The tunnel system extension was installed successfully"
                alert.alertStyle = .informational
            }
            if let window = self.view.window {
                await alert.beginSheetModal(for: window)
            }
        }
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

