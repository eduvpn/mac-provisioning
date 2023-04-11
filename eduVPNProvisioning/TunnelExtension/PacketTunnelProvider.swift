//
//  PacketTunnelProvider.swift
//  TunnelExtension
//
//  Created by Roopesh Chander on 24/02/23.
//

import NetworkExtension

enum PacketTunnelProviderError: Error {
    case cantFindProtocolConfiguration
    case cantFindProviderConfiguration
    case invalidProviderConfiguration
}

class PacketTunnelProvider: NEPacketTunnelProvider {

    var logger: Logger?
    var vpnConfigManager: VPNConfigManager?

    override func startTunnel(options: [String : NSObject]? = nil) async throws {
        // Add code here to start the process of connecting the tunnel.
        let logger = Logger(appComponent: .tunnelExtension)
        self.logger = logger

        logger.log("Starting tunnel")

        guard let protocolConfiguration = self.protocolConfiguration as? NETunnelProviderProtocol else {
            logger.log("Can't find protocolConfiguration")
            throw PacketTunnelProviderError.cantFindProtocolConfiguration
        }

        guard let protocolProviderConfiguration = protocolConfiguration.providerConfiguration else {
            logger.log("Can't find NETunnelProviderProtocol.providerConfiguration")
            throw PacketTunnelProviderError.cantFindProviderConfiguration
        }

        guard let providerConfiguration = ProviderConfiguration(protocolProviderConfiguration: protocolProviderConfiguration, logger: logger) else {
            logger.log("Invalid NETunnelProviderProtocol.providerConfiguration. Available keys: \(protocolProviderConfiguration.keys)")
            throw PacketTunnelProviderError.invalidProviderConfiguration
        }

        let persistenceManager = PersistenceManager(logger: logger)
        let keychainStorageManager = KeychainStorageManager(logger: logger)
        let keychainCertificateManager = KeychainCertificateManager(issuerNames: ["Microsoft Intune MDM Agent CA"], logger: logger)

        let vpnConfigManager = VPNConfigManager(persistenceManager: persistenceManager,
                                                keychainStorageManager: keychainStorageManager,
                                                keychainCertificateManager: keychainCertificateManager,
                                                logger: logger)
        self.vpnConfigManager = vpnConfigManager

        let vpnConfigData = await vpnConfigManager.getVPNConfig(providerConfiguration: providerConfiguration, vpnConfigType: .wireguard)

        NSLog("vpnConfigData = \(vpnConfigData)")

        let networkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        do {
            try await setTunnelNetworkSettings(networkSettings)
        } catch {
            NSLog("setTunnelNetworkSettings error: \(error)")
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        NSLog("stopTunnel")
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }

    override func wake() {
        // Add code here to wake up.
    }
}
