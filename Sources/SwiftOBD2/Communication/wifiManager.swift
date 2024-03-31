//
//  wifimanager.swift
//
//
//  Created by kemo konteh on 2/26/24.
//

import Network
import OSLog

protocol CommProtocol {
    func sendCommand(_ command: String) async throws -> [String]
    func disconnectPeripheral()
    func connectAsync(timeout: TimeInterval) async throws
    var connectionStatePublisher: Published<ConnectionState>.Publisher { get }
    var obdDelegate: OBDServiceDelegate? { get set }
}

enum CommunicationError: Error {
    case invalidData
    case errorOccurred(Error)
}

class WifiManager: CommProtocol {
    var obdDelegate: OBDServiceDelegate?

    @Published var connectionState: ConnectionState = .disconnected
    var connectionStatePublisher: Published<ConnectionState>.Publisher { $connectionState }

    var tcp: NWConnection?
    let logger = Logger.communcation

    func connectAsync(timeout: TimeInterval) async throws {
        let host = NWEndpoint.Host("192.168.0.10")
        guard let port = NWEndpoint.Port("35000") else {
            throw CommunicationError.invalidData
        }
        tcp = NWConnection(host: host, port: port, using: .tcp)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            tcp?.stateUpdateHandler = { newState in
                switch newState {
                case .ready:
                    self.logger.info("Connected to adapter")
                    self.connectionState = .connectedToAdapter
                    continuation.resume(returning: ())
                case let .waiting(error):
                    self.logger.error("Waiting \(error)")
                case let .failed(error):
                    self.logger.error("Failed \(error)")
                    continuation.resume(throwing: CommunicationError.errorOccurred(error))
                default:
                    break
                }
            }
            tcp?.start(queue: .main)
        }
    }

    func sendCommand(_ command: String) async throws -> [String] {
        guard let data = "\(command)\r".data(using: .ascii) else {
            throw CommunicationError.invalidData
        }
        #if DEBUG
        logger.info("Sending command \(command)")
        #endif

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            self.tcp?.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    self.logger.error("Error sending command \(error)")
                    continuation.resume(throwing: error)
                }

                self.tcp?.receive(minimumIncompleteLength: 1, maximumLength: 500, completion: { data, _, _, _ in
                    guard let response = data, let string = String(data: response, encoding: .utf8) else {
                        return
                    }
                    if string.contains(">") {
                        self.logger.info("Received response \(string)")

                        var lines = string
                            .components(separatedBy: .newlines)
                            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        lines.removeLast()

                        continuation.resume(returning: lines)
                    }
                })
            })
        }
    }

    func disconnectPeripheral() {
        tcp?.cancel()
    }
}
