import SwiftUI

struct PreferencesView: View {
    @Binding var showOnboarding: Bool
    @State private var selectedPreferences: Set<String> = PreferenceManager.shared.getSelectedPreferences()
    @EnvironmentObject private var locationManager: LocationManager

    // MARK: - Dietary Presets
    var dietaryPresets: [String: [FoodCategory]] {
        PreferenceManager.shared.dietaryPresets
    }
    
    // MARK: - Category Definitions
    let foodTypes: [FoodCategory] = [
        .fish, .mushroom, .soy, .gluten, 
        .chicken, .rice, .seafood, .snacks, .meat, 
        .vegetables, .eggs, .nuts, .porkAndLard // Added .porkAndLard based on Food.swift update
    ]
    
    let cookingStyles: [FoodCategory] = [
        .soup, .fried, .steamed, .roasted
    ]
    
    let tasteTypes: [FoodCategory] = [
        .sour, .spicy, .sweet, .savory
    ]

    // Updated cantEat to use dietaryPreset keys
    var cantEatOptions: [String] {
        dietaryPresets.keys.sorted()
    }

    // Updated moreOptions to combine foodTypes, cookingStyles, and tasteTypes
    var moreOptions: [String] {
        let allCategories = foodTypes + cookingStyles + tasteTypes
        // Use Set to remove duplicates, then map to rawValue, then sort
        return Array(Set(allCategories.map { $0.rawValue })).sorted()
    }

    var body: some View {
        VStack {
            Spacer()
            Image("AppImage") // Replace with your asset name
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 90)
                .padding(.bottom, 16)
            Text("Choose ur preferences..")
                .font(.headline)
                .padding(.bottom, 2)
            Text("Your selection will help us find the best options for you!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)
            VStack(alignment: .leading, spacing: 8) {
                Text("I can't eat..")
                    .font(.subheadline.bold())
                WrapChips(options: cantEatOptions, selectedDirectlyByUser: $selectedPreferences, dietaryPresets: dietaryPresets)
            }
            .padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 8) {
                Text("Or, you need more category...")
                    .font(.subheadline.bold())
                WrapChips(options: moreOptions, selectedDirectlyByUser: $selectedPreferences, dietaryPresets: dietaryPresets)
            }
            Spacer()
            Button(action: { 
                // Save the raw selections (presets and/or individual categories)
                PreferenceManager.shared.saveSelectedPreferences(preferences: selectedPreferences)
                
                // Request location permission when user finishes preferences
                locationManager.requestLocationPermission()
                locationManager.startUpdatingLocation()
                
                // Mark onboarding as completed
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                
                showOnboarding = false 
            }) {
                Text("I'm ready to eat!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.sample)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            Text("Can't find the preference you're looking for?")
                .font(.footnote)
                .foregroundColor(.gray)
            Button(action: {
                if let url = URL(string: "mailto:support@gop-eat.com") {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Contact our Team")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .underline()
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .onAppear {
            // Load previously selected preferences when the view appears
            selectedPreferences = PreferenceManager.shared.getSelectedPreferences()
        }
    }
}

// --- WrappingHStack Utility ---
struct WrappingHStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let lineSpacing: CGFloat
    let content: (Data.Element) -> Content

    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(data, id: \.self) { item in
                content(item)
                    .padding(.trailing, spacing)
                    .alignmentGuide(.leading, computeValue: { d in
                        if abs(width - d.width) > geometry.size.width {
                            width = 0
                            height -= d.height + lineSpacing
                        }
                        let result = width
                        if let lastItem = data.last, item == lastItem {
                            width = 0 // Last item
                        } else {
                            width -= d.width + spacing
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let result = height
                        if let lastItem = data.last, item == lastItem {
                            height = 0 // Last item
                        }
                        return result
                    })
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ViewHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(ViewHeightKey.self) { value in
            self.totalHeight = value
        }
    }
}

private struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// --- WrapChips using WrappingHStack ---
struct WrapChips: View {
    let options: [String] // These are the rawValue strings for categories or preset names
    @Binding var selectedDirectlyByUser: Set<String>
    
    // Pass dietaryPresets only when 'options' are individual categories (e.g., "moreOptions")
    // to enable checking for implicit selection by a preset.
    var dietaryPresets: [String: [FoodCategory]]? = nil

    private func isOptionEffectivelySelected(_ option: String) -> Bool {
        // 1. Is the option directly selected by the user?
        if selectedDirectlyByUser.contains(option) {
            return true
        }

        // 2. If dietaryPresets are provided, check if this option is part of any *directly selected* preset.
        // This applies when 'option' is an individual category rawValue.
        if let presets = dietaryPresets {
            for selectedPresetName in selectedDirectlyByUser { // Iterate through directly selected items
                if let categoriesInSelectedPreset = presets[selectedPresetName] { // Check if it's a known preset
                    if categoriesInSelectedPreset.map({ $0.rawValue }).contains(option) {
                        return true // The current 'option' is part of this selected preset
                    }
                }
            }
        }
        return false
    }

    var body: some View {
        WrappingHStack(
            data: options,
            spacing: 8,
            lineSpacing: 8
        ) { option in // 'option' is a String (either a preset name or a FoodCategory.rawValue)
            ChipView(
                text: option,
                // Use the enhanced logic for isSelected
                isSelected: isOptionEffectivelySelected(option),
                action: {
                    // This action always toggles the *direct* selection state of the 'option'
                    if selectedDirectlyByUser.contains(option) {
                        selectedDirectlyByUser.remove(option)
                    } else {
                        selectedDirectlyByUser.insert(option)
                    }
                }
            )
            .padding(.vertical, 2)
        }
    }
}

// --- ChipView remains unchanged ---
struct ChipView: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 0) {
                Text(text)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(isSelected ? Color.green.opacity(0.2) : Color(.systemBackground))
            .foregroundColor(isSelected ? .green : .gray)
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .inset(by: 0.37)
                    .stroke(isSelected ? Color.green : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

#Preview {
    
}
