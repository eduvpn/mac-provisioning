//
//  AppDelegate.swift
//  eduVPNProvisioning
//
//  Created by Roopesh Chander on 24/02/23.
//

import Cocoa
import SystemExtensions

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var logger: Logger?
    var systemExtensionInstaller: SystemExtensionInstaller?
    var tunnelManager: TunnelManager?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let mainWindow = NSApp.windows.first
        let viewController = mainWindow?.contentViewController as? ViewController

        let logger = Logger(appComponent: .containerApp)
        self.logger = logger

        let systemExtensionInstaller = SystemExtensionInstaller(logger: logger)
        self.systemExtensionInstaller = systemExtensionInstaller
        viewController?.systemExtensionInstaller = systemExtensionInstaller

        let tunnelManager = TunnelManager(logger: logger)
        self.tunnelManager = tunnelManager
        viewController?.tunnelManager = tunnelManager
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }


}

extension AppDelegate {
    func beginSystemExtensionInstallation() {
        NSLog("beginSystemExtensionInstallation")
        guard let appId = Bundle.main.bundleIdentifier else { fatalError("missing bundle id") }
        let tunnelExtensionBundleId = "\(appId).TunnelExtension"
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: tunnelExtensionBundleId,
            queue: DispatchQueue.main)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }
}

extension AppDelegate: OSSystemExtensionRequestDelegate {
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        NSLog("System Extension: Replacing \(existing.bundleShortVersion) with \(ext.bundleShortVersion)")
        return .replace
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        NSLog("System Extension: Needs user approval")
        NSApp.terminate(self)
    }

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        if result == .completed {
            NSLog("System Extension: Loading complete")
        } else if result == .willCompleteAfterReboot {
            NSLog("System Extension: Loading requires reboot")
        } else {
            NSLog("System Extension: OSSystemExtensionRequest code = \(result.rawValue)")
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        NSLog("System Extension: Error: \(error)")
        NSApp.terminate(self)
    }
}
