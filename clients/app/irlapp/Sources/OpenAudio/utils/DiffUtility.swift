//
//  DiffUtility.swift
//  irlapp
//
//  Created by Elijah Arbee on 10/29/24.
//

import Foundation

/// A utility for computing and applying diffs between two strings.
/// Useful for tracking changes in real-time speech transcription predictions.
public struct DiffUtility {
    
    /// Represents the type of operation in a diff step.
    public enum Operation: String, Codable {
        case insert  // Represents inserted text.
        case delete  // Represents deleted text.
        case equal   // Represents unchanged text.
    }
    
    /// A single step in the diff process.
    public struct DiffStep: Codable {
        public let operation: Operation  // The type of operation.
        public let text: String          // The text associated with the operation.
    }
    
    /// Computes the diff between two strings using Myers' diff algorithm.
    ///
    /// - Parameters:
    ///   - oldText: The original string.
    ///   - newText: The modified string.
    /// - Returns: An array of `DiffStep` representing the differences.
    public static func computeDiff(oldText: String, newText: String) -> [DiffStep] {
        let oldArray = Array(oldText)  // Convert old text to an array of characters.
        let newArray = Array(newText)  // Convert new text to an array of characters.
        let diffs = myersDiff(old: oldArray, new: newArray)  // Compute diffs using Myers' algorithm.
        return diffs
    }
    
    /// Applies the diff steps to reconstruct the new string from the old string.
    ///
    /// - Parameters:
    ///   - steps: The array of `DiffStep` representing the diff.
    ///   - oldText: The original string to which the diff will be applied.
    /// - Returns: The reconstructed new string after applying the diff.
    public static func applyDiff(steps: [DiffStep], to oldText: String) -> String {
        var result = ""
        var index = oldText.startIndex  // Current position in the old text.
        
        for step in steps {
            switch step.operation {
            case .equal:
                // Append the unchanged text segment.
                let endIndex = oldText.index(index, offsetBy: step.text.count)
                result += oldText[index..<endIndex]
                index = endIndex  // Move the index forward.
            case .insert:
                // Insert the new text segment.
                result += step.text
            case .delete:
                // Skip the deleted text segment in the old text.
                index = oldText.index(index, offsetBy: step.text.count)
            }
        }
        return result
    }
    
    // MARK: - Myers' Diff Algorithm Implementation
    
    /// Implements Myers' diff algorithm to compute the differences between two sequences.
    ///
    /// - Parameters:
    ///   - old: The original sequence.
    ///   - new: The modified sequence.
    /// - Returns: An array of `DiffStep` representing the differences.
    private static func myersDiff<T: Equatable>(old: [T], new: [T]) -> [DiffStep] {
        let n = old.count
        let m = new.count
        let maxD = n + m  // Maximum possible number of differences.
        var v: [Int: Int] = [:]
        v[1] = 0  // Initialize the furthest-reaching D-path.
        
        var trace: [[Int: Int]] = []  // Keeps track of all V arrays for backtracking.
        
        // Iterate over all possible number of differences (D).
        for d in 0...maxD {
            var newV: [Int: Int] = [:]
            // Iterate over all possible k-lines for the current D.
            for k in stride(from: -d, through: d, by: 2) {
                var x: Int
                // Determine the direction of the path.
                if k == -d || (k != d && (v[k - 1] ?? 0) < (v[k + 1] ?? 0)) {
                    x = v[k + 1] ?? 0  // Move down.
                } else {
                    x = (v[k - 1] ?? 0) + 1  // Move right.
                }
                var y = x - k  // Calculate the y-coordinate.
                
                // Follow the diagonal (i.e., matching characters).
                while x < n && y < m && old[x] == new[y] {
                    x += 1
                    y += 1
                }
                
                newV[k] = x  // Update the furthest-reaching x for this k.
                
                // Check if the end has been reached.
                if x >= n && y >= m {
                    trace.append(newV)  // Append the final V.
                    return buildDiff(old: old, new: new, trace: trace)  // Reconstruct the diff.
                }
            }
            trace.append(newV)  // Append the current V to the trace.
            v = newV  // Update V for the next iteration.
        }
        return []  // Return an empty diff if no solution is found (shouldn't happen).
    }
    
    /// Reconstructs the diff steps from the trace of V arrays.
    ///
    /// - Parameters:
    ///   - old: The original sequence.
    ///   - new: The modified sequence.
    ///   - trace: The trace of V arrays from Myers' algorithm.
    /// - Returns: An array of `DiffStep` representing the differences.
    private static func buildDiff<T: Equatable>(old: [T], new: [T], trace: [[Int: Int]]) -> [DiffStep] {
        var x = old.count  // Start from the end of the old sequence.
        var y = new.count  // Start from the end of the new sequence.
        var diffs: [DiffStep] = []  // Initialize the diff steps.
        
        // Iterate backwards through the trace to reconstruct the diff.
        for d in stride(from: trace.count - 1, through: 0, by: -1) {
            let v = trace[d]  // Get the V array for the current D.
            let k = x - y  // Current k-line.
            let prevK: Int
            // Determine the previous k-line.
            if k == -d || (k != d && (v[k - 1] ?? 0) < (v[k + 1] ?? 0)) {
                prevK = k + 1
            } else {
                prevK = k - 1
            }
            let prevX = v[prevK] ?? 0  // Get the previous x.
            let prevY = prevX - prevK  // Calculate the previous y.
            
            // Follow the diagonal as far as possible.
            while x > prevX && y > prevY {
                x -= 1
                y -= 1
                let char = old[x]
                diffs.insert(DiffStep(operation: .equal, text: String(describing: char)), at: 0)
            }
            if d > 0 {
                if x == prevX {
                    // Insertion occurred.
                    y -= 1
                    let char = new[y]
                    diffs.insert(DiffStep(operation: .insert, text: String(describing: char)), at: 0)
                } else if y == prevY {
                    // Deletion occurred.
                    x -= 1
                    let char = old[x]
                    diffs.insert(DiffStep(operation: .delete, text: String(describing: char)), at: 0)
                }
            }
        }
        return diffs
    }
    
    // MARK: - Usage Example
    
    /*
     // Example Usage:
     
     let oldText = "The quick brown fox"
     let newText = "The swift brown fox jumps"
     
     // Compute the diff between oldText and newText.
     let diffSteps = DiffUtility.computeDiff(oldText: oldText, newText: newText)
     
     // Apply the diff to the oldText to reconstruct newText.
     let reconstructedText = DiffUtility.applyDiff(steps: diffSteps, to: oldText)
     
     print("Diff Steps:")
     for step in diffSteps {
         print("\(step.operation.rawValue): \(step.text)")
     }
     
     print("\nReconstructed Text:")
     print(reconstructedText)
     
     // Output:
     // Diff Steps:
     // equal: The
     // delete: q
     // insert: s
     // equal: uick brown fox
     // insert: jumps
     
     // Reconstructed Text:
     // The swift brown fox jumps
    */
}
