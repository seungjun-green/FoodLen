//
//  ProfileSetting.swift
//  FoodLen
//
//  Created by SeungJun Lee on 8/6/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Selected indices stored in UserDefaults
    @State private var selectedAllergies: Set<Int> = []
    @State private var selectedDietaryTypes: Set<Int> = []
    @State private var selectedHealthConditions: Set<Int> = []
    @State private var selectedFoodPreferences: Set<Int> = []
    
    // Static arrays (same as CheckListViews)
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
    
    @State private var showResetAlert = false
    @State private var hasUnsavedChanges = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    
                    // Header with current summary
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Dietary Settings")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Manage your dietary preferences and restrictions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Current Summary Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Current Profile Summary:")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(currentSummary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.bottom, 10)
                    }
                    
                    // Settings Sections
                    SettingsSection(
                        title: "🚨 Allergies & Intolerances",
                        subtitle: "Critical for your safety",
                        items: Self.allergies,
                        selectedIndices: $selectedAllergies,
                        hasChanges: $hasUnsavedChanges
                    )
                    
                    SettingsSection(
                        title: "🥗 Dietary Types",
                        subtitle: "Your lifestyle choices",
                        items: Self.dietaryTypes,
                        selectedIndices: $selectedDietaryTypes,
                        hasChanges: $hasUnsavedChanges
                    )
                    
                    SettingsSection(
                        title: "🏥 Health Conditions",
                        subtitle: "Medical dietary requirements",
                        items: Self.healthConditions,
                        selectedIndices: $selectedHealthConditions,
                        hasChanges: $hasUnsavedChanges
                    )
                    
                    SettingsSection(
                        title: "⭐ Food Preferences",
                        subtitle: "Your personal preferences",
                        items: Self.foodPreferences,
                        selectedIndices: $selectedFoodPreferences,
                        hasChanges: $hasUnsavedChanges
                    )
                    
                    // Reset Button
                    VStack(spacing: 15) {
                        Divider()
                        
                        Button("Reset All Preferences") {
                            showResetAlert = true
                        }
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.top, 20)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            loadPreferences() // Revert changes
                        }
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePreferences()
                        hasUnsavedChanges = false
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasUnsavedChanges)
                }
            }
        }
        .onAppear {
            loadPreferences()
        }
        .alert("Reset All Preferences", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllPreferences()
            }
        } message: {
            Text("This will clear all your dietary preferences and restrictions. This action cannot be undone.")
        }
    }
    
    // Computed property for current summary
    var currentSummary: String {
        var summary = ""
        
        let allergies = selectedAllergies.map { Self.allergies[$0] }
        if !allergies.isEmpty {
            summary += "Allergies: \(allergies.joined(separator: ", "))\n"
        }
        
        let dietary = selectedDietaryTypes.map { Self.dietaryTypes[$0] }
        if !dietary.isEmpty {
            summary += "Dietary: \(dietary.joined(separator: ", "))\n"
        }
        
        let health = selectedHealthConditions.map { Self.healthConditions[$0] }
        if !health.isEmpty {
            summary += "Health: \(health.joined(separator: ", "))\n"
        }
        
        let preferences = selectedFoodPreferences.map { Self.foodPreferences[$0] }
        if !preferences.isEmpty {
            summary += "Preferences: \(preferences.joined(separator: ", "))"
        }
        
        return summary.isEmpty ? "No preferences selected" : summary
    }
    
    private func loadPreferences() {
        selectedAllergies = Set(UserDefaults.standard.array(forKey: "selectedAllergies") as? [Int] ?? [])
        selectedDietaryTypes = Set(UserDefaults.standard.array(forKey: "selectedDietaryTypes") as? [Int] ?? [])
        selectedHealthConditions = Set(UserDefaults.standard.array(forKey: "selectedHealthConditions") as? [Int] ?? [])
        selectedFoodPreferences = Set(UserDefaults.standard.array(forKey: "selectedFoodPreferences") as? [Int] ?? [])
        hasUnsavedChanges = false
    }
    
    private func savePreferences() {
        UserDefaults.standard.set(Array(selectedAllergies), forKey: "selectedAllergies")
        UserDefaults.standard.set(Array(selectedDietaryTypes), forKey: "selectedDietaryTypes")
        UserDefaults.standard.set(Array(selectedHealthConditions), forKey: "selectedHealthConditions")
        UserDefaults.standard.set(Array(selectedFoodPreferences), forKey: "selectedFoodPreferences")
    }
    
    private func resetAllPreferences() {
        selectedAllergies.removeAll()
        selectedDietaryTypes.removeAll()
        selectedHealthConditions.removeAll()
        selectedFoodPreferences.removeAll()
        hasUnsavedChanges = true
    }
}

struct SettingsSection: View {
    let title: String
    let subtitle: String
    let items: [String]
    @Binding var selectedIndices: Set<Int>
    @Binding var hasChanges: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Section Header
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Selection count badge
                    if !selectedIndices.isEmpty {
                        Text("\(selectedIndices.count)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Items Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    SettingsCheckboxItem(
                        text: item,
                        isSelected: selectedIndices.contains(index)
                    ) {
                        if selectedIndices.contains(index) {
                            selectedIndices.remove(index)
                        } else {
                            selectedIndices.insert(index)
                        }
                        hasChanges = true
                    }
                }
            }
            
            // Quick Actions for this section
            if !selectedIndices.isEmpty {
                HStack {
                    Button("Clear All") {
                        selectedIndices.removeAll()
                        hasChanges = true
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button("Select All") {
                        selectedIndices = Set(items.indices)
                        hasChanges = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.top, 5)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 5)
        .background(Color.gray.opacity(0.03))
        .cornerRadius(12)
    }
}

struct SettingsCheckboxItem: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: 16))
                
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

