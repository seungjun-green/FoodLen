//
//  ContentView.swift
//  FoodLen
//
//  Created by SeungJun Lee on 8/6/25.
//
import SwiftUI
import MLXVLM
import MLXLMCommon
import MLX
import UniformTypeIdentifiers
import Vision
import VisionKit

// MARK: – Inference state machine
private enum InferenceState {
    case idle
    case running(Task<Void, Never>)
    case cancelling
}

// MARK: – ContentView
struct ContentView: View {
    // UI State
    @State private var isModelLoading = false
    @State private var streamedText = ""
    @State private var parsedText = ""

    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showCheckListViews = false
    @State private var showModelSettings = false

    // Model / Inference
    @ObservedObject private var modelManager = ModelManager.shared
    @State private var inferenceState: InferenceState = .idle
    @State private var currentChatSession: ChatSession?

    // Background handling
    @State private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("firstTimeUser") private var isFirstTimeUser = true
    
    // Multi-image support
    @State private var capturedImages: [UIImage] = []
    @State private var extractedTexts: [String] = [] 
    @State private var isProcessingImages = false

    // MARK: body
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                if !isFirstTimeUser {
                    DietaryProfileCard(summary: selectedItemsSummary) { showCheckListViews = true }
                }

                CameraSection(
                    capturedImages: capturedImages,
                    onCameraTap: { showCamera = true },
                    onImageRemove: { index in
                        capturedImages.remove(at: index)
                        // Also remove corresponding extracted text
                        if index < extractedTexts.count {
                            extractedTexts.remove(at: index)
                        }
                    }
                )
                
                // Show extracted text preview
                if !extractedTexts.isEmpty {
                    ExtractedTextPreview(extractedTexts: extractedTexts)
                }
                
                ActionButtonsSection(
                    isProcessing: isModelLoading || isProcessingImages,
                    modelStatus: modelManager.modelStatus
                ) {
                    Task { await startInference() }
                }
                AIResponseSection(responseText: streamedText, isLoading: isModelLoading)
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .background(
            LinearGradient(colors: [Color(.systemBackground), Color(.systemGray6)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .sheet(isPresented: $showCamera)         { ModernCameraView(capturedImage: $capturedImage, parsedText: $parsedText) }
        .sheet(isPresented: $showCheckListViews) { CheckListViews(isFirstTimeUser: $isFirstTimeUser) }
        .sheet(isPresented: $showModelSettings)  { ModelSettingsView() }
        .onAppear { if isFirstTimeUser { showCheckListViews = true } }
        .onChange(of: capturedImage) { _, newImage in
            if let newImage = newImage {
                capturedImages.append(newImage)
                capturedImage = nil // Reset for next capture
                
                // Process the new image to extract text
                Task {
                    await extractTextFromNewImage(newImage)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .inactive || phase == .background {
                Task { await cancelIfNeeded(reason: "App moved to background.") }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            Task { await cancelIfNeeded(reason: "App became inactive.") }
        }
    }

    // MARK: header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("FoodLens").font(.largeTitle).bold()
                Text("Scan ingredients and check dietary compatibility")
                    .font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            Button { showModelSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2).foregroundColor(.gray)
                    .padding(8).background(Color.gray.opacity(0.1)).cornerRadius(10)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Extract text from newly captured image
    private func extractTextFromNewImage(_ image: UIImage) async {
        await MainActor.run {
            isProcessingImages = true
        }
        
        let extractedText = await extractTextFromImage(image)
        
        await MainActor.run {
            extractedTexts.append(extractedText)
            isProcessingImages = false
        }
    }
    
    // MARK: - Extract text from image using Vision
    private func extractTextFromImage(_ image: UIImage) async -> String {
        guard let cgImage = image.cgImage else {
            return "Failed to process image"
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("Text recognition error: \(error)")
                    continuation.resume(returning: "Error extracting text: \(error.localizedDescription)")
                    return
                }
                
                let recognizedStrings = request.results?.compactMap { result in
                    (result as? VNRecognizedTextObservation)?.topCandidates(1).first?.string
                } ?? []
                
                let combinedText = recognizedStrings.joined(separator: "\n")
                continuation.resume(returning: combinedText.isEmpty ? "No text detected in image" : combinedText)
            }
            
            // Configure for better ingredient detection
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "Failed to process image: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Process all images before inference
    private func processAllImages() async -> String {
        if capturedImages.isEmpty {
            return "No images captured"
        }
        
        // If we don't have extracted text for all images, process them
        if extractedTexts.count != capturedImages.count {
            await MainActor.run {
                isProcessingImages = true
                extractedTexts.removeAll()
            }
            
            for image in capturedImages {
                let text = await extractTextFromImage(image)
                await MainActor.run {
                    extractedTexts.append(text)
                }
            }
            
            await MainActor.run {
                isProcessingImages = false
            }
        }
        
        // Combine all extracted texts
        let allIngredients = extractedTexts
            .enumerated()
            .map { index, text in
                if text.isEmpty || text == "No text detected in image" {
                    return "Image \(index + 1): No ingredients detected"
                } else {
                    return "Image \(index + 1) ingredients:\n\(text)"
                }
            }
            .joined(separator: "\n\n")
        
        return allIngredients
    }

    // MARK: start / cancel
    private func startInference() async {
        await cancelIfNeeded(reason: "Reset before new inference")

        guard case .idle = inferenceState else { return }
        guard UIApplication.shared.applicationState == .active else {
            await MainActor.run { streamedText = "⚠️ App is not active." }
            return
        }

        // Process all images first
        let allIngredientsText = await processAllImages()

        // Load (or reuse) the model container once per app lifetime
        let container: ModelContainer
        do {
            if let loadedContainer = modelManager.getLoadedModelContainer() {
                container = loadedContainer
            } else {
                // Load model if needed
                if modelManager.modelStatus != .loaded {
                    await modelManager.loadModel()
                }
                
                guard let loadedContainer = modelManager.getLoadedModelContainer() else {
                    await MainActor.run {
                        streamedText = "❌ Model failed to load"
                        isModelLoading = false
                    }
                    return
                }
                container = loadedContainer
            }
        }

        // Prepare a new chat session
        let session = ChatSession(container)
        currentChatSession = session

        await MainActor.run {
            isModelLoading = true
            streamedText   = ""
        }

        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "ModelInference") {
            Task { await cancelIfNeeded(reason: "Background task expired.") }
        }

        let task = Task { await runInferenceLoop(with: allIngredientsText) }
        inferenceState = .running(task)
    }

    private func cancelIfNeeded(reason: String) async {
        guard case .running(let task) = inferenceState else { return }
        inferenceState = .cancelling

        task.cancel()
        _ = await task.result

        currentChatSession = nil

        await MainActor.run {
            isModelLoading = false
            streamedText   = "⚠️ Analysis interrupted.\n" + reason
        }

        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }

        inferenceState = .idle
    }

    // MARK: core loop
    private func runInferenceLoop(with ingredientsText: String) async {
        defer { inferenceState = .idle }

        guard let session = currentChatSession else {
            await MainActor.run { streamedText = "❌ No active session." }
            return
        }

        do {
            try Task.checkCancellation()

            var response = ""
            let prompt = createEnhancedAnalysisPrompt(with: ingredientsText)

            for try await chunk in session.streamResponse(to: prompt) {
                try Task.checkCancellation()
                if let end = chunk.range(of: "<end_of_turn>") {
                    response += String(chunk[..<end.lowerBound])
                    break
                }
                response += chunk
                await MainActor.run { streamedText = response }
            }
            await MainActor.run { streamedText = response }
        } catch is CancellationError {
            // cancellation handled by cancelIfNeeded
        } catch {
            await MainActor.run { streamedText = "❌ Analysis error: \(error.localizedDescription)" }
        }

        currentChatSession = nil

        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }

        await MainActor.run { isModelLoading = false }
    }

    // MARK: helpers
    private var selectedItemsSummary: String {
        func names(for key: String, source: [String]) -> [String] {
            (UserDefaults.standard.array(forKey: key) as? [Int] ?? []).map { source[$0] }
        }
        return [
            names(for: "selectedAllergies",        source: CheckListViews.allergies).nilIfEmpty().map { "Allergies: \($0.joined(separator: ", "))" },
            names(for: "selectedDietaryTypes",     source: CheckListViews.dietaryTypes).nilIfEmpty().map { "Dietary: \($0.joined(separator: ", "))" },
            names(for: "selectedHealthConditions", source: CheckListViews.healthConditions).nilIfEmpty().map { "Health: \($0.joined(separator: ", "))" },
            names(for: "selectedFoodPreferences",  source: CheckListViews.foodPreferences).nilIfEmpty().map { "Preferences: \($0.joined(separator: ", "))" }
        ].compactMap { $0 }.joined(separator: "\n").ifEmpty("No preferences selected")
    }

    // MARK: - Enhanced prompt creation
    private func createEnhancedAnalysisPrompt(with ingredientsText: String) -> String {
        let profile = selectedItemsSummary
//        let imageCount = capturedImages.count
        
        return #"""
You are FoodLens AI, a dietary safety assistant. Analyze the ingredients below based on the user's dietary profile.

USER DIETARY PROFILE:
\#(profile)

DETECTED INGREDIENTS FROM #(imageCount) IMAGE(S):
\#(ingredientsText)

Return your answer in the following format:

🔍 SAFETY VERDICT: [SAFE ✅ / CAUTION ⚠️ / NOT SAFE ❌]

Reasons:
Briefly explain the reasons

"""#
    }
}



// MARK: convenience ext
private extension Array where Element == String {
    func nilIfEmpty() -> [String]? { isEmpty ? nil : self }
}

private extension String {
    func ifEmpty(_ replacement: String) -> String { isEmpty ? replacement : self }
}
