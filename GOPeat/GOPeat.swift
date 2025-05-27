//
//  GOPeatApp.swift
//  GOPeat
//
//  Created by jonathan calvin sutrisna on 09/03/25.
//

import SwiftUI
import SwiftData
import CoreSpotlight

@main
struct GOPeat: App {
    @State private var spotlightTenantID: UUID? = nil

    var body: some Scene {
        WindowGroup {
            ContentView(
                showOnboarding: !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"),
                deepLinkTenantID: spotlightTenantID,
                onDeepLinkTenantViewDismiss: {
                    print("Resetting spotlightTenantID from ContentView callback")
                    self.spotlightTenantID = nil
                }
            )
            .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
                if let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                   let tenantID = UUID(uuidString: uniqueIdentifier) {
                    print("Deep link received for tenant ID: \(tenantID)")
                    self.spotlightTenantID = tenantID
                }
            }
        }
        .modelContainer(for: [Canteen.self, Tenant.self, Food.self])
    }
}
