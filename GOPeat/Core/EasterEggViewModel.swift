import SwiftUI
import SwiftData
import UIKit // For Haptic Feedback

class EasterEggViewModel: ObservableObject {
    @Published var presentFullscreenFoodDetail: Bool = false
    @Published var selectedFoodDetails: (name: String, desc: String, categories: String, tenantName: String, canteenName: String)? = nil

    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // Returns true if the "bingung" button should be shown in ModalSearch
    func checkForEasterEggTrigger(searchTerm: String) -> Bool {
        return searchTerm.lowercased() == "bingung"
    }

    func prepareAndShowRandomFoodPopup() {
        // 1. Fetch all Tenants
        let tenantDescriptor = FetchDescriptor<Tenant>(
            sortBy: [SortDescriptor<Tenant>(\.name)]
        )
        
        guard let allTenants = try? modelContext.fetch(tenantDescriptor) else {
            // Handle error or return if no tenants
            print("Error fetching tenants or no tenants found.")
            self.selectedFoodDetails = nil
            self.presentFullscreenFoodDetail = false
            return
        }

        var allPermissibleFoods: [Food] = []
        for tenant in allTenants {
            for food in tenant.foods { // Assuming Tenant has a 'foods' relationship
                if !PreferenceManager.shared.isFoodHidden(food) {
                    allPermissibleFoods.append(food)
                }
            }
        }

        if let randomFood = allPermissibleFoods.randomElement() {
            let categoriesString = randomFood.categories.map { $0.rawValue }.joined(separator: ", ")
            self.selectedFoodDetails = (
                name: randomFood.name,
                desc: randomFood.desc,
                categories: categoriesString,
                tenantName: randomFood.tenant?.name ?? "Unknown Tenant",
                canteenName: randomFood.tenant?.canteen?.name ?? "Unknown Canteen"
            )
            
            // Haptic feedback
            let haptic = UIImpactFeedbackGenerator(style: .medium)
            haptic.impactOccurred()
            
            self.presentFullscreenFoodDetail = true
        } else {
            // No permissible food found
            print("No permissible food found for the easter egg.")
            self.selectedFoodDetails = (name: "No Food Found!", desc: "No suitable food items match your preferences right now.", categories: "", tenantName: "System", canteenName: "GOPeat")
            self.presentFullscreenFoodDetail = true
        }
    }
} 