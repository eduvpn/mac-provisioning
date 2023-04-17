//
//  SystemExtensionInstaller.swift
//  eduVPNProvisioning
//
//  Created by Roopesh Chander on 16/04/23.
//

import Foundation
import SystemExtensions

enum SystemExtensionInstallerError: String, Error {
    case cannotGetBundleId = "Cannot get bundle id"
    case installAlreadyInProgress = "An installation is already in progress"
    case installRequiresUserApproval = "Installation requires user approval. Please contact your MDM solution administrator to allow this app to install the System Extension without user approval."
    case installRequiresReboot = "Installation requires reboot, which is unexpected"
    case installResultWasUnexpected = "Installation request result was unexpected"
}

class SystemExtensionInstaller: NSObject {
    private var isInstalling = false
    private var continuation: CheckedContinuation<(), Error>?

    func installSystemExtension() async throws {

        guard !self.isInstalling else {
            throw SystemExtensionInstallerError.installAlreadyInProgress
        }

        guard let appId = Bundle.main.bundleIdentifier else {
            throw SystemExtensionInstallerError.cannotGetBundleId
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.isInstalling = true
            self.continuation = continuation
            let tunnelExtensionBundleId = "\(appId).TunnelExtension"
            let request = OSSystemExtensionRequest.activationRequest(
                forExtensionWithIdentifier: tunnelExtensionBundleId,
                queue: DispatchQueue.main)
            request.delegate = self
            OSSystemExtensionManager.shared.submitRequest(request)
        }
    }
}

extension SystemExtensionInstaller: OSSystemExtensionRequestDelegate {
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        return .replace
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        guard self.isInstalling else {
            // Can call resume only once on a continuation
            return
        }
        self.isInstalling = false
        self.continuation?.resume(throwing: SystemExtensionInstallerError.installRequiresUserApproval)
    }

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        guard self.isInstalling else {
            // Can call resume only once on a continuation
            return
        }
        self.isInstalling = false
        switch result {
            case .completed:
                self.continuation?.resume()
            case .willCompleteAfterReboot:
                self.continuation?.resume(throwing: SystemExtensionInstallerError.installRequiresReboot)
            @unknown default:
                self.continuation?.resume(throwing: SystemExtensionInstallerError.installResultWasUnexpected)
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        guard self.isInstalling else {
            // Can call resume only once on a continuation
            return
        }
        self.isInstalling = false
        self.continuation?.resume(throwing: error)
    }
}
