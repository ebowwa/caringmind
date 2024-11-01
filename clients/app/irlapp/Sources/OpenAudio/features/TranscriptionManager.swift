//
//  TranscriptionManager.swift
//  openaudiostandard
//
//  Created by Elijah Arbee on 10/28/24.
//  TODO: Improving Data Persistence in TranscriptionManager:
//  Observation: TranscriptionManager manages Core Data entities for transcription entries and versions but includes both business logic and Core Data fetching in one place.
//  Solution: Extract Core Data fetches and inserts into a dedicated TranscriptionDataService class. This separation would streamline TranscriptionManager, isolating business logic from data access.
//

import Foundation
import Combine
import CoreData

// MARK: - Core Data Entities

@objc(TranscriptionEntry)
public class TranscriptionEntry: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var locationData: Data?
    @NSManaged public var audioFileURL: String
    @NSManaged public var versions: Set<TranscriptionVersion>?
}

extension TranscriptionEntry {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TranscriptionEntry> {
        return NSFetchRequest<TranscriptionEntry>(entityName: "TranscriptionEntry")
    }
    
    public var sortedVersions: [TranscriptionVersion] {
        let versionsArray = versions ?? []
        return versionsArray.sorted { $0.versionNumber < $1.versionNumber }
    }
}

@objc(TranscriptionVersion)
public class TranscriptionVersion: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var versionNumber: Int64
    @NSManaged public var diffData: Data
    @NSManaged public var parentEntry: TranscriptionEntry
}

extension TranscriptionVersion {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TranscriptionVersion> {
        return NSFetchRequest<TranscriptionVersion>(entityName: "TranscriptionVersion")
    }
}

// MARK: - TranscriptionManager Class

public class TranscriptionManager: ObservableObject {
    // Published properties
    @Published private(set) var transcriptionHistory: [TranscriptionEntry] = []
    
    // Private properties
    private var cancellables = Set<AnyCancellable>()
    private let locationManager = LocationManager.shared
    private let transcriptionDataService: TranscriptionDataServiceProtocol
    private let recordingScript: RecordingManagerProtocol // Injected dependency
    
    // MARK: - Initialization
    
    /// Initializes a new instance of TranscriptionManager with injected dependencies.
    /// - Parameters:
    ///   - recordingScript: The recording script instance conforming to RecordingManagerProtocol.
    ///   - transcriptionDataService: The data service instance conforming to TranscriptionDataServiceProtocol.
    public init(recordingScript: RecordingManagerProtocol, transcriptionDataService: TranscriptionDataServiceProtocol) {
        self.recordingScript = recordingScript
        self.transcriptionDataService = transcriptionDataService
        
        // Load existing transcriptions from data service
        self.transcriptionHistory = transcriptionDataService.fetchAllTranscriptions()
        
        // Listen to transcription updates from RecordingScript
        self.recordingScript.transcriptionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transcription in
                self?.handleTranscription(transcription)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Transcription Handling
    
    private func handleTranscription(_ transcription: String) {
        guard !transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let isFinal = recordingScript.isFinalTranscription
        if isFinal {
            // Fetch the latest audio file URL from RecordingScript
            guard let audioURL = recordingScript.currentRecordingURL() else {
                Logger.shared.warning("No audio file associated with the transcription.")
                return
            }
            
            // Fetch the latest location data
            let locationData = locationManager.currentLocation
            
            // Fetch or create a TranscriptionEntry for the current audio file
            let entry = transcriptionDataService.fetchOrCreateTranscriptionEntry(audioURL: audioURL, locationData: locationData)
            
            // Compute the diff between the new transcription and the last version
            let previousText = reconstructFullText(from: entry)
            let diff = DiffUtility.computeDiff(oldText: previousText, newText: transcription)
            
            // Serialize the diff
            guard let diffData = try? JSONEncoder().encode(diff) else {
                Logger.shared.error("Failed to encode diff data.")
                return
            }
            
            // Create a new TranscriptionVersion
            let newVersionNumber = (entry.sortedVersions.last?.versionNumber ?? 0) + 1
            let version = TranscriptionVersion(context: transcriptionDataService.context)
            version.id = UUID()
            version.versionNumber = newVersionNumber
            version.diffData = diffData
            version.parentEntry = entry
            
            // Save the new version via the data service
            transcriptionDataService.saveTranscriptionVersion(version)
            Logger.shared.info("Final transcription appended: \(transcription)")
            
            // Update in-memory transcriptionHistory
            self.transcriptionHistory = transcriptionDataService.fetchAllTranscriptions()
        } else {
            Logger.shared.debug("Partial transcription received: \(transcription)")
        }
    }
    
    // MARK: - Reconstruct Full Text
    
    /// Reconstructs the full transcription text from all versions of a given entry.
    /// - Parameter entry: The `TranscriptionEntry` to reconstruct from.
    /// - Returns: The full transcription text as a `String`.
    private func reconstructFullText(from entry: TranscriptionEntry) -> String {
        var fullText = ""
        for version in entry.sortedVersions {
            // Deserialize diff
            guard let diff = try? JSONDecoder().decode([DiffUtility.DiffStep].self, from: version.diffData) else {
                Logger.shared.error("Failed to decode diff data for version \(version.versionNumber)")
                continue
            }
            fullText = DiffUtility.applyDiff(steps: diff, to: fullText)
        }
        return fullText
    }
    
    // MARK: - Public Access Methods
    
    /// Retrieves all transcription entries.
    public func getAllTranscriptions() -> [TranscriptionEntry] {
        return self.transcriptionHistory
    }
    
    /// Retrieves the latest transcription entry.
    public func getLatestTranscription() -> TranscriptionEntry? {
        return self.transcriptionHistory.last
    }
    
    /// Searches transcriptions containing a specific keyword.
    /// - Parameter keyword: The keyword to search for.
    /// - Returns: An array of `TranscriptionEntry` objects containing the keyword.
    public func searchTranscriptions(keyword: String) -> [TranscriptionEntry] {
        // Reconstruct full text and filter entries containing the keyword
        return self.transcriptionHistory.filter { entry in
            let fullText = reconstructFullText(from: entry)
            return fullText.localizedCaseInsensitiveContains(keyword)
        }
    }
    
    /// Deletes a specific transcription entry.
    /// - Parameter entry: The `TranscriptionEntry` to delete.
    public func deleteTranscription(_ entry: TranscriptionEntry) {
        transcriptionDataService.deleteTranscription(entry)
        self.transcriptionHistory = transcriptionDataService.fetchAllTranscriptions()
    }
    
    /// Clears all transcriptions.
    public func clearAllTranscriptions() {
        transcriptionDataService.clearAllTranscriptions()
        self.transcriptionHistory = transcriptionDataService.fetchAllTranscriptions()
    }
}

// MARK: - TranscriptionDataService Class

/// Service responsible for managing Core Data operations related to transcriptions.
public class TranscriptionDataService: TranscriptionDataServiceProtocol {
    public let context: NSManagedObjectContext
    
    /// Initializes the service with a given managed object context.
    /// - Parameter context: The `NSManagedObjectContext` to use for Core Data operations.
    public init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    public func fetchAllTranscriptions() -> [TranscriptionEntry] {
        let fetchRequest: NSFetchRequest<TranscriptionEntry> = TranscriptionEntry.fetchRequest()
        do {
            let entries = try context.fetch(fetchRequest)
            return entries
        } catch {
            Logger.shared.error("Failed to fetch transcriptions: \(error.localizedDescription)")
            return []
        }
    }
    
    public func fetchOrCreateTranscriptionEntry(audioURL: URL, locationData: LocationData?) -> TranscriptionEntry {
        let fetchRequest: NSFetchRequest<TranscriptionEntry> = TranscriptionEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "audioFileURL == %@", audioURL.absoluteString)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let existingEntry = results.first {
                return existingEntry
            }
        } catch {
            Logger.shared.error("Failed to fetch existing TranscriptionEntry: \(error.localizedDescription)")
        }

        // Create a new TranscriptionEntry
        let entry = TranscriptionEntry(context: context)
        entry.id = UUID()
        entry.timestamp = Date()
        entry.audioFileURL = audioURL.absoluteString
        
        if let locationData = locationData {
            do {
                entry.locationData = try JSONEncoder().encode(locationData)
            } catch {
                Logger.shared.error("Failed to encode locationData: \(error.localizedDescription)")
            }
        }
        return entry
    }
    
    public func saveTranscriptionVersion(_ version: TranscriptionVersion) {
        do {
            try context.save()
        } catch {
            Logger.shared.error("Failed to save transcription version: \(error.localizedDescription)")
        }
    }
    
    public func deleteTranscription(_ entry: TranscriptionEntry) {
        context.delete(entry)
        do {
            try context.save()
            Logger.shared.info("Deleted transcription: \(entry.id)")
        } catch {
            Logger.shared.error("Failed to delete transcription: \(error.localizedDescription)")
        }
    }
    
    public func clearAllTranscriptions() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = TranscriptionEntry.fetchRequest()
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(batchDeleteRequest)
            try context.save()
            Logger.shared.info("All transcriptions cleared.")
        } catch {
            Logger.shared.error("Failed to clear transcriptions: \(error.localizedDescription)")
        }
    }
}

// MARK: - TranscriptionDataServiceProtocol

/// Protocol defining the interface for transcription data operations.
public protocol TranscriptionDataServiceProtocol {
    func fetchAllTranscriptions() -> [TranscriptionEntry]
    func fetchOrCreateTranscriptionEntry(audioURL: URL, locationData: LocationData?) -> TranscriptionEntry
    func saveTranscriptionVersion(_ version: TranscriptionVersion)
    func deleteTranscription(_ entry: TranscriptionEntry)
    func clearAllTranscriptions()
    
    /// Provides access to the managed object context.
    var context: NSManagedObjectContext { get }
}
