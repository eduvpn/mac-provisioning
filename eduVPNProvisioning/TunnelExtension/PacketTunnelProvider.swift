//
//  PacketTunnelProvider.swift
//  TunnelExtension
//
//  Created by Roopesh Chander on 24/02/23.
//

import NetworkExtension
import WireGuardKit

enum PacketTunnelProviderError: Error {
    case cantFindProtocolConfiguration
    case cantFindProviderConfiguration
    case invalidProviderConfiguration
    case couldNotGetVPNConfig
    case couldNotParseWgQuickConfig
    case tunnelConfigurationExpired
}

class PacketTunnelProvider: NEPacketTunnelProvider {

    private var logger: Logger?
    private var vpnConfigManager: VPNConfigManager?

    private var timer: DispatchSourceTimer? = nil
    private var timerQueue: DispatchQueue = DispatchQueue(label: "TimerQueue", qos: .default)

    private lazy var adapter: WireGuardAdapter = {
        return WireGuardAdapter(with: self) { [weak self] _, message in
            self?.logger?.log(message)
        }
    }()

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

        guard let vpnConfigData = await vpnConfigManager.getVPNConfig(
            providerConfiguration: providerConfiguration, vpnConfigType: .wireguard) else {
            logger.log("Could not get VPN config")
            throw PacketTunnelProviderError.couldNotGetVPNConfig
        }

        if let expiryDate = vpnConfigData.vpnConfigExpiryDate {
            logger.log("Got VPN config expiring at: \(expiryDate)")
            let secondsToExpiry = Int(expiryDate.timeIntervalSince(Date()))
            if secondsToExpiry <= 0 {
                self.logger?.log("Config has already expired. Cancelling tunnel.")
                self.cancelTunnelWithError(PacketTunnelProviderError.tunnelConfigurationExpired)
                self.timer?.cancel()
                self.timer = nil
            } else {
                let timer = DispatchSource.makeTimerSource(queue: self.timerQueue)
                self.logger?.log("Scheduling timer to cancel tunnel after \(secondsToExpiry) seconds")
                timer.schedule(deadline: .now() + .seconds(secondsToExpiry), leeway: .seconds(1))
                timer.setEventHandler { [weak self] in
                    guard let self = self else { return }
                    self.logger?.log("Config has expired (invoked by timer). Cancelling tunnel.")
                    self.cancelTunnelWithError(PacketTunnelProviderError.tunnelConfigurationExpired)
                    self.timer = nil
                }
                timer.resume()
                self.timer = timer
            }
        } else {
            logger.log("Got VPN config. Expiry is unknown.")
        }

        assert(vpnConfigData.vpnConfigType == .wireguard)
        guard let tunnelConfiguration = try? TunnelConfiguration(fromWgQuickConfig: vpnConfigData.vpnConfig) else {
            logger.log("wg-quick config not parseable")
            throw PacketTunnelProviderError.couldNotParseWgQuickConfig
        }

        do {
            logger.log("Starting WireGuard")
            try await adapter.start(tunnelConfiguration: tunnelConfiguration)
        } catch {
            logger.log("Error starting WireGuard: \(error.localizedDescription)")
            throw error
        }

        logger.log("Tunnel interface is \(adapter.interfaceName ?? "unknown")")
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        logger?.log("Stopping tunnel because: \(reason)")
        do {
            try await adapter.stop()
        } catch {
            logger?.log("Error stopping WireGuard: \(error.localizedDescription)")
        }
        #if os(macOS)
        // HACK: We have to kill the tunnel process ourselves because of a macOS bug
        exit(0)
        #endif
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // No app messages are handled
        completionHandler?(nil)
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        logger?.log("Sleep")
        completionHandler()
    }

    override func wake() {
        logger?.log("Wake")
        // Add code here to wake up.
    }
}

extension WireGuardAdapter {
    func start(tunnelConfiguration: TunnelConfiguration) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            start(tunnelConfiguration: tunnelConfiguration) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func stop() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            stop { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
