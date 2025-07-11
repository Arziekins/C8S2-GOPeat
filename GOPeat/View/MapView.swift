//
//  MapView.swift
//  GOPeat
//
//  Created by jonathan calvin sutrisna on 07/04/25.
//

import CoreLocation
import MapKit
import SwiftUI
import SwiftData

// Global function for location color
func locationColor(for name: String) -> Color {
    switch name {
    case "GOP 1 Canteen": return .red
    case "GOP 6 Canteen": return .blue
    case "Green Eatery": return .green
    case "The Breeze Food Court": return .orange
    default: return .purple
    }
}

// Location authorization states
enum LocationAuthState {
    case notDetermined
    case denied
    case restricted
    case authorized
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authState: LocationAuthState = .notDetermined

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        if locationManager.authorizationStatus == .authorizedWhenInUse || 
           locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            authState = .authorized
            startUpdatingLocation()
        case .denied:
            authState = .denied
        case .restricted:
            authState = .restricted
        case .notDetermined:
            authState = .notDetermined
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Simple error handling
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}

struct MapView: View {
    @State private var camera: MapCameraPosition = .automatic
    @State private var selectedCanteen: Canteen?
    @Binding var showDetail: Bool
    @Binding var showSearchModal: Bool
    @Binding var showTutorial: Bool
    @Binding var showEasterEgg: Bool
    @State private var mapOffset: CGFloat = 0
    @EnvironmentObject private var locationManager: LocationManager
    @StateObject private var tenantSearchViewModel: TenantSearchViewModel
    @StateObject private var easterEggViewModel: EasterEggViewModel
    @State private var selectedTenantFromDeepLink: Tenant?
    @State private var showTenantView = false
    @State private var modalSearchFraction: CGFloat = 1.0
    
    // These are for MapView's direct display needs (e.g., annotations, initial region)
    let displayTenants: [Tenant] 
    let displayCanteens: [Canteen]
    
    // These are ALL tenants and foods from the data store, for search functionality
    private let allTenantsForSearch: [Tenant]
    private let allFoodsForSearch: [Food]
    
    var deepLinkTenantID: UUID?
    private var modelContext: ModelContext

    // Updated Initializer
    init(displayTenants: [Tenant], 
         displayCanteens: [Canteen], 
         allTenantsForSearch: [Tenant], 
         allFoodsForSearch: [Food], 
         showTutorial: Binding<Bool>,
         deepLinkTenantID: UUID? = nil, 
         modelContext: ModelContext,
         showSearchModal: Binding<Bool>,
         showDetail: Binding<Bool>,
         showEasterEgg: Binding<Bool>) {
        self.displayTenants = displayTenants
        self.displayCanteens = displayCanteens
        self.allTenantsForSearch = allTenantsForSearch
        self.allFoodsForSearch = allFoodsForSearch
        self.deepLinkTenantID = deepLinkTenantID
        self._showTutorial = showTutorial
        self.modelContext = modelContext
        self._showSearchModal = showSearchModal
        self._showDetail = showDetail
        self._showEasterEgg = showEasterEgg
        
        self._tenantSearchViewModel = StateObject(
            wrappedValue: TenantSearchViewModel(modelContext: modelContext)
        )
        self._easterEggViewModel = StateObject(wrappedValue: EasterEggViewModel(modelContext: modelContext))
    }

    private func zoomToLocation(_ coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.5)) {
            mapOffset = -UIScreen.main.bounds.height * 0.25
            let region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
            )
            camera = .region(region)
        }
    }

    private func handleCanteenSelection(_ canteen: Canteen) {
        selectedCanteen = canteen
        let coordinate = CLLocationCoordinate2D(
            latitude: canteen.latitude, longitude: canteen.longitude)
        
        // 1. Signal ModalSearch to collapse and resign focus
        tenantSearchViewModel.onClose()

        // 2. After a short delay, update modal states and zoom
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.zoomToLocation(coordinate)
            self.showDetail = true
            self.showSearchModal = false
            self.showEasterEgg = false
            self.showTutorial = false
        }
    }

    private func handleTenantSelection(_ tenant: Tenant) {
        guard let canteen = tenant.canteen else { return }
        let coordinate = CLLocationCoordinate2D(
            latitude: canteen.latitude, longitude: canteen.longitude)
        
        // 1. Signal ModalSearch to collapse and resign focus
        tenantSearchViewModel.onClose()

        // 2. After a short delay, update modal state and zoom
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.zoomToLocation(coordinate)
            self.showSearchModal = false
            self.showDetail = false
            self.showEasterEgg = false
            self.showTutorial = false
            self.showTenantView = true
        }
    }

    private func annotationContent(for canteen: Canteen) -> some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 30, height: 30)

            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(locationColor(for: canteen.name))
                .scaleEffect(selectedCanteen?.id == canteen.id ? 1.3 : 1.0)
        }
        .shadow(radius: 5)
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                handleCanteenSelection(canteen)
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Map View with Offset
            Map(position: $camera) {
                UserAnnotation()
                ForEach(displayCanteens) { canteen in
                    Annotation(
                        canteen.name,
                        coordinate: CLLocationCoordinate2D(
                            latitude: canteen.latitude, longitude: canteen.longitude)
                    ) {
                        annotationContent(for: canteen)
                    }
                }
            }
            .padding(.top, mapOffset)
            .mapStyle(.standard)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .edgesIgnoringSafeArea(.all)
            .background(Color.clear)

            // Location Status Indicator
            if locationManager.authState != .authorized {
                LocationStatusBanner(authState: locationManager.authState) {
                    if locationManager.authState == .notDetermined {
                        locationManager.requestLocationPermission()
                    } else {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }

            // Location Button moved to top right
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        if let currentLocation = locationManager.location?.coordinate {
                            withAnimation {
                                camera = .region(
                                    MKCoordinateRegion(
                                        center: currentLocation,
                                        span: MKCoordinateSpan(
                                            latitudeDelta: 0.002, longitudeDelta: 0.002)
                                    ))
                                mapOffset = 0
                            }
                        }
                    }) {
                        Image(systemName: "location.fill")
                            .padding(10)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .padding(.trailing)
                }
                Spacer()
            }
            .padding(.top)

            // Tutorial Overlay
            if showTutorial {
                MapTutorialOverlay(isPresented: $showTutorial) {
                    withAnimation {
                        showTutorial = false
                        UserDefaults.standard.set(true, forKey: "hasSeenMapTutorial")
                        showSearchModal = true
                        modalSearchFraction = 0.1
                    }
                }
            }
        }
        .sheet(
            isPresented: $showDetail,
            onDismiss: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedCanteen = nil
                    // Only show search modal if we don't have a deep link tenant
                    if deepLinkTenantID == nil {
                        showSearchModal = true
                    }
                    mapOffset = 0
                }
            }
        ) {
            if let canteen = selectedCanteen {
                CanteenDetail(
                    canteen: canteen,
                    allFoods: allFoodsForSearch,
                    dismissAction: {
                        showDetail = false
                    }
                )
                .presentationDetents([.medium])
            }
        }
        .sheet(
            isPresented: Binding(
                get: { showSearchModal && !showTutorial },
                set: { showSearchModal = $0 }
            ), onDismiss: {}
        ) {
            ModalSearch(
                isPresented: $showSearchModal,
                modelContext: modelContext
            )
            .environmentObject(locationManager)
            .environmentObject(easterEggViewModel)
        }
        .fullScreenCover(
            isPresented: $easterEggViewModel.presentFullscreenFoodDetail,
            onDismiss: {
                withAnimation {
                    showSearchModal = true
                    modalSearchFraction = 0.1
                }
            }
        ) {
            if let details = easterEggViewModel.selectedFoodDetails {
                EasterEggPopupView(
                    isPresented: $easterEggViewModel.presentFullscreenFoodDetail,
                    foodDetails: details
                )
            } else {
                EmptyView() 
            }
        }
        .fullScreenCover(isPresented: $showTenantView) {
            if let tenant = selectedTenantFromDeepLink {
                TenantView(tenant: tenant, foods: tenant.foods, selectedCategories: .constant([]))
                    .onDisappear {
                        showTenantView = false
                        selectedTenantFromDeepLink = nil
                    }
            }
        }
        .onAppear {
            // Request location when map appears
            locationManager.requestLocationPermission()
            
            // Logic to handle deep link, find tenant and show details
            if let tenantID = deepLinkTenantID,
               let tenant = allTenantsForSearch.first(where: { $0.id == tenantID }) {
                selectedTenantFromDeepLink = tenant
                
                // Close all modals first
                showSearchModal = false
                showDetail = false
                showEasterEgg = false
                showTutorial = false
                
                // Then show tenant view after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let canteen = tenant.canteen {
                    handleCanteenSelection(canteen) 
                    }
                    showTenantView = true
                }
            } else if !self.showTutorial {
                DispatchQueue.main.async {
                     self.showSearchModal = true
                }
            }
        }
        .onChange(of: showSearchModal) { oldValue, newValue in
            print("MapView: showSearchModal changed from \(oldValue) to \(newValue)")
        }
    }
}

// Location Status Banner View
struct LocationStatusBanner: View {
    let authState: LocationAuthState
    let action: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: statusIcon)
                .font(.system(size: 12))
                .foregroundColor(statusColor)

            Text(statusMessage)
                .font(.footnote)
                .foregroundColor(.black.opacity(0.7))

            Button(action: action) {
                Text(buttonText)
                    .font(.footnote.bold())
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.top, 50)
        .frame(maxWidth: .infinity)
    }

    private var statusIcon: String {
        switch authState {
        case .notDetermined:
            return "location.circle"
        case .denied, .restricted:
            return "location.slash.circle"
        case .authorized:
            return "location.circle.fill"
        }
    }

    private var statusColor: Color {
        switch authState {
        case .notDetermined:
            return .orange
        case .denied, .restricted:
            return .red
        case .authorized:
            return .green
        }
    }

    private var statusMessage: String {
        switch authState {
        case .notDetermined:
            return "Enable location to find nearby canteens"
        case .denied:
            return "Location access needed"
        case .restricted:
            return "Location access unavailable"
        case .authorized:
            return ""
        }
    }

    private var buttonText: String {
        switch authState {
        case .notDetermined:
            return "Enable"
        case .denied, .restricted:
            return "Settings"
        case .authorized:
            return ""
        }
    }
}
