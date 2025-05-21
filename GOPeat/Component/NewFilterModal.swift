import SwiftUI

// MARK: - Shared WrappingHStack Utility (if not globally accessible)
// This might be duplicated from PreferencesView.swift; consider moving to a shared file.
struct WrappingStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
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
// MARK: - End Shared Utility

struct NewFilterModal: View {
    @Binding var isPresented: Bool
    @State private var showPreferencesSheet = false
    // These state variables are no longer needed as EditPreferencesView will use PreferenceManager
    // @State private var selectedCantEatFromSheet: Set<String> = []
    // @State private var selectedMoreOptionsFromSheet: Set<String> = []

    // Filter options will now be bindings, managed by the parent view (ModalSearch)
    @Binding var priceMin: String
    @Binding var priceMax: String
    @Binding var selectedFoodTypes: Set<String>
    @Binding var selectedCookingStyles: Set<String>
    @Binding var selectedTasteTypes: Set<String>
    @Binding var selectedCanteens: Set<String>

    // MARK: - Category Definitions for NewFilterModal's primary filters
    // These will now be filtered based on preferences

    private var ignoredCategories: Set<String> {
        PreferenceManager.shared.getIgnoredCategories()
    }

    let foodTypeCategoriesForFilter: [FoodCategory] = [ // Renamed to avoid conflict
        .fish, .mushroom, .soy, .gluten, 
        .chicken, .rice, .seafood, .snacks, .meat, 
        .vegetables, .eggs, .nuts, .porkAndLard
    ]
    let cookingStyleCategoriesForFilter: [FoodCategory] = [ // Renamed to avoid conflict
        .soup, .fried, .steamed, .roasted
    ]
    let tasteTypeCategoriesForFilter: [FoodCategory] = [ // Renamed to avoid conflict
        .sour, .spicy, .sweet, .savory
    ]

    var foodTypesForFilterSwiftUI: [String] { 
        foodTypeCategoriesForFilter.map { $0.rawValue }.filter { !ignoredCategories.contains($0) }.sorted()
    }
    var cookingStylesForFilterSwiftUI: [String] { 
        cookingStyleCategoriesForFilter.map { $0.rawValue }.filter { !ignoredCategories.contains($0) }.sorted()
    }
    var tasteTypesForFilterSwiftUI: [String] { 
        tasteTypeCategoriesForFilter.map { $0.rawValue }.filter { !ignoredCategories.contains($0) }.sorted()
    }

    // MARK: - Data Definitions for EditPreferencesView (to match PreferencesView)
    // Use PreferenceManager for presets and derive options
    var dietaryPresetsForSheet: [String: [FoodCategory]] {
        PreferenceManager.shared.dietaryPresets
    }
    
    let foodTypesForSheet: [FoodCategory] = [
        .fish, .mushroom, .soy, .gluten, 
        .chicken, .rice, .seafood, .snacks, .meat, 
        .vegetables, .eggs, .nuts, .porkAndLard
    ]
    
    let cookingStylesForSheet: [FoodCategory] = [
        .soup, .fried, .steamed, .roasted
    ]
    
    let tasteTypesForSheet: [FoodCategory] = [
        .sour, .spicy, .sweet, .savory
    ]

    var cantEatOptionsForSheet: [String] {
        dietaryPresetsForSheet.keys.sorted()
    }

    var moreOptionsForSheet: [String] {
        let allCategories = foodTypesForSheet + cookingStylesForSheet + tasteTypesForSheet
        return Array(Set(allCategories.map { $0.rawValue })).sorted()
    }

    let canteensList: [String] = ["The Breeze Food Court", "Green Eatery", "GOP 6 Canteen", "GOP 1 Canteen"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Filters")
                            .font(.largeTitle).bold()
                            .foregroundColor(.sample)
                        Spacer()
                        Button("Clear") { 
                            // Clear local filter selections
                            priceMin = ""
                            priceMax = ""
                            selectedFoodTypes.removeAll()
                            selectedCookingStyles.removeAll()
                            selectedTasteTypes.removeAll()
                            selectedCanteens.removeAll()
                            // Optionally, could also offer to clear global preferences here or navigate to EditPreferencesView
                        }
                        .foregroundColor(.sample)
                    }
                    // Price Range
                    VStack(alignment: .leading) {
                        Text("Price Range").font(.headline)
                        HStack {
                            TextField("Rp Minimum", text: $priceMin)
                                .keyboardType(.numberPad)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            Text("-")
                            TextField("Rp Maximum", text: $priceMax)
                                .keyboardType(.numberPad)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    // Food type
                    VStack(alignment: .leading) {
                        Text("Food type").font(.headline)
                        EditViewWrapChips(options: foodTypesForFilterSwiftUI, selectedDirectlyByUser: $selectedFoodTypes)
                    }
                    // Cooking style
                    VStack(alignment: .leading) {
                        Text("Cooking style").font(.headline)
                        EditViewWrapChips(options: cookingStylesForFilterSwiftUI, selectedDirectlyByUser: $selectedCookingStyles)
                    }
                    // Taste type
                    VStack(alignment: .leading) {
                        Text("Taste type").font(.headline)
                        EditViewWrapChips(options: tasteTypesForFilterSwiftUI, selectedDirectlyByUser: $selectedTasteTypes)
                    }
                    // Canteen section
                    VStack(alignment: .leading) {
                        Text("Canteen").font(.headline)
                        ForEach(canteensList, id: \.self) { canteenItem in
                            HStack {
                                Checkbox(
                                    isChecked: selectedCanteens.contains(canteenItem),
                                    action: {
                                        if selectedCanteens.contains(canteenItem) {
                                            selectedCanteens.remove(canteenItem)
                                        } else {
                                            selectedCanteens.insert(canteenItem)
                                        }
                                    }
                                )
                                Text(canteenItem)
                            }
                        }
                    }
                    HStack(spacing: 4) {
                        // Edit Preferences
                        Button(action: { showPreferencesSheet = true }) {
                            Text("Edit Preferences")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .foregroundColor(.sample)
                                .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.sample, lineWidth: 2))
                        }
                        // Show Options Button
                        Button(action: { 
                            // Apply filters and dismiss
                            // This is where you would use selectedFoodTypes, selectedCookingStyles etc.
                            // The ignored categories will be fetched from PreferenceManager.shared.getIgnoredCategories()
                            isPresented = false 
                        }) {
                            Text("Show Options") // Placeholder text, update as needed
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.sample)
                                .foregroundColor(.white)
                                .cornerRadius(25)
                        }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showPreferencesSheet) {
            EditPreferencesView(
                isPresented: $showPreferencesSheet,
                availableCantEatOptions: cantEatOptionsForSheet,
                availableMoreOptions: moreOptionsForSheet
            )
        }
        .onChange(of: showPreferencesSheet) { oldValue, newValue in
            if !newValue && oldValue == true { // When EditPreferencesView is dismissed
                let currentIgnored = PreferenceManager.shared.getIgnoredCategories()
                selectedFoodTypes = selectedFoodTypes.filter { !currentIgnored.contains($0) }
                selectedCookingStyles = selectedCookingStyles.filter { !currentIgnored.contains($0) }
                selectedTasteTypes = selectedTasteTypes.filter { !currentIgnored.contains($0) }
            }
        }
        // Add onAppear to also prune selections when the modal first appears,
        // in case preferences changed while it wasn't visible.
        .onAppear {
            let currentIgnored = PreferenceManager.shared.getIgnoredCategories()
            selectedFoodTypes = selectedFoodTypes.filter { !currentIgnored.contains($0) }
            selectedCookingStyles = selectedCookingStyles.filter { !currentIgnored.contains($0) }
            selectedTasteTypes = selectedTasteTypes.filter { !currentIgnored.contains($0) }
        }
    }
}

// Assuming WrapChips and ChipView are defined here or accessible, similar to PreferencesView.swift
// If they are not here, they would need to be added or imported.
// For this edit, I will assume they are available and proceed to modify EditPreferencesView
// and insert modified WrapChips/ChipView if they are expected to be self-contained in this file.

// If WrapChips and ChipView from PreferencesView are not accessible, redefine them here with the modifications.
// For brevity, let's assume the definitions will be made similar to those in PreferencesView.swift
// The critical part is how EditPreferencesView USES WrapChips.

// --- Start of potential redefinition if needed (otherwise, ensure they are accessible) ---
// Duplicating modified WrapChips and ChipView for EditPreferencesView if not shared
// (Ideally, these would be in a shared file)

// struct WrappingHStack ... (if needed and not globally available)
// struct ViewHeightKey ... (if needed and not globally available)

struct EditViewWrapChips: View { // Renamed to avoid conflict if file has its own WrapChips
    let options: [String]
    @Binding var selectedDirectlyByUser: Set<String>
    var dietaryPresets: [String: [FoodCategory]]? = nil

    private func isOptionEffectivelySelected(_ option: String) -> Bool {
        if selectedDirectlyByUser.contains(option) {
            return true
        }
        if let presets = dietaryPresets {
            for selectedPresetName in selectedDirectlyByUser {
                if let categoriesInSelectedPreset = presets[selectedPresetName] {
                    if categoriesInSelectedPreset.map({ $0.rawValue }).contains(option) {
                        return true
                    }
                }
            }
        }
        return false
    }

    var body: some View {
        // Assuming WrappingHStack is available or defined here
        WrappingHStack(data: options, spacing: 8, lineSpacing: 8) { option in 
            EditViewChipView( // Use renamed ChipView
                text: option,
                isSelected: isOptionEffectivelySelected(option),
                action: {
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

struct EditViewChipView: View { // Renamed ChipView
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
// --- End of potential redefinition --- 

struct EditPreferencesView: View {
    @Binding var isPresented: Bool
    @State private var currentSelectedPreferences: Set<String> = PreferenceManager.shared.getSelectedPreferences()
    
    // Options passed from NewFilterModal
    let availableCantEatOptions: [String] // Preset names
    let availableMoreOptions: [String]  // Individual category names

    // Access to dietary presets definition, similar to PreferencesView
    var dietaryPresetsForEditView: [String: [FoodCategory]] {
        PreferenceManager.shared.dietaryPresets
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Edit preferences")
                .font(.title2.bold())
                .foregroundColor(Color.sample)
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("I can't eat..")
                    .font(.subheadline.bold())
                // Use the (potentially redefined/accessible) WrapChips
                // For preset chips, dietaryPresets arg is not strictly needed for its own selection determination
                EditViewWrapChips(options: availableCantEatOptions, selectedDirectlyByUser: $currentSelectedPreferences)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Or, you need more category...")
                    .font(.subheadline.bold())
                // For individual category chips, pass dietaryPresets to check for implicit selection
                EditViewWrapChips(options: availableMoreOptions, selectedDirectlyByUser: $currentSelectedPreferences, dietaryPresets: self.dietaryPresetsForEditView)
            }
            
            Spacer()

            HStack(spacing: 16) {
                Button(action: { isPresented = false }) {
                    Text("Cancel")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.red, lineWidth: 1))
                }
                Button(action: {
                    PreferenceManager.shared.saveSelectedPreferences(preferences: currentSelectedPreferences)
                    isPresented = false 
                }) {
                    Text("Apply")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.sample)
                        .cornerRadius(25)
                }
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .onAppear {
            currentSelectedPreferences = PreferenceManager.shared.getSelectedPreferences()
        }
    }
} 

struct Checkbox: View {
    var isChecked: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isChecked ? Color.sample : Color.white)
                    .frame(width: 20, height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isChecked ? Color.sample : Color(.systemGray4), lineWidth: 1)
                    )
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
