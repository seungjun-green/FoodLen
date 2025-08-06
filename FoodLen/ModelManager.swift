//
//  ModelManager.swift
//  FoodLen
//
//  Created by SeungJun Lee on 8/6/25.
//


import SwiftUI
import MLXVLM
import MLXLMCommon

import Foundation

struct ModelOption {
    let id: String
    let displayName: String
    let description: String
    let size: String
    let minimumRAMGB: Int
    
    // Static method to get device RAM in GB
    static func getDeviceRAMInGB() -> Int {
        let ramBytes = ProcessInfo.processInfo.physicalMemory
        return Int(ramBytes / (1024 * 1024 * 1024))
    }
    
    // Show ALL models, but mark availability
    static let availableModels = [
        ModelOption(
            id: "mlx-community/gemma-3-1b-it-qat-4bit",
            displayName: "Gemma 3-1B (4-bit)",
            description: "Powerful AI for text and images, built for speed and scale",
            size: "~0.75 GB",
            minimumRAMGB: 2
        ),
        ModelOption(
            id: "mlx-community/gemma-3n-E2B-it-lm-4bit",
            displayName: "Gemma 3n-E2B (4-bit)",
            description: "Powerful AI for text and images, built for speed and scale",
            size: "~2.51 GB",
            minimumRAMGB: 7
        )
    ]
    
    // Check if this model is available on current device
    var isAvailable: Bool {
        return Self.getDeviceRAMInGB() >= minimumRAMGB
    }
    
    // Get unavailability reason
    var unavailabilityReason: String? {
        if !isAvailable {
            let deviceRAM = Self.getDeviceRAMInGB()
            return "Device RAM should be \(minimumRAMGB)GB or higher (current: \(deviceRAM)GB)"
        }
        return nil
    }
    
    var directoryName: String {
        return id.components(separatedBy: "/").last ?? id
    }
}

enum ModelStatus: Equatable {
    case notDownloaded
    case downloading
    case downloaded
    case loading
    case loaded
    case error(String)
}

class ModelManager: ObservableObject {
    static let shared = ModelManager()
    
    @Published var modelStatus: ModelStatus = .notDownloaded
    @Published var downloadProgress: Double = 0.0
    @Published var selectedModel: ModelOption = ModelOption.availableModels[0]
    
    private var loadedModelContainer: ModelContainer?
    private var downloadTask: Task<Void, Never>?
    private var progressTimer: Timer?
    private var debugLogs: [String] = []
    
    private init() {
        loadSelectedModel()
        checkModelStatus()
    }
        
    func setSelectedModel(_ model: ModelOption) {
        guard model.id != selectedModel.id else { return }
        
        addDebugLog("🔄 Switching model from \(selectedModel.displayName) to \(model.displayName)")
        
        // If there's a currently loaded model, unload it
        if modelStatus == .loaded {
            unloadModel()
        }
        
        selectedModel = model
        saveSelectedModel()
        checkModelStatus()
    }
    
    private func saveSelectedModel() {
        UserDefaults.standard.set(selectedModel.id, forKey: "selectedModelID")
    }
    
    private func loadSelectedModel() {
        if let savedModelID = UserDefaults.standard.string(forKey: "selectedModelID"),
           let model = ModelOption.availableModels.first(where: { $0.id == savedModelID }) {
            selectedModel = model
        }
    }
    
    // MARK: - Current Model Properties
    
    private var modelID: String {
        return selectedModel.id
    }
    
    // MARK: - Debug Information
    
    func getDebugInfo() -> [String] {
        var info: [String] = []
        let fileManager = FileManager.default
        
        info.append("🔍 DEBUG INFORMATION")
        info.append("Model ID: \(modelID)")
        info.append("Current Status: \(modelStatus)")
        info.append("")
        
        // App directories
        info.append("📁 APP DIRECTORIES:")
        
        if let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            info.append("Documents: \(documentsDir.path)")
            logDirectoryContents(path: documentsDir.path, into: &info, prefix: "  ")
        }
        
        if let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            info.append("Cache: \(cacheDir.path)")
            logDirectoryContents(path: cacheDir.path, into: &info, prefix: "  ")
        }
        
        if let libraryDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first {
            info.append("Library: \(libraryDir.path)")
            logDirectoryContents(path: libraryDir.path, into: &info, prefix: "  ")
        }
        
        if let tempDir = fileManager.temporaryDirectory as URL? {
            info.append("Temp: \(tempDir.path)")
            logDirectoryContents(path: tempDir.path, into: &info, prefix: "  ")
        }
        
        info.append("")
        info.append("🔍 SEARCHING FOR MODEL FILES:")
        
        // Search for any model-related files
        searchForModelFiles(into: &info)
        
        info.append("")
        info.append("📋 RECENT DEBUG LOGS:")
        info.append(contentsOf: debugLogs.suffix(20))
        
        return info
    }
    
    private func logDirectoryContents(path: String, into info: inout [String], prefix: String, maxDepth: Int = 2, currentDepth: Int = 0) {
        guard currentDepth < maxDepth else { return }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: path)
            let sortedContents = contents.sorted()
            
            for item in sortedContents.prefix(50) { // Limit to prevent too much output
                let itemPath = (path as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                
                if FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        info.append("\(prefix)📁 \(item)/")
                        if currentDepth < maxDepth - 1 {
                            logDirectoryContents(path: itemPath, into: &info, prefix: prefix + "  ", maxDepth: maxDepth, currentDepth: currentDepth + 1)
                        }
                    } else {
                        let fileSize = getFileSize(path: itemPath)
                        info.append("\(prefix)📄 \(item) (\(fileSize))")
                    }
                }
            }
            
            if contents.count > 50 {
                info.append("\(prefix)... and \(contents.count - 50) more items")
            }
        } catch {
            info.append("\(prefix)❌ Error reading directory: \(error.localizedDescription)")
        }
    }
    
    private func searchForModelFiles(into info: inout [String]) {
        let fileManager = FileManager.default
        let searchTerms = ["gemma", "1b", "qat", "4bit", "mlx", "model", "tokenizer", "config"]
        
        func searchDirectory(path: String, depth: Int = 0) {
            guard depth < 4 else { return } // Prevent infinite recursion
            
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: path)
                
                for item in contents {
                    let itemPath = (path as NSString).appendingPathComponent(item)
                    var isDirectory: ObjCBool = false
                    
                    if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                        let lowercaseItem = item.lowercased()
                        
                        // Check if item contains any search terms
                        if searchTerms.contains(where: { lowercaseItem.contains($0) }) {
                            let fileSize = isDirectory.boolValue ? "" : " (\(getFileSize(path: itemPath)))"
                            info.append("  ✅ Found: \(itemPath)\(fileSize)")
                        }
                        
                        // Recursively search subdirectories
                        if isDirectory.boolValue && depth < 3 {
                            searchDirectory(path: itemPath, depth: depth + 1)
                        }
                    }
                }
            } catch {
                // Silently ignore permission errors for system directories
            }
        }
        
        // Search in all app directories
        if let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            searchDirectory(path: documentsDir.path)
        }
        
        if let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            searchDirectory(path: cacheDir.path)
        }
        
        if let libraryDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first {
            searchDirectory(path: libraryDir.path)
        }
    }
    
    private func getFileSize(path: String) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            if let size = attributes[.size] as? Int64 {
                return formatBytes(size)
            }
        } catch {
            // Ignore errors
        }
        return "unknown"
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func addDebugLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)"
        debugLogs.append(logMessage)
        print(logMessage)
        
        // Keep only the last 100 logs
        if debugLogs.count > 100 {
            debugLogs.removeFirst(debugLogs.count - 100)
        }
    }
    
    func checkModelStatus() {
        Task { @MainActor in
            addDebugLog("🔍 Checking model status for: \(modelID)")
            
            // Check if model files exist locally (don't try to load into memory)
            if isModelCached() {
                addDebugLog("📁 Model files found locally")
                self.modelStatus = .downloaded  // Set to downloaded, not loaded
            } else {
                addDebugLog("📭 No local model files found")
                self.modelStatus = .notDownloaded
            }
        }
    }
    
    private func isModelCached() -> Bool {
        addDebugLog("🔍 Starting comprehensive cache check for model: \(selectedModel.displayName)")
        
        let fileManager = FileManager.default
        
        // Check the actual cache directory structure we found
        if let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            addDebugLog("📁 Cache directory: \(cacheDir.path)")
            
            // The key path we found in the logs: models/mlx-community/[model-name]/
            let modelsPath = cacheDir.appendingPathComponent("models")
            addDebugLog("🔍 Checking models path: \(modelsPath.path)")
            
            if fileManager.fileExists(atPath: modelsPath.path) {
                addDebugLog("✅ Found models directory!")
                
                // Check for the exact nested structure: models/mlx-community/[model-directory]/
                let mlxCommunityPath = modelsPath.appendingPathComponent("mlx-community")
                addDebugLog("🔍 Checking mlx-community path: \(mlxCommunityPath.path)")
                
                if fileManager.fileExists(atPath: mlxCommunityPath.path) {
                    addDebugLog("✅ Found mlx-community directory!")
                    
                    do {
                        let mlxContents = try fileManager.contentsOfDirectory(atPath: mlxCommunityPath.path)
                        addDebugLog("📄 mlx-community directory contents: \(mlxContents)")
                        
                        // Look for the specific model directory
                        let modelDirName = selectedModel.directoryName
                        addDebugLog("🔍 Looking for model directory: \(modelDirName)")
                        
                        if mlxContents.contains(modelDirName) {
                            let modelPath = mlxCommunityPath.appendingPathComponent(modelDirName)
                            addDebugLog("✅ Found model directory at: \(modelPath.path)")
                            
                            // Check if it has actual model files
                            do {
                                let modelContents = try fileManager.contentsOfDirectory(atPath: modelPath.path)
                                addDebugLog("📄 Model directory contents: \(modelContents)")
                                
                                let hasModelFiles = modelContents.contains { file in
                                    file.contains("config") ||
                                    file.contains("tokenizer") ||
                                    file.contains(".safetensors") ||
                                    file.contains(".bin") ||
                                    file.contains(".json") ||
                                    file.hasSuffix(".json") ||
                                    file.hasSuffix(".safetensors") ||
                                    file.hasSuffix(".bin")
                                }
                                
                                if hasModelFiles {
                                    addDebugLog("✅ Model files confirmed!")
                                    return true
                                } else {
                                    addDebugLog("⚠️ Model directory exists but no model files found")
                                    // Still return true if the directory exists - it might be downloading
                                    return modelContents.count > 0
                                }
                            } catch {
                                addDebugLog("❌ Error listing model directory contents: \(error)")
                                // If we can't read the directory, assume it exists
                                return true
                            }
                        } else {
                            addDebugLog("❌ Model directory '\(modelDirName)' not found in mlx-community")
                            
                            // Check for any matching models in the directory
                            for item in mlxContents {
                                if item.lowercased().contains("gemma") {
                                    addDebugLog("✅ Found alternative gemma model: \(item)")
                                    // Check if this might be our model with different naming
                                    if selectedModel.id.contains("1b") && item.lowercased().contains("1b") {
                                        return true
                                    } else if selectedModel.id.contains("2b") && item.lowercased().contains("2b") {
                                        return true
                                    }
                                }
                            }
                        }
                    } catch {
                        addDebugLog("❌ Error listing mlx-community directory: \(error)")
                    }
                } else {
                    addDebugLog("❌ mlx-community directory does not exist")
                    
                    // Fallback: check if models directory has any direct model folders
                    do {
                        let contents = try fileManager.contentsOfDirectory(atPath: modelsPath.path)
                        addDebugLog("📄 Models directory contents: \(contents)")
                        
                        // Look for alternative naming patterns
                        let modelVariations = [
                            modelID,
                            modelID.replacingOccurrences(of: "/", with: "--"),
                            modelID.replacingOccurrences(of: "/", with: "_"),
                            selectedModel.directoryName
                        ]
                        
                        for variation in modelVariations {
                            if contents.contains(variation) {
                                let modelPath = modelsPath.appendingPathComponent(variation)
                                addDebugLog("✅ Found model at alternative path: \(modelPath.path)")
                                return true
                            }
                        }
                        
                        // Check for any model-related directories
                        for item in contents {
                            if item.lowercased().contains("gemma") {
                                if (selectedModel.id.contains("1b") && item.lowercased().contains("1b")) ||
                                   (selectedModel.id.contains("2b") && item.lowercased().contains("2b")) {
                                    addDebugLog("✅ Found potential model match: \(item)")
                                    return true
                                }
                            }
                        }
                    } catch {
                        addDebugLog("❌ Error listing models directory: \(error)")
                    }
                }
            } else {
                addDebugLog("❌ Models directory does not exist")
            }
            
            // Also check if there are any other model-related directories
            let otherPaths = [
                ("huggingface/hub", cacheDir.appendingPathComponent("huggingface/hub")),
                ("huggingface/transformers", cacheDir.appendingPathComponent("huggingface/transformers")),
                ("mlx", cacheDir.appendingPathComponent("mlx")),
                ("mlx-models", cacheDir.appendingPathComponent("mlx-models")),
                ("mlx_models", cacheDir.appendingPathComponent("mlx_models"))
            ]
            
            for (name, path) in otherPaths {
                if fileManager.fileExists(atPath: path.path) {
                    addDebugLog("✅ Found additional cache at: \(path.path)")
                    do {
                        let contents = try fileManager.contentsOfDirectory(atPath: path.path)
                        addDebugLog("📄 Contents of \(name): \(contents)")
                        
                        if contents.contains(where: { item in
                            item.contains("gemma") && (
                                (selectedModel.id.contains("1b") && item.contains("1b")) ||
                                (selectedModel.id.contains("2b") && item.contains("2b"))
                            )
                        }) {
                            addDebugLog("✅ Found matching gemma model in \(name)")
                            return true
                        }
                    } catch {
                        addDebugLog("❌ Error checking \(path.path): \(error)")
                    }
                } else {
                    addDebugLog("❌ \(name) directory does not exist")
                }
            }
        }
        
        addDebugLog("❌ No model files found for \(selectedModel.displayName)")
        return false
    }
    
    @MainActor
    func downloadModel() async {
        guard modelStatus != .downloading && modelStatus != .loading else { return }
        
        addDebugLog("🚀 Starting download process...")
        modelStatus = .downloading
        downloadProgress = 0.0
        
        startProgressSimulation()
        
        downloadTask = Task {
            do {
                addDebugLog("🔄 Starting model download for: \(modelID)")
                addDebugLog("📍 Download will begin shortly...")
                
                // Track where MLX tries to download the model
                let fileManager = FileManager.default
                if let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                    addDebugLog("📁 Current cache directory before download: \(cacheDir.path)")
                    
                    // List current contents
                    do {
                        let beforeContents = try fileManager.contentsOfDirectory(atPath: cacheDir.path)
                        addDebugLog("📄 Cache contents before download: \(beforeContents)")
                    } catch {
                        addDebugLog("❌ Error listing cache before download: \(error)")
                    }
                }
                
                // Check if task was cancelled
                if Task.isCancelled {
                    throw CancellationError()
                }
                
                addDebugLog("🎯 Calling loadModelContainer...")
                
                // Just download the model, don't load it into memory yet
                let modelContainer = try await loadModelContainer(id: modelID)
                
                addDebugLog("✅ loadModelContainer completed successfully")
                
                // Check what was downloaded
                if let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                    addDebugLog("📁 Cache directory after download: \(cacheDir.path)")
                    
                    // List contents after download
                    func listContentsRecursively(path: String, depth: Int = 0, maxDepth: Int = 3) {
                        guard depth < maxDepth else { return }
                        
                        do {
                            let contents = try fileManager.contentsOfDirectory(atPath: path)
                            for item in contents.prefix(20) { // Limit output
                                let itemPath = (path as NSString).appendingPathComponent(item)
                                var isDirectory: ObjCBool = false
                                
                                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                                    let indent = String(repeating: "  ", count: depth + 1)
                                    
                                    if isDirectory.boolValue {
                                        addDebugLog("\(indent)📁 \(item)/")
                                        if item.lowercased().contains("model") ||
                                           item.lowercased().contains("gemma") ||
                                           item.lowercased().contains("mlx") ||
                                           item.lowercased().contains("huggingface") {
                                            listContentsRecursively(path: itemPath, depth: depth + 1, maxDepth: maxDepth)
                                        }
                                    } else {
                                        let fileSize = getFileSize(path: itemPath)
                                        addDebugLog("\(indent)📄 \(item) (\(fileSize))")
                                    }
                                }
                            }
                            
                            if contents.count > 20 {
                                let indent = String(repeating: "  ", count: depth + 1)
                                addDebugLog("\(indent)... and \(contents.count - 20) more items")
                            }
                        } catch {
                            let indent = String(repeating: "  ", count: depth + 1)
                            addDebugLog("\(indent)❌ Error listing \(path): \(error)")
                        }
                    }
                    
                    addDebugLog("📄 Full cache structure after download:")
                    listContentsRecursively(path: cacheDir.path)
                }
                
                // Immediately unload from memory to save RAM
                await MainActor.run {
                    self.loadedModelContainer = nil
                }
                
                addDebugLog("✅ Model downloaded successfully (not loaded into memory)")
                
                await MainActor.run {
                    self.stopProgressSimulation()
                    self.modelStatus = .downloaded
                    self.downloadProgress = 1.0
                }
                
            } catch {
                addDebugLog("❌ Download failed with error: \(error)")
                addDebugLog("❌ Error type: \(type(of: error))")
                addDebugLog("❌ Error details: \(error.localizedDescription)")
                
                await MainActor.run {
                    self.stopProgressSimulation()
                    
                    if error is CancellationError {
                        self.modelStatus = .notDownloaded
                    } else {
                        // More detailed error message
                        let errorMessage = self.getDetailedErrorMessage(error)
                        self.modelStatus = .error(errorMessage)
                    }
                    self.downloadProgress = 0.0
                }
            }
        }
    }
    
    @MainActor
    func loadModel() async {
        guard modelStatus == .downloaded else { return }
        
        addDebugLog("🔄 Loading model into memory...")
        modelStatus = .loading
        
        do {
            addDebugLog("🎯 Calling loadModelContainer for loading...")
            let modelContainer = try await loadModelContainer(id: modelID)
            loadedModelContainer = modelContainer
            modelStatus = .loaded
            addDebugLog("✅ Model loaded into memory successfully")
        } catch {
            addDebugLog("❌ Failed to load model: \(error)")
            modelStatus = .error("Failed to load model: \(error.localizedDescription)")
        }
    }
    
    func unloadModel() {
        addDebugLog("🔄 Unloading model from memory...")
        loadedModelContainer = nil
        Task { @MainActor in
            modelStatus = .downloaded
        }
        addDebugLog("✅ Model unloaded from memory")
    }
    
    private func getDetailedErrorMessage(_ error: Error) -> String {
        // For now, return a simple error message
        // You can expand this based on MLX error types
        return "Download failed: \(error.localizedDescription)"
    }
    
    private func startProgressSimulation() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.modelStatus == .downloading else { return }
                
                if self.downloadProgress < 0.9 {
                    self.downloadProgress += 0.02
                }
            }
        }
    }
    
    private func stopProgressSimulation() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    func cancelDownload() {
        addDebugLog("🛑 Canceling download...")
        downloadTask?.cancel()
        downloadTask = nil
        stopProgressSimulation()
        
        Task { @MainActor in
            modelStatus = .notDownloaded
            downloadProgress = 0.0
        }
        
        addDebugLog("✅ Download cancelled")
    }
    
    func deleteModel() {
        addDebugLog("🗑️ Starting model deletion...")
        loadedModelContainer = nil
        
        let fileManager = FileManager.default
        var deletedSomething = false
        
        // Try to delete from the exact path we know it downloads to
        if let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            // Primary target: the exact path we discovered
            let exactModelPath = cacheDir.appendingPathComponent("models/mlx-community/gemma-3-1b-it-qat-4bit")
            addDebugLog("🎯 Targeting exact model path: \(exactModelPath.path)")
            
            if fileManager.fileExists(atPath: exactModelPath.path) {
                do {
                    try fileManager.removeItem(at: exactModelPath)
                    addDebugLog("🗑️ Successfully deleted model at: \(exactModelPath.path)")
                    deletedSomething = true
                } catch {
                    addDebugLog("❌ Failed to delete model at exact path: \(error)")
                }
            } else {
                addDebugLog("⚠️ Exact model path does not exist")
            }
            
            // Also try to delete the entire mlx-community directory if it's empty or only contains our model
            let mlxCommunityPath = cacheDir.appendingPathComponent("models/mlx-community")
            if fileManager.fileExists(atPath: mlxCommunityPath.path) {
                do {
                    let contents = try fileManager.contentsOfDirectory(atPath: mlxCommunityPath.path)
                    addDebugLog("📄 mlx-community contents before cleanup: \(contents)")
                    
                    // If it's empty or only contains our model, delete the whole directory
                    if contents.isEmpty || (contents.count == 1 && contents.first == "gemma-3-1b-it-qat-4bit") {
                        try fileManager.removeItem(at: mlxCommunityPath)
                        addDebugLog("🗑️ Deleted entire mlx-community directory")
                        deletedSomething = true
                    }
                } catch {
                    addDebugLog("❌ Error checking/deleting mlx-community directory: \(error)")
                }
            }
            
            // Fallback: try other possible locations
            let possiblePaths = [
                cacheDir.appendingPathComponent("models").appendingPathComponent(modelID),
                cacheDir.appendingPathComponent("models").appendingPathComponent(modelID.replacingOccurrences(of: "/", with: "--")),
                cacheDir.appendingPathComponent("models").appendingPathComponent(modelID.replacingOccurrences(of: "/", with: "_")),
                cacheDir.appendingPathComponent("huggingface/hub").appendingPathComponent(modelID.replacingOccurrences(of: "/", with: "--")),
                cacheDir.appendingPathComponent("huggingface/transformers").appendingPathComponent(modelID.replacingOccurrences(of: "/", with: "--")),
                cacheDir.appendingPathComponent("mlx").appendingPathComponent(modelID),
                cacheDir.appendingPathComponent("mlx-models").appendingPathComponent(modelID)
            ]
            
            for path in possiblePaths {
                if fileManager.fileExists(atPath: path.path) {
                    do {
                        try fileManager.removeItem(at: path)
                        addDebugLog("🗑️ Deleted fallback model cache at: \(path.path)")
                        deletedSomething = true
                    } catch {
                        addDebugLog("❌ Failed to delete fallback cache at \(path.path): \(error)")
                    }
                }
            }
            
            // Also search for any remaining gemma-related directories and delete them
            func searchAndDelete(in directory: String, depth: Int = 0) {
                guard depth < 3 else { return }
                
                do {
                    let contents = try fileManager.contentsOfDirectory(atPath: directory)
                    for item in contents {
                        if item.lowercased().contains("gemma") && item.lowercased().contains("1b") {
                            let itemPath = (directory as NSString).appendingPathComponent(item)
                            do {
                                try fileManager.removeItem(atPath: itemPath)
                                addDebugLog("🗑️ Deleted potential model directory: \(itemPath)")
                                deletedSomething = true
                            } catch {
                                addDebugLog("❌ Failed to delete \(itemPath): \(error)")
                            }
                        } else {
                            var isDirectory: ObjCBool = false
                            let itemPath = (directory as NSString).appendingPathComponent(item)
                            if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) && isDirectory.boolValue {
                                searchAndDelete(in: itemPath, depth: depth + 1)
                            }
                        }
                    }
                } catch {
                    // Ignore errors when searching
                }
            }
            
            searchAndDelete(in: cacheDir.path)
        }
        
        if deletedSomething {
            addDebugLog("✅ Model deletion completed")
        } else {
            addDebugLog("⚠️ No model files found to delete")
        }
        
        Task { @MainActor in
            modelStatus = .notDownloaded
            downloadProgress = 0.0
        }
    }
    
    @MainActor
    func reloadModel() async {
        guard modelStatus == .downloaded || modelStatus == .loaded else { return }
        
        addDebugLog("🔄 Reloading model...")
        
        if modelStatus == .loaded {
            // Unload first, then reload
            unloadModel()
            try? await Task.sleep(nanoseconds: 500_000_000) // Brief delay
        }
        
        await loadModel()
    }
    
    func getLoadedModelContainer() -> ModelContainer? {
        return loadedModelContainer
    }

    @MainActor
    func loadModelContainerIfNeeded() async -> ModelContainer? {
        addDebugLog("🔄 loadModelContainerIfNeeded – performing hard reload to prevent Metal encoder reuse")

        // Always unload first to guarantee fresh Metal command encoders
        unloadModel()
        try? await Task.sleep(nanoseconds: 300_000_000) // brief pause to let Metal release resources

        await loadModel()
        return loadedModelContainer
    }

}
