//
//  TunnelManager.swift
//  eduVPNProvisioning
//
//  Created by Roopesh Chander on 17/04/23.
//

import Foundation
import NetworkExtension

enum TunnelManagerError: String, Error {
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
        self.logger.log("TunnelManager.setupTunnelConfiguration: Getting tunnel provider manager")
        let tunnelProviderManager = try await getTunnelProviderManager()
        self.logger.log("TunnelManager.setupTunnelConfiguration: Enabling on-demand")
        try await enableOnDemand(on: tunnelProviderManager)
    }
}

private extension TunnelManager {
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
