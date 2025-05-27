//
//  ContentView.swift
//  GOPeat
//
//  Created by jonathan calvin sutrisna on 09/03/25.
//

import SwiftUI
import MapKit
import SwiftData
import CoreSpotlight

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query var canteensFromDataStore: [Canteen]
    @Query var tenantsFromDataStore: [Tenant]
    @Query var foodsFromDataStore: [Food]
    @State private var showSheet = true
    @State var showOnboarding: Bool
    @State private var showPreferences = false
    @StateObject private var locationManager = LocationManager()
    var deepLinkTenantID: UUID?
    @State private var navigateToTenantViewFromDeepLink = false
    @State private var hasIndexedSpotlightThisSession = false
    var onDeepLinkTenantViewDismiss: (() -> Void)?
    
    // Add states to control MapView modals
    @State private var showSearchModal = false
    @State private var showDetail = false
    @State private var showTutorial = false
    @State private var showEasterEgg = false
    
    @State private var deepLinkedTenant: Tenant?
    
    init(showOnboarding: Bool = true, deepLinkTenantID: UUID? = nil, onDeepLinkTenantViewDismiss: (() -> Void)? = nil) {
        self._showOnboarding = State(initialValue: showOnboarding)
        self.deepLinkTenantID = deepLinkTenantID
        self.onDeepLinkTenantViewDismiss = onDeepLinkTenantViewDismiss
    }
    
    private func insertInitialData() async {
        // Create Canteens
        let canteens = createInitialCanteens()
        for canteen in canteens {
            context.insert(canteen)
        }
        
        // Create Tenants
        let tenants = createInitialTenants(canteens: canteens)
        
        // Create Foods
        let foods = createInitialFoods(tenants: tenants)
        for food in foods {
            context.insert(food)
        }
        
        do {
            try context.save()
        } catch {
            fatalError(error.localizedDescription)
        }
        print("Insert Initial Data Success")
        print("===============================")
    }

    private func createInitialCanteens() -> [Canteen] {
        return [
            Canteen(name: "Green Eatery",
                   latitude: -6.302180333605081,
                   longitude: 106.65229958867403,
                   image: "GreenEatery",
                   desc: "Modern food court featuring diverse dishes",
                   operationalTime: "Monday - Friday: 6 AM - 9 PM",
                   amenities: ["Disabled Access", "Smoking Area", "Convenience Store"]),
            Canteen(name: "GOP 6 Canteen",
                   latitude: -6.303134809023461,
                   longitude: 106.65281577080749,
                   image: "GOP6",
                   desc: "Popular food court with multiple food stalls",
                   operationalTime: "Monday - Saturday: 6:30 AM - 8 PM",
                   amenities: ["ATM", "Printing Services"]),
            Canteen(name: "GOP 1 Canteen",
                   latitude: -6.301780422262836,
                   longitude: 106.65017405960315,
                   image: "GOP1",
                   desc: "Main cafeteria at GOP 1 offering various cuisines",
                   operationalTime: "Monday - Friday: 7 AM - 7 PM",
                   amenities: ["Free WiFi", "Air Conditioned", "Outdoor Seating"]),
            Canteen(name: "The Breeze Food Court",
                   latitude: -6.301495171206343,
                   longitude: 106.65514273021897,
                   image: "TheBreeze",
                   desc: "Spacious food court with outdoor seating",
                   operationalTime: "Daily: 8 AM - 10 PM",
                   amenities: ["Live Music", "Event Space", "Premium Dining"])
        ]
    }

    private func createInitialTenants(canteens: [Canteen]) -> [Tenant] {
        var tenants: [Tenant] = []
        
        // Green Eatery tenants
        if let greenEatery = canteens.first(where: { $0.name == "Green Eatery" }) {
            let greenEateryTenants = [
                Tenant(name: "Mama Djempol",
                      image: "MamaDjempolGE",
                      contactPerson: "08123456789",
                      preorderInformation: true,
                      operationalHours: "09:00-14:00",
                      isHalal: true,
                      canteen: greenEatery,
                      priceRange: "16.000-25.000"),
                Tenant(name: "Kasturi",
                      image: "Kasturi",
                      contactPerson: "08123456789",
                      preorderInformation: true,
                      operationalHours: "09:00-14:00",
                      isHalal: true,
                      canteen: greenEatery,
                      priceRange: "13.000-20.000"),
                Tenant(name: "La Ding",
                      image: "LaDing",
                      contactPerson: "08123456789",
                      preorderInformation: true,
                      operationalHours: "09:00-14:00",
                      isHalal: true,
                      canteen: greenEatery,
                      priceRange: "17.000-35.000")
            ]
            tenants.append(contentsOf: greenEateryTenants)
            greenEatery.tenants.append(contentsOf: greenEateryTenants)
        }
        
        // GOP 6 tenants
        if let gop6 = canteens.first(where: { $0.name == "GOP 6 Canteen" }) {
            let gop6Tenants = [
                Tenant(name: "Dapur Mimin",
                      image: "dapurMimin",
                      contactPerson: "-",
                      preorderInformation: false,
                      operationalHours: "11:00-17:00",
                      isHalal: true,
                      canteen: gop6,
                      priceRange: "18.000-25.000"),
                Tenant(name: "Nasi Kapau Nusantara",
                      image: "NasiPadang",
                      contactPerson: "08987654321",
                      preorderInformation: true,
                      operationalHours: "10:00-16:00",
                      isHalal: true,
                      canteen: gop6,
                      priceRange: "15.000-30.000")
            ]
            tenants.append(contentsOf: gop6Tenants)
            gop6.tenants.append(contentsOf: gop6Tenants)
        }
        
        // GOP 1 tenants
        if let gop1 = canteens.first(where: { $0.name == "GOP 1 Canteen" }) {
            let gop1Tenants = [
                Tenant(name: "Warung Padang Sederhana",
                      image: "PadangSederhana",
                      contactPerson: "08123456789",
                      preorderInformation: true,
                      operationalHours: "08:00-20:00",
                      isHalal: true,
                      canteen: gop1,
                      priceRange: "15.000-35.000"),
                Tenant(name: "Bakso Malang",
                      image: "BaksoMalang",
                      contactPerson: "08987654321",
                      preorderInformation: false,
                      operationalHours: "10:00-18:00",
                      isHalal: true,
                      canteen: gop1,
                      priceRange: "12.000-25.000"),
                Tenant(name: "Warung Nasi Uduk",
                      image: "NasiUduk",
                      contactPerson: "08123456789",
                      preorderInformation: true,
                      operationalHours: "06:00-14:00",
                      isHalal: true,
                      canteen: gop1,
                      priceRange: "10.000-20.000"),
                Tenant(name: "Warung Lokal",
                      image: "WarungLokal",
                      contactPerson: "08987654321",
                      preorderInformation: false,
                      operationalHours: "06:00-17:00",
                      isHalal: true,
                      canteen: gop1,
                      priceRange: "5.000-15.000")
            ]
            tenants.append(contentsOf: gop1Tenants)
            gop1.tenants.append(contentsOf: gop1Tenants)
        }
        
        // The Breeze tenants
        if let theBreeze = canteens.first(where: { $0.name == "The Breeze Food Court" }) {
            let breezeTenants = [
                Tenant(name: "Warung Makan Pak Haji",
                      image: "WarungPakHaji",
                      contactPerson: "08123456789",
                      preorderInformation: true,
                      operationalHours: "07:00-15:00",
                      isHalal: true,
                      canteen: theBreeze,
                      priceRange: "12.000-25.000"),
                Tenant(name: "Warung Pecel",
                      image: "WarungPecel",
                      contactPerson: "08987654321",
                      preorderInformation: false,
                      operationalHours: "08:00-16:00",
                      isHalal: true,
                      canteen: theBreeze,
                      priceRange: "10.000-20.000"),
                Tenant(name: "Warung Soto",
                      image: "WarungSoto",
                      contactPerson: "08123456789",
                      preorderInformation: true,
                      operationalHours: "07:00-14:00",
                      isHalal: true,
                      canteen: theBreeze,
                      priceRange: "15.000-25.000"),
                Tenant(name: "Warung Gorengan",
                      image: "WarungGorengan",
                      contactPerson: "08987654321",
                      preorderInformation: false,
                      operationalHours: "08:00-17:00",
                      isHalal: true,
                      canteen: theBreeze,
                      priceRange: "2.000-5.000")
            ]
            tenants.append(contentsOf: breezeTenants)
            theBreeze.tenants.append(contentsOf: breezeTenants)
        }
        
        // Insert tenants to context
        for tenant in tenants {
            context.insert(tenant)
        }
        
        return tenants
    }

    private func createInitialFoods(tenants: [Tenant]) -> [Food] {
        var foods: [Food] = []
        
        // Kasturi foods
        if let kasturi = tenants.first(where: { $0.name == "Kasturi" }) {
            let kasturiFoods = [
                Food(name: "Sapi Lada Hitam", description: "Sapi dengan saus lada hitam", categories: [.meat, .fried, .savory], tenant: kasturi),
                Food(name: "Sawi Putih", description: "Sawi putih rebus", categories: [.vegetables, .steamed, .savory], tenant: kasturi),
                Food(name: "Otak-Otak", description: "Otak-otak bakar khas", categories: [.fish, .roasted, .savory], tenant: kasturi),
                Food(name: "Telur Ponti", description: "Telur khas Pontianak", categories: [.eggs, .fried, .savory], tenant: kasturi),
                Food(name: "Ikan Tongkol", description: "Ikan tongkol dengan bumbu", categories: [.fish, .fried, .savory], tenant: kasturi),
                Food(name: "Kentang Mustofa", description: "Kentang goreng kering", categories: [.vegetables, .fried, .savory], tenant: kasturi),
                Food(name: "Tempe Kering", description: "Tempe goreng kering", categories: [.soy, .fried, .savory, .sweet], tenant: kasturi),
                Food(name: "Ayam Kering", description: "Ayam goreng kering", categories: [.chicken, .fried, .savory], tenant: kasturi),
                Food(name: "Teri Kacang", description: "Teri goreng dengan kacang", categories: [.fish, .nuts, .snacks, .fried, .savory, .sweet], tenant: kasturi),
                Food(name: "Ayam Bakar", description: "Ayam bakar kecap", categories: [.chicken, .roasted, .sweet, .savory], tenant: kasturi),
                Food(name: "Ayam Rendang", description: "Ayam dengan bumbu rendang", categories: [.chicken, .soup, .savory, .spicy], tenant: kasturi),
                Food(name: "Ayam Gulai", description: "Ayam dengan kuah gulai", categories: [.chicken, .soup, .savory, .spicy], tenant: kasturi)
            ]
            foods.append(contentsOf: kasturiFoods)
        }
        
        // La Ding foods
        if let laDing = tenants.first(where: { $0.name == "La Ding" }) {
            let laDingFoods = [
                Food(name: "Soto Mie", description: "Soto mie khas Bogor", categories: [.meat, .vegetables, .gluten, .soup, .savory], tenant: laDing),
                Food(name: "Sop Iga", description: "Sup iga sapi", categories: [.meat, .soup, .savory], tenant: laDing),
                Food(name: "Sop Daging", description: "Sup daging sapi", categories: [.meat, .soup, .savory], tenant: laDing),
                Food(name: "Somay", description: "Siomay khas Bandung", categories: [.fish, .soy, .vegetables, .eggs, .gluten, .steamed, .savory], tenant: laDing),
                Food(name: "Nasi Uduk", description: "Nasi gurih khas Jakarta", categories: [.rice, .steamed, .savory], tenant: laDing)
            ]
            foods.append(contentsOf: laDingFoods)
        }
        
        // Mama Djempol foods
        if let mamaDjempol = tenants.first(where: { $0.name == "Mama Djempol" }) {
            let mamaDjempolFoods = [
                Food(name: "Ayam Lada Hitam", description: "Ayam dengan saus lada hitam", categories: [.chicken, .fried, .savory], tenant: mamaDjempol),
                Food(name: "Ayam Jamur Kancing", description: "Ayam dengan jamur kancing", categories: [.chicken, .mushroom, .fried, .savory], tenant: mamaDjempol),
                Food(name: "Ayam Saus Madu", description: "Ayam dengan saus madu", categories: [.chicken, .fried, .sweet, .savory], tenant: mamaDjempol),
                Food(name: "Ayam Pedas Manis", description: "Ayam dengan bumbu pedas manis", categories: [.chicken, .fried, .spicy, .sweet, .savory], tenant: mamaDjempol),
                Food(name: "Ayam Saus Padang", description: "Ayam dengan saus Padang", categories: [.chicken, .fried, .spicy, .savory], tenant: mamaDjempol),
                Food(name: "Ayam Sambal Hijau", description: "Ayam dengan sambal hijau", categories: [.chicken, .fried, .spicy, .savory], tenant: mamaDjempol),
                Food(name: "Ayam Suwir", description: "Ayam suwir pedas", categories: [.chicken, .fried, .spicy, .savory], tenant: mamaDjempol),
                Food(name: "Ikan Dori", description: "Ikan dori goreng", categories: [.fish, .fried, .savory], tenant: mamaDjempol),
                Food(name: "Cumi Rica", description: "Cumi dengan bumbu rica", categories: [.seafood, .fried, .spicy, .savory], tenant: mamaDjempol),
                Food(name: "Ikan Tongkol Balado", description: "Ikan tongkol dengan balado", categories: [.fish, .fried, .spicy, .savory], tenant: mamaDjempol),
                Food(name: "Tempe Orek", description: "Tempe goreng kecap", categories: [.soy, .fried, .sweet, .savory], tenant: mamaDjempol),
                Food(name: "Kangkung", description: "Tumis kangkung", categories: [.vegetables, .fried, .savory], tenant: mamaDjempol),
                Food(name: "Sayur Toge", description: "Tumis toge", categories: [.vegetables, .fried, .savory], tenant: mamaDjempol)
            ]
            foods.append(contentsOf: mamaDjempolFoods)
        }
        
        // Dapur Mimin foods
        if let dapurMimin = tenants.first(where: { $0.name == "Dapur Mimin" }) {
            let dapurMiminFoods = [
                Food(name: "Tempe", description: "Tempe", categories: [.soy, .fried, .savory], tenant: dapurMimin),
                Food(name: "Telor Kecap", description: "Telur, kecap", categories: [.eggs, .fried, .sweet, .savory], tenant: dapurMimin),
                Food(name: "Jamur Cabe Garam", description: "Jamur, cabe, garam", categories: [.mushroom, .vegetables, .fried, .spicy, .savory], tenant: dapurMimin),
                Food(name: "Ikan Bandeng Presto", description: "Ikan bandeng presto", categories: [.fish, .steamed, .fried, .savory], tenant: dapurMimin),
                Food(name: "Perkedel Jagung", description: "Jagung, goreng", categories: [.vegetables, .fried, .savory, .sweet], tenant: dapurMimin),
                Food(name: "Tahu Telur Nasi", description: "Tahu, telur, nasi, saus kacang", categories: [.soy, .eggs, .rice, .nuts, .fried, .savory, .sweet], tenant: dapurMimin),
                Food(name: "Gado Polos", description: "Sayuran, bumbu kacang", categories: [.vegetables, .nuts, .steamed, .savory, .sweet], tenant: dapurMimin),
                Food(name: "Gado Gado + Telur", description: "Sayuran, bumbu kacang, telur", categories: [.vegetables, .nuts, .eggs, .steamed, .savory, .sweet], tenant: dapurMimin),
                Food(name: "Mieprak", description: "Mie instan", categories: [.gluten, .soup, .savory], tenant: dapurMimin),
                Food(name: "Nasi Kebuli", description: "Nasi, rempah, kaldu", categories: [.rice, .meat, .steamed, .savory], tenant: dapurMimin),
                Food(name: "Nasi Briyani", description: "Nasi, rempah, daging", categories: [.rice, .meat, .steamed, .savory], tenant: dapurMimin),
                Food(name: "Siomay (3 pcs)", description: "Ikan, tepung, bumbu kacang", categories: [.fish, .gluten, .nuts, .steamed, .savory], tenant: dapurMimin),
                Food(name: "Soto Ayam", description: "Ayam, kuah soto, rempah", categories: [.chicken, .soup, .savory], tenant: dapurMimin),
                Food(name: "Tahu Sechuan", description: "Tahu, bumbu Szechuan", categories: [.soy, .fried, .spicy, .savory], tenant: dapurMimin)
            ]
            foods.append(contentsOf: dapurMiminFoods)
        }
        
        // Nasi Kapau Nusantara foods
        if let nasiKapau = tenants.first(where: { $0.name == "Nasi Kapau Nusantara" }) {
            let nasiKapauFoods = [
                Food(name: "Nasi Padang", description: "Nasi dengan berbagai pilihan lauk khas Padang", categories: [.rice, .meat, .chicken, .fish, .vegetables, .eggs, .fried, .soup, .roasted, .savory, .spicy], tenant: nasiKapau),
                Food(name: "Rendang Daging", description: "Daging sapi yang dimasak dalam bumbu rendang yang kaya rempah", categories: [.meat, .soup, .savory, .spicy], tenant: nasiKapau),
                Food(name: "Ayam Gulai", description: "Ayam yang dimasak dalam kuah gulai kuning yang gurih", categories: [.chicken, .soup, .savory, .spicy], tenant: nasiKapau),
                Food(name: "Ayam Bakar", description: "Ayam yang dibakar dengan bumbu khas", categories: [.chicken, .roasted, .savory, .spicy], tenant: nasiKapau),
                Food(name: "Ikan Bakar", description: "Ikan yang dibakar dengan bumbu khas", categories: [.fish, .roasted, .savory, .spicy], tenant: nasiKapau),
                Food(name: "Telur Dadar", description: "Telur dadar khas Padang yang tebal dan renyah", categories: [.eggs, .fried, .savory], tenant: nasiKapau),
                Food(name: "Sayur Nangka", description: "Gulai nangka muda", categories: [.vegetables, .soup, .savory, .spicy], tenant: nasiKapau),
                Food(name: "Daun Singkong", description: "Daun singkong rebus yang dibumbui", categories: [.vegetables, .steamed, .savory], tenant: nasiKapau),
                Food(name: "Sambal Ijo", description: "Sambal cabai hijau khas Padang", categories: [.vegetables, .fried, .spicy, .savory], tenant: nasiKapau),
                Food(name: "Kerupuk Kulit", description: "Kerupuk kulit sapi goreng", categories: [.meat, .snacks, .fried, .savory], tenant: nasiKapau)
            ]
            foods.append(contentsOf: nasiKapauFoods)
        }
        
        // Warung Padang Sederhana foods
        if let padangSederhana = tenants.first(where: { $0.name == "Warung Padang Sederhana" }) {
            let padangSederhanaFoods = [
                Food(name: "Rendang Daging", description: "Daging sapi dengan bumbu rendang khas Padang", categories: [.meat, .soup, .savory, .spicy], tenant: padangSederhana),
                Food(name: "Ayam Pop", description: "Ayam yang dimasak dengan bumbu khas Padang", categories: [.chicken, .steamed, .savory], tenant: padangSederhana),
                Food(name: "Ikan Asam Padeh", description: "Ikan dengan kuah asam pedas", categories: [.fish, .soup, .sour, .spicy, .savory], tenant: padangSederhana),
                Food(name: "Dendeng Batokok", description: "Daging sapi yang dipukul dan digoreng", categories: [.meat, .fried, .savory, .spicy], tenant: padangSederhana),
                Food(name: "Sayur Nangka", description: "Gulai nangka muda", categories: [.vegetables, .soup, .savory, .spicy], tenant: padangSederhana)
            ]
            foods.append(contentsOf: padangSederhanaFoods)
        }
        
        // Bakso Malang foods
        if let baksoMalang = tenants.first(where: { $0.name == "Bakso Malang" }) {
            let baksoMalangFoods = [
                Food(name: "Bakso Urat", description: "Bakso dengan urat sapi", categories: [.meat, .soup, .savory], tenant: baksoMalang),
                Food(name: "Bakso Telur", description: "Bakso dengan telur puyuh", categories: [.meat, .eggs, .soup, .savory], tenant: baksoMalang),
                Food(name: "Mie Goreng", description: "Mie goreng dengan bumbu khas", categories: [.gluten, .chicken, .meat, .seafood, .vegetables, .eggs, .fried, .savory, .sweet], tenant: baksoMalang),
                Food(name: "Pangsit Goreng", description: "Pangsit goreng renyah", categories: [.gluten, .meat, .snacks, .fried, .savory], tenant: baksoMalang)
            ]
            foods.append(contentsOf: baksoMalangFoods)
        }
        
        // Warung Nasi Uduk foods
        if let nasiUduk = tenants.first(where: { $0.name == "Warung Nasi Uduk" }) {
            let nasiUdukFoods = [
                Food(name: "Nasi Uduk", description: "Nasi gurih dengan bumbu khas", categories: [.rice, .steamed, .savory], tenant: nasiUduk),
                Food(name: "Ayam Goreng", description: "Ayam goreng krispi", categories: [.chicken, .fried, .savory], tenant: nasiUduk),
                Food(name: "Tempe Goreng", description: "Tempe goreng krispi", categories: [.soy, .fried, .savory], tenant: nasiUduk),
                Food(name: "Telur Dadar", description: "Telur dadar tebal", categories: [.eggs, .fried, .savory], tenant: nasiUduk),
                Food(name: "Sambal Kacang", description: "Sambal kacang khas", categories: [.nuts, .vegetables, .fried, .spicy, .savory, .sweet], tenant: nasiUduk)
            ]
            foods.append(contentsOf: nasiUdukFoods)
        }
        
        // Warung Lokal foods
        if let warungLokal = tenants.first(where: { $0.name == "Warung Lokal" }) {
            let warungLokalFoods = [
                Food(name: "Nasi Goreng", description: "Nasi goreng spesial dengan bumbu khas", categories: [.rice, .chicken, .meat, .seafood, .eggs, .vegetables, .fried, .savory, .sweet], tenant: warungLokal),
                Food(name: "Mie Goreng", description: "Mie goreng dengan bumbu khas", categories: [.gluten, .chicken, .meat, .seafood, .vegetables, .eggs, .fried, .savory, .sweet], tenant: warungLokal),
                Food(name: "Nasi Campur", description: "Nasi dengan berbagai lauk pilihan", categories: [.rice, .meat, .chicken, .vegetables, .eggs, .fried, .steamed, .roasted, .soup, .savory, .spicy, .sweet], tenant: warungLokal),
                Food(name: "Nasi Uduk", description: "Nasi gurih dengan bumbu khas", categories: [.rice, .steamed, .savory], tenant: warungLokal)
            ]
            foods.append(contentsOf: warungLokalFoods)
        }
        
        // Warung Makan Pak Haji foods
        if let warungPakHaji = tenants.first(where: { $0.name == "Warung Makan Pak Haji" }) {
            let warungPakHajiFoods = [
                Food(name: "Nasi Campur", description: "Nasi dengan berbagai lauk pilihan", categories: [.rice, .meat, .chicken, .vegetables, .eggs, .fried, .steamed, .roasted, .soup, .savory, .spicy, .sweet], tenant: warungPakHaji),
                Food(name: "Ayam Penyet", description: "Ayam goreng dengan sambal", categories: [.chicken, .fried, .spicy, .savory], tenant: warungPakHaji),
                Food(name: "Ikan Gurame", description: "Ikan gurame goreng", categories: [.fish, .fried, .savory], tenant: warungPakHaji),
                Food(name: "Sayur Asem", description: "Sayur asem khas", categories: [.vegetables, .soup, .sour, .savory, .sweet], tenant: warungPakHaji)
            ]
            foods.append(contentsOf: warungPakHajiFoods)
        }
        
        // Warung Pecel foods
        if let warungPecel = tenants.first(where: { $0.name == "Warung Pecel" }) {
            let warungPecelFoods = [
                Food(name: "Pecel", description: "Sayuran dengan bumbu kacang", categories: [.vegetables, .nuts, .steamed, .savory, .sweet, .spicy], tenant: warungPecel),
                Food(name: "Rawon", description: "Sup daging dengan kuah hitam", categories: [.meat, .soup, .savory], tenant: warungPecel),
                Food(name: "Tempe Penyet", description: "Tempe goreng dengan sambal", categories: [.soy, .fried, .spicy, .savory], tenant: warungPecel),
                Food(name: "Tahu Penyet", description: "Tahu goreng dengan sambal", categories: [.soy, .fried, .spicy, .savory], tenant: warungPecel)
            ]
            foods.append(contentsOf: warungPecelFoods)
        }
        
        // Warung Soto foods
        if let warungSoto = tenants.first(where: { $0.name == "Warung Soto" }) {
            let warungSotoFoods = [
                Food(name: "Soto Ayam", description: "Sup ayam dengan bumbu kuning", categories: [.chicken, .soup, .savory], tenant: warungSoto),
                Food(name: "Soto Daging", description: "Sup daging dengan bumbu kuning", categories: [.meat, .soup, .savory], tenant: warungSoto),
                Food(name: "Soto Babat", description: "Sup babat dengan bumbu kuning", categories: [.meat, .soup, .savory], tenant: warungSoto),
                Food(name: "Tempe Goreng", description: "Tempe goreng krispi", categories: [.soy, .fried, .savory], tenant: warungSoto)
            ]
            foods.append(contentsOf: warungSotoFoods)
        }
        
        // Warung Gorengan foods
        if let warungGorengan = tenants.first(where: { $0.name == "Warung Gorengan" }) {
            let warungGorenganFoods = [
                Food(name: "Tempe Goreng", description: "Tempe goreng krispi", categories: [.soy, .fried, .savory], tenant: warungGorengan),
                Food(name: "Tahu Goreng", description: "Tahu goreng krispi", categories: [.soy, .fried, .savory], tenant: warungGorengan),
                Food(name: "Bakwan", description: "Bakwan sayur goreng", categories: [.vegetables, .gluten, .snacks, .fried, .savory], tenant: warungGorengan),
                Food(name: "Pisang Goreng", description: "Pisang goreng krispi", categories: [.snacks, .fried, .sweet], tenant: warungGorengan)
            ]
            foods.append(contentsOf: warungGorenganFoods)
        }
        
        return foods
    }

    private func deleteInitialData() async {
        do {
            let canteens = try context.fetch(FetchDescriptor<Canteen>())
            for canteen in canteens {
                context.delete(canteen)
            }
            
            let tenants = try context.fetch(FetchDescriptor<Tenant>())
            for tenant in tenants {
                context.delete(tenant)
            }
            
            let foods = try context.fetch(FetchDescriptor<Food>())
            for food in foods {
                context.delete(food)
            }
            
            try context.save()
        } catch {
            fatalError(error.localizedDescription)
        }
        
        print("Delete Initial Success")
        print("===============================")
    }

    private func showInsertedData() {
        for canteen in canteensFromDataStore {
            print("=== Canteens ===")
            print("Nama: \(canteen.name), Lokasi: (\(canteen.latitude), \(canteen.longitude))")
            for tenant in canteen.tenants {
                print("Nama: \(tenant.name) Halal: \( (tenant.isHalal ?? false) ? "Yes" : "No")")
                for food in tenant.foods {
                    print("Nama: \(food.name), Deskripsi: \(food.desc), Tenant: \(food.tenant?.name ?? "Unknown")")
                }
            }
        }
    }

    // Extracted main content view logic
    @ViewBuilder
    private var mainContent: some View {
        let shouldLoadData = canteensFromDataStore.isEmpty && tenantsFromDataStore.isEmpty && foodsFromDataStore.isEmpty

        Group {
            if showOnboarding {
                OnboardingView(showOnboarding: $showOnboarding, showPreferences: $showPreferences)
                    .environmentObject(locationManager)
            } else {
                MapView(
                    displayTenants: tenantsFromDataStore,
                    displayCanteens: canteensFromDataStore,
                    allTenantsForSearch: tenantsFromDataStore,
                    allFoodsForSearch: foodsFromDataStore,
                    showTutorial: $showTutorial,
                    deepLinkTenantID: deepLinkTenantID,
                    modelContext: context,
                    showSearchModal: $showSearchModal,
                    showDetail: $showDetail,
                    showEasterEgg: $showEasterEgg
                )
                .environmentObject(locationManager)
            }
        }
    }

    var body: some View {
        // Call the extracted mainContent and apply modifiers here
        mainContent
            .task {
                let needsInitialDataLoad = canteensFromDataStore.isEmpty && tenantsFromDataStore.isEmpty && foodsFromDataStore.isEmpty
                if needsInitialDataLoad {
                    await insertInitialData()
                }
            }
            .onChange(of: tenantsFromDataStore) { _, newTenants in
                if !newTenants.isEmpty && !hasIndexedSpotlightThisSession {
                    indexTenantsForSpotlight()
                    hasIndexedSpotlightThisSession = true
                }
                if deepLinkTenantID != nil && !newTenants.isEmpty && !navigateToTenantViewFromDeepLink {
                     navigateToTenantViewFromDeepLink = true
                }
            }
            .onChange(of: deepLinkTenantID) { oldValue, newValue in
                print("deepLinkTenantID changed from \(String(describing: oldValue)) to \(String(describing: newValue))")
                if let newID = newValue {
                    print("Deep link received for tenant ID: \(newID)")
                    // Tutup semua sheet/modal lain sebelum membuka TenantView
                    showPreferences = false
                    showSearchModal = false
                    showDetail = false
                    showTutorial = false
                    showEasterEgg = false
                    
                    // Tambahkan delay untuk memastikan data siap
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if !tenantsFromDataStore.isEmpty {
                            print("Data ready, navigating to tenant view")
                            navigateToTenantViewFromDeepLink = true
                        } else {
                            print("Data not ready yet, waiting...")
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $navigateToTenantViewFromDeepLink) {
                if let tenantID = deepLinkTenantID {
                    if let tenant = tenantsFromDataStore.first(where: { $0.id == tenantID }) {
                        TenantView(tenant: tenant, foods: tenant.foods, selectedCategories: .constant([]))
                            .onDisappear {
                                print("TenantView dismissed")
                                navigateToTenantViewFromDeepLink = false
                                showSearchModal = true
                                onDeepLinkTenantViewDismiss?()
                                deepLinkedTenant = nil
                            }
                    } else {
                        Text("Tenant not found from deep link")
                            .onAppear {
                                print("Tenant not found in data store")
                            }
                    }
                }
            }
    }
    
    private func indexTenantsForSpotlight() {
        var searchableItems: [CSSearchableItem] = []
        for tenant in tenantsFromDataStore {
            let attributeSet = CSSearchableItemAttributeSet(contentType: .item)
            attributeSet.title = tenant.name
            attributeSet.contentDescription = "\(tenant.canteen?.name ?? "") - \(tenant.operationalHours)"
            attributeSet.keywords = [tenant.name, tenant.canteen?.name ?? "", "tenant", "food", "canteen"]

            let searchableItem = CSSearchableItem(
                uniqueIdentifier: tenant.id.uuidString,
                domainIdentifier: "com.gopeat.tenant",
                attributeSet: attributeSet
            )
            searchableItems.append(searchableItem)
        }
        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if let error = error {
                print("Error indexing tenants: \(error.localizedDescription)")
            } else {
                print("Tenants indexed successfully for Spotlight.")
            }
        }
    }

    // Computed property for foods filtered by preferences
    private var visibleFoods: [Food] {
        foodsFromDataStore.filter { !PreferenceManager.shared.isFoodHidden($0) }
    }

    // Computed property for tenants filtered by preferences
    // A tenant is visible if it's not empty and not all its foods are hidden by preferences.
    private var visibleTenants: [Tenant] {
        tenantsFromDataStore.filter { tenant in
            // Get all original foods for this tenant
            let originalFoodsForTenant = foodsFromDataStore.filter { $0.tenant?.id == tenant.id }
            return !PreferenceManager.shared.isTenantHidden(tenant, allFoodsForTenant: originalFoodsForTenant)
        }
    }
    
    // Helper to get visible foods for a specific tenant
    private func visibleFoods(for tenant: Tenant) -> [Food] {
        foodsFromDataStore.filter { $0.tenant?.id == tenant.id && !PreferenceManager.shared.isFoodHidden($0) }
    }
}

#Preview {
    ContentView(
        showOnboarding: true,
        deepLinkTenantID: nil,
        onDeepLinkTenantViewDismiss: nil
    )
    .modelContainer(for: [Canteen.self, Tenant.self, Food.self])
}
