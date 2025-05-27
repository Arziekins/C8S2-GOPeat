//
//  SplashView.swift
//  GOPeat
//
//  Created by jonathan calvin sutrisna on 10/04/25.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var size = 0.8
    @State private var opacity = 0.5
    @Binding var deepLinkTenantID: UUID?
    
    init(deepLinkTenantID: Binding<UUID?> = .constant(nil)) {
        self._deepLinkTenantID = deepLinkTenantID
    }
    
    var body: some View {
        if isActive {
            ContentView(
                showOnboarding: !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"),
                deepLinkTenantID: deepLinkTenantID,
                onDeepLinkTenantViewDismiss: nil
            )
        } else {
            VStack {
                Image("AppImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            }
            .scaleEffect(size)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 1.2)) {
                    self.size = 0.9
                    self.opacity = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        self.isActive = true
                    }
                }
            }
        }
    }
}
