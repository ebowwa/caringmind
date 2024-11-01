//
//  socketmanager.swift
//  openaudiostandard
//
//  Created by Elijah Arbee on 10/20/24.
//

import Foundation
import Combine

// MARK: - WebSocketManager

public class WebSocketManager: NSObject, WebSocketManagerProtocol {
    private var webSocketTask: URLSessionWebSocketTask?
    private let receivedDataSubject = PassthroughSubject<Data, Never>()

    public var receivedDataPublisher: AnyPublisher<Data, Never> {
        receivedDataSubject.eraseToAnyPublisher()
    }

    /// Initializes the WebSocketManager with a specified URL.
    /// - Parameter url: The WebSocket server URL.
    public init(url: URL) {
        super.init()
        setupWebSocket(url: url)
    }

    /// Sets up the WebSocket connection.
    /// - Parameter url: The WebSocket server URL.
    private func setupWebSocket(url: URL) {
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveMessage()
    }

    /// Sends audio data through the WebSocket connection.
    /// - Parameter data: The audio data to send.
    public func sendAudioData(_ data: Data) {
        webSocketTask?.send(.data(data)) { error in
            if let error = error {
                print("Error sending audio data: \(error.localizedDescription)")
            }
        }
    }

    /// Receives messages from the WebSocket connection.
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        self?.receivedDataSubject.send(data)
                    }
                case .data(let data):
                    self?.receivedDataSubject.send(data)
                @unknown default:
                    print("Received unknown message type.")
                }
                self?.receiveMessage() // Continue listening for more messages
            case .failure(let error):
                print("Error receiving message: \(error.localizedDescription)")
                // Optionally, implement reconnection logic here
            }
        }
    }

    deinit {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
}

