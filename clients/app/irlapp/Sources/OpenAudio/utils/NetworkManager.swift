//
//  NetworkManager.swift
//  irlapp
//
//  Created by Elijah Arbee on 10/27/24.
//

import Foundation
import os.log
import ZIPFoundation

public class NetworkManager {
    public static let shared = NetworkManager()
    private let logger = Logger.shared
    
    private init() {}
    
    /// Prepares a ZIP archive with specific files and sends it via POST request.
    public func uploadZipOfFiles(withExtensions extensions: [String], from directory: URL, to url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        let zipURL = createZipFile(withExtensions: extensions, from: directory)
        
        guard let zipData = try? Data(contentsOf: zipURL) else {
            let dataError = NSError(domain: "DataError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read ZIP data."])
            logger.error("Failed to read ZIP data.")
            completion(.failure(dataError))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/zip", forHTTPHeaderField: "Content-Type")
        request.setValue("\(zipData.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = zipData
        
        URLSession.shared.uploadTask(with: request, from: zipData) { [weak self] _, response, error in
            self?.handleResponse(response, error: error, completion: completion)
        }.resume()
    }
    
    /// Sends JSON data via POST request.
    public func sendData<T: Encodable>(_ data: T, to url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let jsonData = try? JSONEncoder().encode(data) else {
            let encodingError = NSError(domain: "EncodingError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode data."])
            logger.error("Failed to encode data.")
            completion(.failure(encodingError))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { _, response, error in
            self.handleResponse(response, error: error, completion: completion)
        }.resume()
    }
    
    // Helper: Creates a ZIP file with specified extensions from a directory.
    private func createZipFile(withExtensions extensions: [String], from directory: URL) -> URL {
        let zipFilename = "FilesBundle_\(Date().timeIntervalSince1970).zip"
        let zipURL = directory.appendingPathComponent(zipFilename)
        
        if FileManager.default.fileExists(atPath: zipURL.path) {
            try? FileManager.default.removeItem(at: zipURL)
        }

        do {
            let archive = try Archive(url: zipURL, accessMode: .create)
            let filesToZip = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [])
                .filter { extensions.contains($0.pathExtension) }

            for fileURL in filesToZip {
                let relativePath = fileURL.lastPathComponent
                try archive.addEntry(with: relativePath, fileURL: fileURL, compressionMethod: .deflate)
                logger.debug("Added \(relativePath) to ZIP archive.")
            }
            logger.info("ZIP archive created at \(zipURL.path)")
        } catch {
            logger.error("Failed to create ZIP archive.")
        }
        
        return zipURL
    }
    
    /// General response handler for network requests.
    private func handleResponse(_ response: URLResponse?, error: Error?, completion: @escaping (Result<Void, Error>) -> Void) {
        if let error = error {
            logger.error("Network error: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            let responseError = NSError(domain: "ResponseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server."])
            logger.error("Invalid response from server.")
            completion(.failure(responseError))
            return
        }
        
        if (200...299).contains(httpResponse.statusCode) {
            logger.info("Data sent successfully.")
            completion(.success(()))
        } else {
            let statusError = NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server responded with status code: \(httpResponse.statusCode)"])
            logger.error("Server responded with status code: \(httpResponse.statusCode)")
            completion(.failure(statusError))
        }
    }
}

protocol NetworkManagerProtocol {
    func uploadZipOfFiles(withExtensions extensions: [String], from directory: URL, to url: URL, completion: @escaping (Result<Void, Error>) -> Void)
    func sendData<T: Encodable>(_ data: T, to url: URL, completion: @escaping (Result<Void, Error>) -> Void)
}

extension NetworkManager: NetworkManagerProtocol {}
