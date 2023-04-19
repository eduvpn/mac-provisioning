//
//  AppDelegate.swift
//  eduVPNProvisioning
//
//  Created by Roopesh Chander on 24/02/23.
//

import Cocoa

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
