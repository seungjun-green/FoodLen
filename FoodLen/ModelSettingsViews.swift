//
//  ModelSettings.swift
//  FoodLen
//
//  Created by SeungJun Lee on 8/7/25.
//


import SwiftUI
import MLXVLM
import MLXLMCommon
import UIKit

struct ModelSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var modelManager = ModelManager.shared
    @State private var showingDeleteAlert = false
    @State private var showingModelPicker = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 50))
                            .foregroundColor(.purple)
                        
                        Text("AI Model Settings")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Manage your local AI model for food analysis")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Model Selection Card
                    ModelSelectionCard(
                        selectedModel: modelManager.selectedModel,
                        onModelSelect: { model in
                            modelManager.setSelectedModel(model)
                        }
                    )
                                        
                    // Model Status Card
                    ModelStatusCard(
                        status: modelManager.modelStatus,
                        downloadProgress: modelManager.downloadProgress,
                        modelSize: modelManager.selectedModel.size
                    )
                    
                    // Model Information Card
                    ModelInfoCard(selectedModel: modelManager.selectedModel)
                    
                    // Action Buttons
                    ActionButtonsView(
                        modelStatus: modelManager.modelStatus,
                        onDownload: {
                            Task {
                                await modelManager.downloadModel()
                            }
                        },
                        onDelete: {
                            showingDeleteAlert = true
                        },
                        onLoad: {
                            Task {
                                await modelManager.loadModel()
                            }
                        },
                        onUnload: {
                            modelManager.unloadModel()
                        },
                        onReload: {
                            Task {
                                await modelManager.reloadModel()
                            }
                        },
                        onCancel: {
                            modelManager.cancelDownload()
                        }
                    )
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Delete Model", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    modelManager.deleteModel()
                }
            } message: {
                Text("Are you sure you want to delete the downloaded model? This will free up \(modelManager.selectedModel.size) of storage.")
            }
        }
    }
}

struct ModelSelectionCard: View {
    let selectedModel: ModelOption
    let onModelSelect: (ModelOption) -> Void
    @State private var showingPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet.circle.fill")
                    .foregroundColor(.blue)
                Text("Model Selection")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Button(action: {
                showingPicker = true
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(selectedModel.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            if !selectedModel.isAvailable {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Text(selectedModel.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let reason = selectedModel.unavailabilityReason {
                            Text(reason)
                                .font(.caption)
                                .foregroundColor(.orange)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Spacer()
                    
                    Text(selectedModel.size)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(selectedModel.isAvailable ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                        .foregroundColor(selectedModel.isAvailable ? .blue : .secondary)
                        .cornerRadius(8)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showingPicker) {
            ModelPickerSheet(
                selectedModel: selectedModel,
                onModelSelect: onModelSelect
            )
        }
    }
}

struct ModelPickerSheet: View {
    let selectedModel: ModelOption
    let onModelSelect: (ModelOption) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(ModelOption.availableModels, id: \.id) { model in
                        Button(action: {
                            // Only allow selection if model is available
                            if model.isAvailable {
                                onModelSelect(model)
                                dismiss()
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(model.displayName)
                                            .font(.headline)
                                            .foregroundColor(model.isAvailable ? .primary : .secondary)
                                        
                                        if !model.isAvailable {
                                            Image(systemName: "lock.fill")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    
                                    Text(model.description)
                                        .font(.subheadline)
                                        .foregroundColor(model.isAvailable ? .secondary : .gray)
                                    
                                    HStack {
                                        Text("Size: \(model.size)")
                                            .font(.caption)
                                            .foregroundColor(model.isAvailable ? .secondary : .gray)
                                        
                                        if let reason = model.unavailabilityReason {
                                            Spacer()
                                            Text(reason)
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                                .fontWeight(.medium)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                if model.id == selectedModel.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                } else if !model.isAvailable {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding(.vertical, 4)
                            .opacity(model.isAvailable ? 1.0 : 0.6) // Make unavailable models semi-transparent
                        }
                        .disabled(!model.isAvailable) // Disable button for unavailable models
                    }
                } header: {
                    Text("Available Models")
                } footer: {
                    let deviceRAM = ModelOption.getDeviceRAMInGB()
                    Text("Choose the model that best fits your needs. Your device has \(deviceRAM)GB RAM. Models requiring more RAM are shown but cannot be selected.")
                }
            }
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}


struct ModelStatusCard: View {
    let status: ModelStatus
    let downloadProgress: Double
    let modelSize: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                StatusIndicator(status: status)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model Status")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(modelSize)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            if status == .downloading {
                DownloadProgressView(progress: downloadProgress)
            }
            
            if case .error(let message) = status {
                ErrorDetailsView(message: message)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var statusText: String {
        switch status {
        case .notDownloaded:
            return "Model not downloaded"
        case .downloading:
            return "Downloading model files..."
        case .downloaded:
            return "Model downloaded (not loaded)"
        case .loading:
            return "Loading model into memory..."
        case .loaded:
            return "Model loaded and ready to use"
        case .error:
            return "Error occurred"
        }
    }
}

struct DownloadProgressView: View {
    let progress: Double
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                HStack {
                    Text("Progress")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 2.0)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
            
            HStack {
                Text("Downloading and loading model...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Please wait")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(.top, 4)
    }
}

struct ErrorDetailsView: View {
    let message: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Error Details")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 20)
        }
        .padding(.top, 8)
    }
}

struct ActionButtonsView: View {
    let modelStatus: ModelStatus
    let onDownload: () -> Void
    let onDelete: () -> Void
    let onLoad: () -> Void
    let onUnload: () -> Void
    let onReload: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            switch modelStatus {
            case .notDownloaded:
                DownloadButton(isLoading: false, action: onDownload)
                
            case .downloaded:
                VStack(spacing: 12) {
                    ActionButton(
                        title: "Load Model into Memory",
                        color: .green,
                        action: onLoad
                    )
                    
                    HStack(spacing: 12) {
                        ActionButton(
                            title: "Delete Downloaded Model",
                            color: .red,
                            action: onDelete
                        )
                    }
                }
                
            case .loaded:
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        ActionButton(
                            title: "Unload from Memory",
                            color: .orange,
                            action: onUnload
                        )
                        
                        ActionButton(
                            title: "Reload Model",
                            color: .blue,
                            action: onReload
                        )
                    }
                    
                    ActionButton(
                        title: "Delete Model",
                        color: .red,
                        action: onDelete
                    )
                }
                
            case .downloading:
                ActionButton(
                    title: "Cancel Download",
                    color: .red,
                    action: onCancel
                )
                
            case .error:
                ActionButton(
                    title: "Retry Download",
                    color: .blue,
                    action: onDownload
                )
                
            case .loading:
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading model into memory...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 16)
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(title, action: action)
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }
}

struct StatusIndicator: View {
    let status: ModelStatus
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 50, height: 50)
            
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(.white)
        }
    }
    
    private var backgroundColor: Color {
        switch status {
        case .notDownloaded:
            return .gray
        case .downloading:
            return .blue
        case .downloaded, .loaded:
            return .green
        case .loading:
            return .orange
        case .error:
            return .red
        }
    }
    
    private var iconName: String {
        switch status {
        case .notDownloaded:
            return "arrow.down.circle"
        case .downloading:
            return "arrow.down"
        case .downloaded:
            return "checkmark.circle"
        case .loading:
            return "gearshape"
        case .loaded:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle"
        }
    }
}

struct ModelInfoCard: View {
    let selectedModel: ModelOption
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Model Information")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(title: "Model", value: selectedModel.displayName)
                InfoRow(title: "Quantization", value: "4-bit")
                InfoRow(title: "Privacy", value: "100% local processing")
                InfoRow(title: "Storage Size", value: selectedModel.size)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct DownloadButton: View {
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title3)
                }
                
                Text(isLoading ? "Downloading..." : "Download Model")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isLoading ? [.gray, .gray] : [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: isLoading ? .clear : .blue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isLoading)
    }
}

extension Error {
    var isNetworkError: Bool {
        let description = localizedDescription.lowercased()
        return description.contains("network") ||
               description.contains("connection") ||
               description.contains("timeout") ||
               description.contains("unreachable")
    }
}
