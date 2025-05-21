import MapKit
import SwiftData
import SwiftUI

// Structure to hold search results, separating visible and hidden items
struct CategorizedSearchResults: Equatable {
    var visibleTenants: [Tenant] = []
    var hiddenTenantNames: [String] = [] // Names of tenants hidden by preference
    var visibleFoodsByTenant: [Tenant.ID: [Food]] = [:] // Foods that are visible and match search, grouped by tenant
    var hiddenFoodNames: [String] = [] // Names of foods directly searched and hidden
    // Add a property to track if the nearest filter resulted in no canteens (e.g. location services off)
    var noNearestCanteenFound: Bool = false
}

class TenantSearchViewModel: ObservableObject {
    @Published var searchTerm: String = "" {
        didSet {
            performSearchInternal()
        }
    }
    // Filter criteria from NewFilterModal
    @Published var priceMin: String = "" { didSet { performSearchInternal() } }
    @Published var priceMax: String = "" { didSet { performSearchInternal() } }
    @Published var selectedFoodTypes: Set<String> = [] { didSet { performSearchInternal() } }
    @Published var selectedCookingStyles: Set<String> = [] { didSet { performSearchInternal() } }
    @Published var selectedTasteTypes: Set<String> = [] { didSet { performSearchInternal() } }
    @Published var selectedCanteenNames: Set<String> = [] { didSet { performSearchInternal() } }

    // New filter states
    @Published var isNearestFilterActive: Bool = false { didSet { performSearchInternal() } }
    @Published var isOpenNowFilterActive: Bool = false { didSet { performSearchInternal() } }
    @Published var currentUserLocation: CLLocationCoordinate2D? { didSet { performSearchInternal() } }

    @Published var sheeHeight: PresentationDetent = .fraction(0.1)
    @Published var categorizedResults = CategorizedSearchResults()
    @Published var recentSearch: [String] = []
    
    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        performSearchInternal()
    }

    func clearAllModalFilters() {
        priceMin = ""
        priceMax = ""
        selectedFoodTypes.removeAll()
        selectedCookingStyles.removeAll()
        selectedTasteTypes.removeAll()
        selectedCanteenNames.removeAll()
        // isNearestFilterActive = false // Decide if these should also be cleared
        // isOpenNowFilterActive = false 
        // searchTerm = "" 
        // performSearchInternal() will be called by an empty searchTerm's didSet if uncommented above,
        // or by each property's didSet if they are cleared individually.
    }

    private func parsePriceRange(priceRangeString: String) -> (min: Int, max: Int)? {
        let components = priceRangeString.components(separatedBy: "-").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if components.count == 2, let min = Int(components[0]), let max = Int(components[1]) {
            return (min, max)
        } else if components.count == 1, let val = Int(components[0]) { // Case like "15000" (treat as exact or min depending on logic)
             // Assuming "15000" means items at least 15000 or exactly 15000. For a range, this is ambiguous.
             // For now, let's assume if only one number, it's an exact match or a lower bound.
             // This part might need refinement based on how single price points in `Tenant.priceRange` should be handled.
             // A simple approach: if only one value, treat it as min and max.
            return (val, val)
        }
        // Handle cases like "Under 15000" or "Above 50000" if necessary by adding more parsing logic.
        // For now, we only handle "X - Y" and "X".
        return nil
    }

    private func performSearchInternal() {
        // 0. Fetch data from ModelContext
        let allTenants: [Tenant]
        let allFoods: [Food]
        let allCanteens: [Canteen]
        do {
            allTenants = try modelContext.fetch(FetchDescriptor<Tenant>(sortBy: [SortDescriptor<Tenant>(\.name)]))
            allFoods = try modelContext.fetch(FetchDescriptor<Food>(sortBy: [SortDescriptor<Food>(\.name)]))
            allCanteens = try modelContext.fetch(FetchDescriptor<Canteen>(sortBy: [SortDescriptor<Canteen>(\.name)]))
        } catch {
            print("Error fetching data for search: \\(error)")
            // Handle error, perhaps by setting results to empty and returning
            self.categorizedResults = CategorizedSearchResults()
            return
        }
        
        var results = CategorizedSearchResults()
        let loweredSearchTerm = searchTerm.lowercased()

        // Determine if any modal filters are active (excluding nearest/open now for this check)
        let otherModalFiltersAreActive = !priceMin.isEmpty || !priceMax.isEmpty ||
                                         !selectedFoodTypes.isEmpty || !selectedCookingStyles.isEmpty ||
                                         !selectedTasteTypes.isEmpty || !selectedCanteenNames.isEmpty

        var effectiveSelectedCanteenNames = selectedCanteenNames
        var nearestCanteenFound = true // Flag for nearest canteen search

        if isNearestFilterActive {
            if let location = currentUserLocation, let nearestCanteen = findNearestCanteen(to: location) {
                effectiveSelectedCanteenNames = [nearestCanteen.name] // Override/set canteen filter to nearest
            } else {
                // No location or no canteens, so nearest filter cannot be applied.
                // This means if "Nearest" is the *only* filter, no tenants will be shown.
                effectiveSelectedCanteenNames = [] // Ensure no canteens are selected if nearest fails
                results.noNearestCanteenFound = true // Signal UI that nearest canteen wasn't found
                nearestCanteenFound = false
            }
        }

        var potentiallyVisibleTenants = allTenants

        // Filter by "Nearest" / selected canteens first if applicable
        if isNearestFilterActive && !nearestCanteenFound {
             potentiallyVisibleTenants = [] // No tenants if nearest is active but no canteen found
        } else if isNearestFilterActive || !selectedCanteenNames.isEmpty { // Use effectiveSelectedCanteenNames if nearest is active OR original modal selection
            potentiallyVisibleTenants = potentiallyVisibleTenants.filter { tenant in
                guard let tenantCanteenName = tenant.canteen?.name else { return false }
                return effectiveSelectedCanteenNames.contains(tenantCanteenName)
            }
        }


        // Apply "Open Now" filter
        if isOpenNowFilterActive {
            potentiallyVisibleTenants = potentiallyVisibleTenants.filter { tenant in
                isTenantOpenNow(tenant.operationalHours)
            }
        }
        
        // Apply other modal filters (price, food types etc.)
        potentiallyVisibleTenants = potentiallyVisibleTenants.filter { tenant in
            // Apply price range filter
            if !priceMin.isEmpty || !priceMax.isEmpty {
                guard let (tenantMinPrice, tenantMaxPrice) = parsePriceRange(priceRangeString: tenant.priceRange) else {
                    return false
                }
                let filterMinPrice = Int(priceMin) ?? 0
                let filterMaxPrice = Int(priceMax) ?? Int.max
                
                if filterMinPrice > 0 && tenantMaxPrice < filterMinPrice { return false }
                if filterMaxPrice < Int.max && tenantMinPrice > filterMaxPrice { return false }
            }
            return true
        }


        // Iterate through these potentially visible tenants
        for tenant in potentiallyVisibleTenants {
            let foodsForThisTenant = allFoods.filter { $0.tenant?.id == tenant.id }

            // Skip if tenant is hidden by global preferences
            if PreferenceManager.shared.isTenantHidden(tenant, allFoodsForTenant: foodsForThisTenant) {
                if otherModalFiltersAreActive || !searchTerm.isEmpty { // Only add to hidden if a search/filter is active
                    results.hiddenTenantNames.append(tenant.name)
                }
                continue
            }

            var matchingVisibleFoodsForTenant: [Food] = []

            for food in foodsForThisTenant {
                // Skip if food is hidden by global preferences
                if PreferenceManager.shared.isFoodHidden(food) {
                    if otherModalFiltersAreActive || !searchTerm.isEmpty { // Only add to hidden if a search/filter is active
                         results.hiddenFoodNames.append(food.name)
                    }
                    continue
                }

                var matchesAllCriteria = true

                // 1. Check search term (if any)
                if !loweredSearchTerm.isEmpty {
                    if !food.name.lowercased().contains(loweredSearchTerm) && !tenant.name.lowercased().contains(loweredSearchTerm) {
                        matchesAllCriteria = false
                    }
                    // If search term matches tenant name but not food name, food is still a candidate for display under the tenant
                    // if other filters pass. But if search term must match food, then the condition is just on food.name
                    // Current logic: if search term is present, it must match food OR tenant.
                    // If the intent is that search term filters food names directly, this should be:
                    // if !food.name.lowercased().contains(loweredSearchTerm) { matchesAllCriteria = false }
                }
                
                // If search term is not empty AND it matches the tenant's name, this tenant is potentially visible
                // irrespective of direct food name match, IF no other food-specific filters are active or if its foods match them.
                // This part of logic might need refinement based on exact desired behavior of search term vs. category filters.

                // 2. Check Food Type categories
                if !selectedFoodTypes.isEmpty {
                    let foodCategoriesAsStrings = Set(food.categories.map { $0.rawValue })
                    if !selectedFoodTypes.isSubset(of: foodCategoriesAsStrings) {
                        matchesAllCriteria = false
                    }
                }

                // 3. Check Cooking Style categories
                if !selectedCookingStyles.isEmpty {
                    let foodCategoriesAsStrings = Set(food.categories.map { $0.rawValue })
                    if !selectedCookingStyles.isSubset(of: foodCategoriesAsStrings) {
                        matchesAllCriteria = false
                    }
                }

                // 4. Check Taste Type categories
                if !selectedTasteTypes.isEmpty {
                    let foodCategoriesAsStrings = Set(food.categories.map { $0.rawValue })
                    if !selectedTasteTypes.isSubset(of: foodCategoriesAsStrings) {
                        matchesAllCriteria = false
                    }
                }

                if matchesAllCriteria {
                    matchingVisibleFoodsForTenant.append(food)
                }
            } // End food loop for a tenant

            // If, after all filters, this tenant has matching foods, or if no food-specific modal filters active and search term matches tenant
            if !matchingVisibleFoodsForTenant.isEmpty {
                results.visibleTenants.append(tenant)
                results.visibleFoodsByTenant[tenant.id] = matchingVisibleFoodsForTenant.sorted(by: { $0.name < $1.name })
            } else if searchTerm.isEmpty && !otherModalFiltersAreActive { 
                // If no search term and no modal filters, show all non-preference-hidden tenants (initial state)
                results.visibleTenants.append(tenant)
            } else if !loweredSearchTerm.isEmpty && tenant.name.lowercased().contains(loweredSearchTerm) && selectedFoodTypes.isEmpty && selectedCookingStyles.isEmpty && selectedTasteTypes.isEmpty {
                // If search term matches tenant and no food-specific category filters are active, tenant is visible (even if no food name match)
                results.visibleTenants.append(tenant)
                // foods will be empty for this tenant in visibleFoodsByTenant, which is fine
            }

        } // End tenant loop
        
        // If no search term and no modal filters are active, this is the initial state or cleared state.
        // Show all tenants not hidden by preferences. Foods are not detailed yet.
        if searchTerm.isEmpty && !otherModalFiltersAreActive {
            results.visibleTenants.removeAll() // Clear previous tenant list
            results.visibleFoodsByTenant.removeAll()
            for tenant in allTenants {
                let foodsForThisTenant = allFoods.filter { $0.tenant?.id == tenant.id }
                if !PreferenceManager.shared.isTenantHidden(tenant, allFoodsForTenant: foodsForThisTenant) {
                    results.visibleTenants.append(tenant)
                }
            }
        }

        results.visibleTenants = Array(Set(results.visibleTenants)).sorted(by: { $0.name < $1.name })
        results.hiddenFoodNames = Array(Set(results.hiddenFoodNames)).sorted()
        results.hiddenTenantNames = Array(Set(results.hiddenTenantNames)).sorted()
        
        self.categorizedResults = results
    }
    
    func getVisibleFoodsForTenantInSearch(_ tenant: Tenant) -> [Food] {
        return categorizedResults.visibleFoodsByTenant[tenant.id] ?? []
    }

    func saveRecentSearch() { // Takes no arguments, uses the current searchTerm
        guard !searchTerm.isEmpty else { return }
        // Prevent duplicates, case-insensitive
        recentSearch.removeAll { $0.lowercased() == searchTerm.lowercased() }
        recentSearch.insert(searchTerm, at: 0)
        if recentSearch.count > 5 {
            recentSearch = Array(recentSearch.prefix(5))
        }
        // Persist recent searches (optional, example with UserDefaults)
        // UserDefaults.standard.set(recentSearch, forKey: "recentSearches")
    }
    
    func onClose() {
        sheeHeight = .fraction(0.1)
        self.searchTerm = "" // Setting searchTerm will trigger performSearchInternal via didSet
    }

    // Placeholder for finding nearest canteen
    private func findNearestCanteen(to location: CLLocationCoordinate2D) -> Canteen? {
        // This function now needs access to allCanteens, which are fetched in performSearchInternal.
        // For simplicity in this refactor, we'll re-fetch here if needed, or acknowledge this might need restructuring
        // if performSearchInternal is not called frequently enough or if this method is called independently.
        // Optimal: pass allCanteens to this method if called from performSearchInternal, or fetch if called otherwise.
        // Current approach: fetch directly if this method is standalone.
        // However, since performSearchInternal now fetches allCanteens, we can assume it has run if this is being called.
        // For this refactor, we will assume that performSearchInternal has populated a temporary 'allCanteens' or rely on it being passed.
        // For now, to make it compile, let's fetch it. This is NOT OPTIMAL for performance if called often outside performSearch.
        let canteensToSearch: [Canteen]
        do {
            canteensToSearch = try modelContext.fetch(FetchDescriptor<Canteen>())
        } catch {
            print("Error fetching canteens for nearest search: \\(error)")
            return nil
        }
        
        guard !canteensToSearch.isEmpty else { return nil }
        var closestCanteen: Canteen? = nil
        var smallestDistance: Double = Double.infinity

        for canteen in canteensToSearch {
            let canteenLocation = CLLocation(latitude: canteen.latitude, longitude: canteen.longitude)
            let userCLLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
            let distance = userCLLocation.distance(from: canteenLocation) // Distance in meters

            if distance < smallestDistance {
                smallestDistance = distance
                closestCanteen = canteen
            }
        }
        return closestCanteen
    }

    // Placeholder for checking if tenant is open
    private func isTenantOpenNow(_ operationalHours: String) -> Bool {
        // Example: "09:00-17:00" or "Mon-Fri 09:00-22:00, Sat 10:00-18:00"
        // This needs robust parsing based on the actual format of operationalHours.
        // For simplicity, let's assume a HH:mm-HH:mm format for now and it applies to current day.
        let parts = operationalHours.split(separator: "-").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return false } // Return false if format is not HH:mm-HH:mm

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"

        guard let startTime = dateFormatter.date(from: parts[0]),
              let endTime = dateFormatter.date(from: parts[1]) else {
            return false // Return false if time parsing fails
        }

        let calendar = Calendar.current
        let now = Date()
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)

        guard let currentHour = nowComponents.hour, let currentMinute = nowComponents.minute, // Ensure currentHour and currentMinute are from nowComponents
              let startHour = calendar.dateComponents([.hour, .minute], from: startTime).hour, // Get start hour/minute from startTime
              let startMinute = calendar.dateComponents([.hour, .minute], from: startTime).minute,
              let endHour = calendar.dateComponents([.hour, .minute], from: endTime).hour, // Get end hour/minute from endTime
              let endMinute = calendar.dateComponents([.hour, .minute], from: endTime).minute else {
            return false // Return false if components cannot be extracted
        }

        let currentTimeInMinutes = currentHour * 60 + currentMinute
        let startTimeInMinutes = startHour * 60 + startMinute // Use parsed hour/minute
        var endTimeInMinutes = endHour * 60 + endMinute // Use parsed hour/minute, and declare as var

        // Handle overnight operations if endTime is earlier than startTime (e.g., 20:00 - 02:00)
        if endTimeInMinutes < startTimeInMinutes {
            endTimeInMinutes += 24 * 60 // Add a day to end time
        }
        
        return currentTimeInMinutes >= startTimeInMinutes && currentTimeInMinutes <= endTimeInMinutes
    }
}

struct ModalSearch: View {
    @FocusState var isSearchBarFocused: Bool
    private let maxHeight: PresentationDetent = .fraction(0.9)
    @ObservedObject var tenantSearchViewModel: TenantSearchViewModel
    @EnvironmentObject var locationManager: LocationManager // Access LocationManager
    @EnvironmentObject var easterEggViewModel: EasterEggViewModel // << ADDED
    @Binding var isPresented: Bool // << ADDED: To dismiss the modal
    @State private var showNewFilterModal = false
    @State private var isNearestActive = false
    @State private var isOpenNowActive = false
    @State private var showBingungButton: Bool = false // << ADDED: Controls visibility of easter egg button

    // State variables for NewFilterModal criteria
    @State private var modalPriceMin: String = ""
    @State private var modalPriceMax: String = ""
    @State private var modalSelectedFoodTypes: Set<String> = []
    @State private var modalSelectedCookingStyles: Set<String> = []
    @State private var modalSelectedTasteTypes: Set<String> = []
    @State private var modalSelectedCanteenNames: Set<String> = []

    init(isPresented: Binding<Bool>, modelContext: ModelContext) {
        self._isPresented = isPresented
        _tenantSearchViewModel = ObservedObject(wrappedValue: TenantSearchViewModel(modelContext: modelContext))
    }

    private func showTenantResults() -> some View {
        let results = tenantSearchViewModel.categorizedResults
        let searchTermNotEmpty = !tenantSearchViewModel.searchTerm.isEmpty

        return VStack(alignment: .leading) {
            if searchTermNotEmpty {
                Text("Results for \"\(tenantSearchViewModel.searchTerm)\"")
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding(.bottom, 5)
                Divider()
            }

            if !results.visibleTenants.isEmpty {
                Text("Tenants")
                    .font(.title3).bold()
                    .padding(.top)
                ForEach(results.visibleTenants) { tenant in
                    VStack(alignment: .leading) {
                        TenantCard(tenant: tenant) // Make sure TenantCard can handle the tenant object
                        
                        // Display foods for this tenant that matched the search and are visible
                        let foodsToList = tenantSearchViewModel.getVisibleFoodsForTenantInSearch(tenant)
                        if !foodsToList.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(foodsToList) { food in
                                    Text(food.name)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 16)
                                        .background(Color(.systemGray6))
                                        .foregroundColor(.primary)
                                    if food.id != foodsToList.last?.id {
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                            .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }

            // Display hidden item messages
            if searchTermNotEmpty && results.visibleTenants.isEmpty && results.visibleFoodsByTenant.allSatisfy({ $0.value.isEmpty }) {
                if !results.hiddenTenantNames.isEmpty {
                    ForEach(results.hiddenTenantNames, id: \.self) { name in
                        Text("\"\(name)\" is hidden based on your selected preferences.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.vertical, 2)
                    }
                }
                if !results.hiddenFoodNames.isEmpty {
                    ForEach(results.hiddenFoodNames, id: \.self) { name in
                         Text("Food item \"\(name)\" is hidden based on your selected preferences.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.vertical, 2)
                    }
                }
                // If both hidden lists are empty but no visible results, then it's a general not found
                if results.hiddenTenantNames.isEmpty && results.hiddenFoodNames.isEmpty {
                     Text("No results found for \"\(tenantSearchViewModel.searchTerm)\".")
                        .font(.subheadline)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 10)
                }
            } else if searchTermNotEmpty && results.visibleTenants.isEmpty && results.visibleFoodsByTenant.allSatisfy({ $0.value.isEmpty }) && results.hiddenTenantNames.isEmpty && results.hiddenFoodNames.isEmpty {
                Text("No results found for \"\(tenantSearchViewModel.searchTerm)\".")
                    .font(.subheadline)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
            }
        }
    }

    private func showRecentSearch() -> some View {
        VStack(alignment: .leading) {
            if !tenantSearchViewModel.recentSearch.isEmpty && tenantSearchViewModel.searchTerm.isEmpty {
                Text("Your Search History")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .padding(.bottom, 2)
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(tenantSearchViewModel.recentSearch, id: \.self) { recent in
                            Button {
                                tenantSearchViewModel.searchTerm = recent
                                // tenantSearchViewModel.saveRecentSearch() // Save on submit, not on tap recent
                                isSearchBarFocused = true
                            } label: {
                                Text(recent)
                                    .foregroundStyle(Color.primary)
                                    .font(.caption)
                                    .padding(8)
                                    .background(Color(.systemGray5))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 5)
    }

    var body: some View {
        NavigationStack{
            VStack(alignment: .leading, spacing: 0) {
                SearchBar(
                    searchTerm: $tenantSearchViewModel.searchTerm,
                    isTextFieldFocused: $isSearchBarFocused,
                    onCancel: {
                        isSearchBarFocused = false
                        tenantSearchViewModel.searchTerm = ""
                    },
                    onSearch: {
                        isSearchBarFocused = false
                        if easterEggViewModel.checkForEasterEggTrigger(searchTerm: tenantSearchViewModel.searchTerm) {
                            showBingungButton = true
                        } else {
                            showBingungButton = false
                            tenantSearchViewModel.saveRecentSearch()
                        }
                    }
                )
                .padding(.horizontal)
                .padding(.bottom, tenantSearchViewModel.sheeHeight == .fraction(0.1) ? 0 : 8) // Add padding only when expanded
                
                // Easter Egg Button - Centered below SearchBar when active
                if showBingungButton {
                    Button(action: {
                        easterEggViewModel.prepareAndShowRandomFoodPopup() // This sets .presentFullscreenFoodDetail = true
                        isPresented = false // Dismiss ModalSearch sheet (triggers $showSearchModal = false in MapView)
                        showBingungButton = false // Reset the local bingung state for ModalSearch
                    }) {
                        Text("Saya Bingung, Pilihkan Dong!")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color("Sample")) // Ensure "Sample" color is in Assets
                            .cornerRadius(8)
                            .shadow(radius: 3)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20) // Space from search bar
                    .padding(.bottom, 20) // Space before other content
                }

                // Filter Bar - only show if not bingung mode and sheet is expanded
                if !showBingungButton && tenantSearchViewModel.sheeHeight != .fraction(0.1) {
                    VStack(alignment: .leading, spacing: 4) { 
                        HStack { 
                            Button {
                                isNearestActive.toggle()
                            } label: {
                                Text("Nearest")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(isNearestActive ? Color.green.opacity(0.2) : Color(.systemGray6))
                                    .foregroundColor(isNearestActive ? .green : .gray)
                                    .cornerRadius(22)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22)
                                            .inset(by: 0.37)
                                            .stroke(isNearestActive ? Color.green : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            
                            Button {
                                isOpenNowActive.toggle()
                            } label: {
                                Text("Open Now")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(isOpenNowActive ? Color.green.opacity(0.2) : Color(.systemGray6))
                                    .foregroundColor(isOpenNowActive ? .green : .gray)
                                    .cornerRadius(22)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22)
                                            .inset(by: 0.37)
                                            .stroke(isOpenNowActive ? Color.green : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            Spacer()
                            if !modalPriceMin.isEmpty || !modalPriceMax.isEmpty || !modalSelectedFoodTypes.isEmpty || !modalSelectedCookingStyles.isEmpty || !modalSelectedTasteTypes.isEmpty || !modalSelectedCanteenNames.isEmpty {
                                Button(action: {
                                    modalPriceMin = ""
                                    modalPriceMax = ""
                                    modalSelectedFoodTypes.removeAll()
                                    modalSelectedCookingStyles.removeAll()
                                    modalSelectedTasteTypes.removeAll()
                                    modalSelectedCanteenNames.removeAll()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.red.opacity(0.8))
                                }
                            }
                            Button(action: { showNewFilterModal = true }) {
                                Image(systemName: "line.horizontal.3.decrease.circle")
                                    .font(.title2)
                                    .foregroundColor(Color(.systemGray))
                            }
                        }
                        if isNearestActive && tenantSearchViewModel.categorizedResults.noNearestCanteenFound {
                            Text("Could not determine nearest canteen. Please check location services.")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.leading, 5)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                // Conditional display of content (results, recent, or bingung message)
                if showBingungButton {
                    Spacer() // Push everything to center if only bingung button is shown
                    Text("Tekan tombol di atas untuk menemukan takdir kulinermu! 👆")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                } else if tenantSearchViewModel.searchTerm.isEmpty && !showBingungButton {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 15) { 
                            if !tenantSearchViewModel.recentSearch.isEmpty {
                                showRecentSearch()
                            }
                            if !tenantSearchViewModel.categorizedResults.visibleTenants.isEmpty {
                                showTenantResults() 
                            }
                            if tenantSearchViewModel.categorizedResults.visibleTenants.isEmpty && tenantSearchViewModel.recentSearch.isEmpty {
                                Text("Mau makan apa hari ini? Cari aja!")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 20) 
                            }
                        }
                        .padding(.horizontal) 
                    }
                } else if !tenantSearchViewModel.searchTerm.isEmpty && !showBingungButton {
                    ScrollView {
                        showTenantResults()
                            .padding(.horizontal)
                    }
                }
                if !showBingungButton { // Only add the Spacer if not in bingung mode to push content up
                    Spacer() 
                }
            }
            // .animation(.default, value: tenantSearchViewModel.searchTerm) // << COMMENTED OUT
            // .animation(.default, value: tenantSearchViewModel.categorizedResults.visibleTenants.count) // << COMMENTED OUT
            // .animation(.default, value: showBingungButton) // << COMMENTED OUT
            .onAppear {
                if tenantSearchViewModel.searchTerm.isEmpty && 
                   (!tenantSearchViewModel.recentSearch.isEmpty || !tenantSearchViewModel.categorizedResults.visibleTenants.isEmpty) &&
                   tenantSearchViewModel.sheeHeight == .fraction(0.1) {
                     // tenantSearchViewModel.sheeHeight = .medium // Auto expand if has content and collapsed
                }
                if locationManager.authState == .notDetermined {
                    locationManager.requestLocationPermission()
                }
                locationManager.startUpdatingLocation()
            }
            .onReceive(locationManager.$location) { newLocation in
                if let location = newLocation {
                    tenantSearchViewModel.currentUserLocation = location.coordinate
                }
            }
            .presentationDetents(
                showBingungButton ? [.medium] : [.fraction(0.1), .medium, .large], // Adjust detents for bingung mode
                selection: $tenantSearchViewModel.sheeHeight
            )
            .interactiveDismissDisabled()
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
            .onChange(of: isSearchBarFocused, initial: false) { _, newValue in
                withAnimation {
                    if newValue { // isSearchBarFocused is true
                        tenantSearchViewModel.sheeHeight = .medium 
                        showBingungButton = false // Hide bingung button when user starts typing again
                    }
                }
            }
            .onChange(of: tenantSearchViewModel.sheeHeight) { _, newValue in
                if newValue == .fraction(0.1) && isSearchBarFocused {
                    isSearchBarFocused = false 
                }
            }
            .sheet(isPresented: $showNewFilterModal) {
                NewFilterModal(
                    isPresented: $showNewFilterModal,
                    priceMin: $modalPriceMin,
                    priceMax: $modalPriceMax,
                    selectedFoodTypes: $modalSelectedFoodTypes,
                    selectedCookingStyles: $modalSelectedCookingStyles,
                    selectedTasteTypes: $modalSelectedTasteTypes,
                    selectedCanteens: $modalSelectedCanteenNames
                )
                // Propagate changes from NewFilterModal back to TenantSearchViewModel
                .onDisappear {
                    tenantSearchViewModel.priceMin = modalPriceMin
                    tenantSearchViewModel.priceMax = modalPriceMax
                    tenantSearchViewModel.selectedFoodTypes = modalSelectedFoodTypes
                    tenantSearchViewModel.selectedCookingStyles = modalSelectedCookingStyles
                    tenantSearchViewModel.selectedTasteTypes = modalSelectedTasteTypes
                    tenantSearchViewModel.selectedCanteenNames = modalSelectedCanteenNames
                    tenantSearchViewModel.isNearestFilterActive = isNearestActive // Sync local toggle with VM
                    tenantSearchViewModel.isOpenNowFilterActive = isOpenNowActive   // Sync local toggle with VM
                }
            }
            // Remove individual .onChange modifiers for modal filters if handled by onDisappear
            // .onChange(of: modalPriceMin) { _, newValue in tenantSearchViewModel.priceMin = newValue }
            // ... and so on for other filters ...
            // Keep .onChange for direct toggles if not using onDisappear for them
            .onChange(of: isNearestActive) { _, newValue in tenantSearchViewModel.isNearestFilterActive = newValue }
            .onChange(of: isOpenNowActive) { _, newValue in tenantSearchViewModel.isOpenNowFilterActive = newValue }
        }
    }
}

