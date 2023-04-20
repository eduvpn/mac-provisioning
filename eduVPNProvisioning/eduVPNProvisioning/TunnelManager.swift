//
//  TunnelManager.swift
//  eduVPNProvisioning
//
//  Created by Roopesh Chander on 17/04/23.
//

import Foundation
import NetworkExtension

enum TunnelManagerError: String, Error {
    case noDeviceCertificateFoundInKeychain = "No device certificate found in the keychain"
    case noValidTunnelConfigurationFound = "No valid tunnel configuration found"
    case onDemandIsAlreadyEnabled = "On-Demand is already enabled"
}

class TunnelManager {
    private var logger: Logger
    private var tunnelProviderManager: NETunnelProviderManager?

    init(logger: Logger) {
        self.logger = logger
    }

    func setupTunnelConfiguration() async throws {
        guard checkDeviceCertificate() else {
            self.logger.log("TunnelManager.setupTunnelConfiguration: Aborting because device certificate is not found")
            throw TunnelManagerError.noDeviceCertificateFoundInKeychain
        }

        self.logger.log("TunnelManager.setupTunnelConfiguration: Getting tunnel provider manager")
        let tunnelProviderManager = try await getTunnelProviderManager()
        self.logger.log("TunnelManager.setupTunnelConfiguration: Enabling on-demand")
        try await enableOnDemand(on: tunnelProviderManager)
    }
}

private extension TunnelManager {
    func checkDeviceCertificate() -> Bool {
        let keychainCertificateManager = KeychainCertificateManager(issuerNames: ["Microsoft Intune MDM Agent CA"], logger: logger)
        guard let _ = keychainCertificateManager.getDeviceCertificateData() else {
            logger.log("TunnelManager.checkDeviceCertificate: No device certificate found. Aborting setting up tunnel.")
            return false
        }
        logger.log("TunnelManager.checkDeviceCertificate: Device certificate found.")
        return true
    }

    func getTunnelProviderManager() async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        let count = managers.count
        for (index, manager) in managers.enumerated() {
            self.logger.log("TunnelManager.getTunnelProviderManager: Trying tunnel index \(index) of \(count)")
            guard let tunnelProviderProtocol = manager.protocolConfiguration as? NETunnelProviderProtocol,
                  let protocolProviderConfiguration = tunnelProviderProtocol.providerConfiguration else {
                self.logger.log("TunnelManager.getTunnelProviderManager: NETunnelProviderProtocol.providerConfiguration is not present")
                continue
            }
            guard let providerConfiguration = ProviderConfiguration(
                protocolProviderConfiguration: protocolProviderConfiguration, logger: logger) else {
                self.logger.log("TunnelManager.getTunnelProviderManager: Invalid NETunnelProviderProtocol.providerConfiguration. Available keys: \(protocolProviderConfiguration.keys)")
                continue
            }
            self.logger.log("TunnelManager.getTunnelProviderManager: Choosing tunnel with provider configuration \(providerConfiguration.description)")
            return manager
        }
        self.logger.log("TunnelManager.getTunnelProviderManager: No valid tunnel configuration found")
        throw TunnelManagerError.noValidTunnelConfigurationFound
    }

    func enableOnDemand(on tunnelProviderManager: NETunnelProviderManager) async throws {
        if tunnelProviderManager.isOnDemandEnabled {
            self.logger.log("TunnelManager.enableOnDemand: On-demand is already enabled")
            throw TunnelManagerError.onDemandIsAlreadyEnabled
        }
        tunnelProviderManager.isOnDemandEnabled = true
        try await tunnelProviderManager.saveToPreferences()
    }
}
