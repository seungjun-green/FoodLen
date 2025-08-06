//
//  SafeInferenceWrapper.swift
//  FoodLen
//
//  Created by SeungJun Lee on 8/6/25.
//


import Foundation
import MLXVLM
import MLXLMCommon
import UIKit

/// A wrapper class that provides safe inference with background detection
class SafeInferenceWrapper {
    private var isActive = true
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    private var sessionQueue = DispatchQueue(label: "inference.safety", qos: .userInitiated)
    
    init() {
        setupObservers()
    }
    
    deinit {
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupObservers() {
        // Observe background transition
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isActive = false
        }
        
        // Observe foreground transition
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isActive = true
        }
    }
    
    /// Performs inference with safety checks
    func performInference(
        modelContainer: ModelContainer,
        prompt: String,
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        // Create a local session that we can control
        let session = ChatSession(modelContainer)
        var responseText = ""
        var chunkBuffer = ""
        var chunkCount = 0
        
        do {
            // Check if we should start at all
            let appState = await MainActor.run { UIApplication.shared.applicationState }
            guard isActive && appState == .active else {
                throw InferenceError.appNotActive
            }

            
            // Process chunks with safety checks
            for try await chunk in session.streamResponse(to: prompt) {
                // Immediate check before processing each chunk
                guard isActive else {
                    throw InferenceError.appWentToBackground
                }
                
                // Additional safety check
                let appState = await MainActor.run { UIApplication.shared.applicationState }
                if appState != .active {
                    throw InferenceError.appWentToBackground
                }

                
                chunkCount += 1
                
                // Buffer chunks to reduce UI updates
                chunkBuffer += chunk
                
                // Check for end marker
                if let range = chunk.range(of: "<end_of_turn>") {
                    responseText += String(chunk[..<range.lowerBound])
                    break
                } else {
                    responseText += chunk
                }
                
                // Update UI less frequently
                if chunkCount % 3 == 0 && !chunkBuffer.isEmpty {
                    let update = chunkBuffer
                    chunkBuffer = ""
                    
                    // Final safety check before UI update
                    if isActive {
                        let currentText = responseText
                        await MainActor.run {
                            onChunk(currentText)
                        }
                    }
                }
                
                // Yield control periodically
                if chunkCount % 10 == 0 {
                    await Task.yield()
                }
            }
            
            // Final update
            if isActive {
                let finalText = responseText
                await MainActor.run {
                    onComplete(finalText)
                }
            }
            
        } catch {
            await MainActor.run {
                onError(error)
            }
        }
    }
}

enum InferenceError: LocalizedError {
    case appNotActive
    case appWentToBackground
    
    var errorDescription: String? {
        switch self {
        case .appNotActive:
            return "Cannot start analysis while app is not active"
        case .appWentToBackground:
            return "Analysis stopped because app went to background"
        }
    }
}
