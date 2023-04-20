//
//  ViewController.swift
//  eduVPNProvisioning
//
//  Created by Roopesh Chander on 24/02/23.
//

import Cocoa

class ViewController: NSViewController {

    var systemExtensionInstaller: SystemExtensionInstaller? = nil
    var tunnelManager: TunnelManager? = nil

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
        guard let tunnelManager = tunnelManager else {
            fatalError("Tunnel Manager is not set")
        }
        Task {
            var tunnelConfigError: Error?
            do {
                try await tunnelManager.setupTunnelConfiguration()
            } catch {
                tunnelConfigError = error
            }

            let alert = NSAlert()
            if let tunnelConfigError = tunnelConfigError {
                alert.messageText = "Setting up Tunnel Configuration Failed"
                if let tunnelManagerError = tunnelConfigError as? TunnelManagerError {
                    alert.informativeText = tunnelManagerError.rawValue
                } else {
                    alert.informativeText = tunnelConfigError.localizedDescription
                }
                alert.alertStyle = .critical
            } else {
                alert.messageText = "Tunnel Configured with On-Demand"
                alert.informativeText = "On-demand was set on the tunnel successfully"
                alert.alertStyle = .informational
            }
            if let window = self.view.window {
                await alert.beginSheetModal(for: window)
            }
        }
    }

    @IBAction func copyAppLogPathClicked(_ sender: Any) {
        setPasteboardString(self.appLogPath)
    }

    @IBAction func copyTunnelLogPathClicked(_ sender: Any) {
        setPasteboardString(self.tunnelLogPath)
    }

    private func setPasteboardString(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}

