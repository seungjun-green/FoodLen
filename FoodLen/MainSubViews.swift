//
//  SubViews.swift
//  FoodLen
//
//  Created by SeungJun Lee on 8/6/25.
//

import Foundation
import SwiftUI
import MLXVLM
import MLXLMCommon
import UniformTypeIdentifiers
import Vision
import VisionKit

struct DietaryProfileCard: View {
    let summary: String
    let onEditTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("Your Dietary Profile")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Edit", action: onEditTap)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(16)
            }
            
            Text(summary)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(nil)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct CameraSection: View {
    let capturedImages: [UIImage]
    let onCameraTap: () -> Void
    let onImageRemove: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            if !capturedImages.isEmpty {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "photo.fill")
                            .foregroundColor(.green)
                        Text("Captured Images (\(capturedImages.count))")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        
                        Button("Add More") {
                            onCameraTap()
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(16)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(capturedImages.enumerated()), id: \.offset) { index, image in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 160, height: 120)
                                        .clipped()
                                        .cornerRadius(16)
                                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                    
                                    Button(action: {
                                        onImageRemove(index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.black.opacity(0.6)))
                                    }
                                    .offset(x: -4, y: 4)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.horizontal, -16)
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            } else {
                Button(action: onCameraTap) {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 80, height: 80)
                                .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 4) {
                            Text("Take a Photo")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Scan food labels and ingredients")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct ActionButtonsSection: View {
    let isProcessing: Bool
    let modelStatus: ModelStatus
    let onProcess: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: onProcess) {
                HStack(spacing: 12) {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.title3)
                    }
                    
                    Text(buttonText)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(buttonBackground)
                .cornerRadius(16)
                .shadow(color: shadowColor, radius: 8, x: 0, y: 4)
            }
            .disabled(isProcessing || !isModelReady)
            .animation(.easeInOut(duration: 0.2), value: isProcessing)
            
            if !isModelReady {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text(modelStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var isModelReady: Bool {
        switch modelStatus {
        case .loaded:
            return true
        default:
            return false
        }
    }
    
    private var buttonText: String {
        if isProcessing {
            return "Analyzing..."
        } else if !isModelReady {
            return "Model Required"
        } else {
            return "Analyze Food Safety"
        }
    }
    
    private var buttonBackground: LinearGradient {
        if isProcessing || !isModelReady {
            return LinearGradient(colors: [.gray, .gray], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    private var shadowColor: Color {
        isModelReady && !isProcessing ? .green.opacity(0.3) : .clear
    }
    
    private var modelStatusText: String {
        switch modelStatus {
        case .notDownloaded:
            return "Download model in settings to analyze food"
        case .downloading:
            return "Model downloading... Please wait"
        case .loading:
            return "Loading model... Please wait"
        case .error(let message):
            return "Model error: \(message)"
        default:
            return ""
        }
    }
}

struct AIResponseSection: View {
    let responseText: String
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text("AI Analysis")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                
                if !isLoading && !responseText.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            if isLoading && responseText.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                        .scaleEffect(1.2)
                    
                    Text("Analyzing ingredients and checking compatibility...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if !responseText.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(responseText.components(separatedBy: .newlines).enumerated()), id: \.offset) { index, line in
                            formatLine(line)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    @ViewBuilder
    private func formatLine(_ line: String) -> some View {
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            Text(" ")
                .font(.caption)
        } else if line.hasPrefix("**") && line.hasSuffix("**") {
            Text(line.replacingOccurrences(of: "**", with: ""))
                .font(.body)
                .fontWeight(.bold)
        } else {
            buildTextWithInlineBold(line)
        }
    }
    
    private func buildTextWithInlineBold(_ line: String) -> Text {
        var result = Text("")
        var remaining = line
        
        while !remaining.isEmpty {
            if let startRange = remaining.range(of: "**") {
                let beforeBold = String(remaining[..<startRange.lowerBound])
                if !beforeBold.isEmpty {
                    result = result + Text(beforeBold)
                }
                
                let afterStart = remaining[startRange.upperBound...]
                if let endRange = afterStart.range(of: "**") {
                    let boldText = String(afterStart[..<endRange.lowerBound])
                    result = result + Text(boldText).bold()
                    remaining = String(afterStart[endRange.upperBound...])
                } else {
                    result = result + Text(remaining)
                    break
                }
            } else {
                result = result + Text(remaining)
                break
            }
        }
        
        return result
    }
}

struct ModernCameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var parsedText: String
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ModernCameraView
        
        init(_ parent: ModernCameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.capturedImage = image
                parent.performTextDetection(on: image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
    
    func performTextDetection(on image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("Text detection error: \(error)")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            let detectedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            DispatchQueue.main.async {
                self.parsedText = detectedText
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform text detection: \(error)")
        }
    }
}

struct CheckListViews: View {
    @Binding var isFirstTimeUser: Bool
    @Environment(\.dismiss) private var dismiss
    
    static let allergies = [
        "Milk/Dairy", "Eggs", "Peanuts", "Tree Nuts", "Fish", "Shellfish",
        "Soy", "Wheat/Gluten", "Sesame", "Corn", "Mustard", "Celery", "Sulfites"
    ]
    
    static let dietaryTypes = [
        "Vegan", "Vegetarian", "Pescatarian", "Keto/Low-Carb", "Paleo",
        "Halal", "Kosher", "Mediterranean", "Low-Sodium", "Diabetic-Friendly"
    ]
    
    static let healthConditions = [
        "Diabetes", "Hypertension", "Pregnancy", "Lactose Intolerance",
        "Celiac Disease", "Heart Disease", "Kidney Disease", "High Cholesterol"
    ]
    
    static let foodPreferences = [
        "Organic Only", "Low Sugar", "High Protein", "Low Fat",
        "No Artificial Colors", "No Preservatives", "Gluten-Free", "Raw Food"
    ]
    
    @State private var selectedAllergies: Set<Int> = []
    @State private var selectedDietaryTypes: Set<Int> = []
    @State private var selectedHealthConditions: Set<Int> = []
    @State private var selectedFoodPreferences: Set<Int> = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Set Up Your Dietary Profile")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Select all that apply to help us keep you safe and healthy.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 10)
                    
                    CheckboxSection(
                        title: "🚨 Allergies & Intolerances",
                        subtitle: "Critical for your safety",
                        items: Self.allergies,
                        selectedIndices: $selectedAllergies
                    )
                    
                    CheckboxSection(
                        title: "🥗 Dietary Types",
                        subtitle: "Your lifestyle choices",
                        items: Self.dietaryTypes,
                        selectedIndices: $selectedDietaryTypes
                    )
                    
                    CheckboxSection(
                        title: "🏥 Health Conditions",
                        subtitle: "Medical dietary requirements",
                        items: Self.healthConditions,
                        selectedIndices: $selectedHealthConditions
                    )
                    
                    CheckboxSection(
                        title: "⭐ Food Preferences",
                        subtitle: "Your personal preferences",
                        items: Self.foodPreferences,
                        selectedIndices: $selectedFoodPreferences
                    )
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isFirstTimeUser {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePreferences()
                        isFirstTimeUser = false
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadPreferences()
        }
    }
    
    private func loadPreferences() {
        selectedAllergies = Set(UserDefaults.standard.array(forKey: "selectedAllergies") as? [Int] ?? [])
        selectedDietaryTypes = Set(UserDefaults.standard.array(forKey: "selectedDietaryTypes") as? [Int] ?? [])
        selectedHealthConditions = Set(UserDefaults.standard.array(forKey: "selectedHealthConditions") as? [Int] ?? [])
        selectedFoodPreferences = Set(UserDefaults.standard.array(forKey: "selectedFoodPreferences") as? [Int] ?? [])
    }
    
    private func savePreferences() {
        UserDefaults.standard.set(Array(selectedAllergies), forKey: "selectedAllergies")
        UserDefaults.standard.set(Array(selectedDietaryTypes), forKey: "selectedDietaryTypes")
        UserDefaults.standard.set(Array(selectedHealthConditions), forKey: "selectedHealthConditions")
        UserDefaults.standard.set(Array(selectedFoodPreferences), forKey: "selectedFoodPreferences")
    }
}

struct CheckboxSection: View {
    let title: String
    let subtitle: String
    let items: [String]
    @Binding var selectedIndices: Set<Int>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    Button(action: {
                        if selectedIndices.contains(index) {
                            selectedIndices.remove(index)
                        } else {
                            selectedIndices.insert(index)
                        }
                    }) {
                        HStack {
                            Image(systemName: selectedIndices.contains(index) ? "checkmark.square.fill" : "square")
                                .foregroundColor(selectedIndices.contains(index) ? .blue : .gray)
                            
                            Text(item)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedIndices.contains(index) ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedIndices.contains(index) ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Extracted Text Preview Component
struct ExtractedTextPreview: View {
    let extractedTexts: [String]
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.viewfinder")
                    .foregroundColor(.green)
                Text("Extracted Text (\(extractedTexts.count) image\(extractedTexts.count == 1 ? "" : "s"))")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(isExpanded ? "Hide" : "Show") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if isExpanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(extractedTexts.enumerated()), id: \.offset) { index, text in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Image \(index + 1):")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                Text(text.isEmpty ? "No text detected" : text)
                                    .font(.caption)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}
