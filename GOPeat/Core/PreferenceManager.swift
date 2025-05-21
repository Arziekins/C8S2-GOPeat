import Foundation

class PreferenceManager {
    static let shared = PreferenceManager()
    private let ignoredCategoriesKey = "ignoredFoodCategories"
    private let selectedPreferencesKey = "selectedUserPreferences" // For storing both presets and individual categories

    // Store the dietary presets definition here for centralized access
    let dietaryPresets: [String: [FoodCategory]] = [
        "Ahimsa": [.meat, .chicken, .fish, .seafood, .eggs],
        "Treif": [.fish, .seafood],
        "Pescatarian": [.meat, .chicken],
        "GERD-Triggers": [.spicy, .fried, .sour]
    ]

    private init() {}

    // Saves the raw selections (can be preset names or category rawValues)
    func saveSelectedPreferences(preferences: Set<String>) {
        UserDefaults.standard.set(Array(preferences), forKey: selectedPreferencesKey)
        // Also update the ignored categories based on these selections
        compileAndSaveIgnoredCategories(selectedPreferences: preferences)
    }

    // Retrieves the raw selections
    func getSelectedPreferences() -> Set<String> {
        guard let preferencesArray = UserDefaults.standard.array(forKey: selectedPreferencesKey) as? [String] else {
            return Set<String>()
        }
        return Set(preferencesArray)
    }
    
    // Compiles selected preferences (expanding presets) into a flat list of ignored FoodCategory rawValues
    private func compileAndSaveIgnoredCategories(selectedPreferences: Set<String>) {
        var categoriesToIgnore = Set<String>()
        for selection in selectedPreferences {
            if let presetCategories = dietaryPresets[selection] {
                for category in presetCategories {
                    categoriesToIgnore.insert(category.rawValue)
                }
            } else {
                // It's an individual category rawValue
                categoriesToIgnore.insert(selection)
            }
        }
        UserDefaults.standard.set(Array(categoriesToIgnore), forKey: ignoredCategoriesKey)
    }

    // This will now return the compiled list of actual FoodCategory rawValues to ignore
    func getIgnoredCategories() -> Set<String> {
        guard let categoriesArray = UserDefaults.standard.array(forKey: ignoredCategoriesKey) as? [String] else {
            // If direct ignored categories are not found (e.g., first launch after update),
            // try to compile them from selectedPreferences
            let selectedPrefs = getSelectedPreferences()
            if !selectedPrefs.isEmpty {
                compileAndSaveIgnoredCategories(selectedPreferences: selectedPrefs)
                // Recurse to get the newly compiled values
                return getIgnoredCategories()
            }
            return Set<String>()
        }
        return Set(categoriesArray)
    }

    func clearAllPreferences() {
        UserDefaults.standard.removeObject(forKey: selectedPreferencesKey)
        UserDefaults.standard.removeObject(forKey: ignoredCategoriesKey)
    }
    
    // Helper function to check if a single food item should be hidden
    func isFoodHidden(_ food: Food) -> Bool {
        let ignored = getIgnoredCategories()
        if ignored.isEmpty {
            return false
        }
        // Check if any of food's categories are in the ignored set
        return !food.categories.allSatisfy { category in
            !ignored.contains(category.rawValue)
        }
    }

    // Helper function to check if a tenant should be hidden
    // This assumes you can get all Food items associated with a tenant.
    // You might need to adjust this based on your data model (e.g., if Tenant has a [Food] property
    // or if you query foods by tenant ID).
    func isTenantHidden(_ tenant: Tenant, allFoodsForTenant: [Food]) -> Bool {
        if allFoodsForTenant.isEmpty { // A tenant with no food items is not explicitly hidden by preference
            return false
        }
        // Tenant is hidden if ALL of its food items are hidden
        return allFoodsForTenant.allSatisfy { isFoodHidden($0) }
    }
} 