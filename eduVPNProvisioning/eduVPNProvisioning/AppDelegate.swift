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

        let logger = Logger(appComponent: .containerApp)
        self.logger = logger

        let systemExtensionInstaller = SystemExtensionInstaller(logger: logger)
        self.systemExtensionInstaller = systemExtensionInstaller

        let tunnelManager = TunnelManager(logger: logger)
        self.tunnelManager = tunnelManager

        let mainWindow = NSApp.windows.first

        if isSetupCommandLineArgumentPassed() {
            // If "-setup" is passed, setup the tunnel and quit
            mainWindow?.close()
            Task {
                logger.log("AppDelegate: -setup is passed. Setting up.")
                await setupTunnel(systemExtensionInstaller: systemExtensionInstaller, tunnelManager: tunnelManager, logger: logger)
                logger.log("AppDelegate: -setup is passed. Quitting after setting up.")
                NSApp.terminate(self)
            }
        } else {
            // If "-setup" is not passed, continue to setup the views
            let viewController = mainWindow?.contentViewController as? ViewController

            viewController?.systemExtensionInstaller = systemExtensionInstaller

            viewController?.tunnelManager = tunnelManager
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }


}

private extension AppDelegate {
    func isSetupCommandLineArgumentPassed() -> Bool {
        let commandLineArguments = ProcessInfo.processInfo.arguments
        for (index, argument) in commandLineArguments.enumerated() {
            if index == 0 {
                // arg0 is the executable itself
                continue
            }
            if argument == "-setup" {
                return true
            }
        }
        return false
    }

    func setupTunnel(systemExtensionInstaller: SystemExtensionInstaller, tunnelManager: TunnelManager, logger: Logger) async {

        // Install system extension

        logger.log("AppDelegate.setupTunnel: Trying to install system extension")
        var installError: Error?
        do {
            try await systemExtensionInstaller.installSystemExtension()
        } catch {
            installError = error
        }

        if let installError = installError {
            let errorMessage = {
                if let systemExtensionInstallError = installError as? SystemExtensionInstallerError {
                    return systemExtensionInstallError.rawValue
                } else {
                    return installError.localizedDescription
                }
            }()
            logger.log("AppDelegate.setupTunnel: System Extension Installation Failed: \(errorMessage)")
        } else {
            logger.log("AppDelegate.setupTunnel: The tunnel system extension was installed successfully")
        }

        // Enable on-demand

        logger.log("AppDelegate.setupTunnel: Trying to enable on-demand on the tunnel configuration")
        var tunnelConfigError: Error?
        do {
            try await tunnelManager.setupTunnelConfiguration()
        } catch {
            tunnelConfigError = error
        }

        if let tunnelConfigError = tunnelConfigError {
            let errorMessage = {
                if let tunnelManagerError = tunnelConfigError as? TunnelManagerError {
                    return tunnelManagerError.rawValue
                } else {
                    return tunnelConfigError.localizedDescription
                }
            }()
            logger.log("AppDelegate.setupTunnel: While enabling on-demand: \(errorMessage)")
        } else {
            logger.log("AppDelegate.setupTunnel: On-demand was enabled on the tunnel configuration successfully")
        }
    }
}
