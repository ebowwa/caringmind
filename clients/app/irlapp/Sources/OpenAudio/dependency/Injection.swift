//
//  Injection.swift
//  irlapp
//
//  Created by Elijah Arbee on 11/1/24.
//


// Dependency/Injection.swift
import Swinject
import SwinjectAutoregistration

public final class Injection {
    public static let shared = Injection()
    private let container: Container
    
    private init() {
        container = Container()
        registerDependencies()
    }
    
    private func registerDependencies() {
        // Register Core Services
        container.autoregister(AudioFileManagerProtocol.self, initializer: AudioFileManager.init)
        container.autoregister(WebSocketManagerProtocol.self, initializer: WebSocketManager.init)
        container.autoregister(VoiceActivityDetectorProtocol.self, initializer: EnergyBasedVoiceActivityDetector.init)
        container.autoregister(AudioBufferProcessorProtocol.self) { resolver in
            AudioBufferProcessor(
                webSocketManager: resolver.resolve(WebSocketManagerProtocol.self)!,
                vad: resolver.resolve(VoiceActivityDetectorProtocol.self)!
            )
        }
        container.autoregister(AudioEngineManagerProtocol.self) { resolver in
            AudioEngineManager(
                audioFileManager: resolver.resolve(AudioFileManagerProtocol.self)!,
                bufferProcessor: resolver.resolve(AudioBufferProcessorProtocol.self)!,
                logger: resolver.resolve(Logger.self)! // Assuming Logger is registered
            )
        }
        container.autoregister(AVAudioSessionManagerProtocol.self, initializer: AVAudioSessionManager.init)
        
        // Register Features
        container.autoregister(TranscriptionDataServiceProtocol.self) { resolver in
            TranscriptionDataService(context: resolver.resolve(NSManagedObjectContext.self)!)
        }
        container.autoregister(TranscriptionManager.self) { resolver in
            TranscriptionManager(
                recordingScript: resolver.resolve(RecordingManagerProtocol.self)!,
                transcriptionDataService: resolver.resolve(TranscriptionDataServiceProtocol.self)!,
                logger: resolver.resolve(Logger.self)! // Assuming Logger is registered
            )
        }
        
        // Register Logger
        container.register(Logger.self) { _ in Logger.shared }
            .inObjectScope(.container)
        
        // Register Core Data Stack
        container.register(NSManagedObjectContext.self) { _ in
            // Configure your Core Data stack here
            let container = NSPersistentContainer(name: "TranscriptionModel")
            container.loadPersistentStores { _, error in
                if let error = error {
                    fatalError("Core Data stack failed to load: \(error)")
                }
            }
            return container.viewContext
        }.inObjectScope(.container)
        
        // Add other dependencies similarly...
    }
    
    public func resolve<T>() -> T {
        guard let resolved = container.resolve(T.self) else {
            fatalError("Dependency \(T.self) not registered")
        }
        return resolved
    }
}