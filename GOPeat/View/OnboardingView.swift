import SwiftUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @Binding var showPreferences: Bool
    @EnvironmentObject private var locationManager: LocationManager
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Image("AppImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 120)
                Spacer()
            }
            HStack {
                Text("Welcome to GOPeat!")
                    .font(.title2).bold()
                Spacer()
            }
            Text("Your assistant in finding the perfect canteen for you!")
                .font(.body)
                .foregroundColor(.black)
            Spacer()
            Button(action: { showPreferences = true }) {
                Text("Personalize me!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.sample)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            Text("or")
                .foregroundColor(.secondary)
                .font(.subheadline)
            Button(action: { showOnboarding = false }) {
                Text("i can eat anything..")
                    .font(.subheadline.bold())
                    .foregroundColor(.gray)
                    .underline()
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24)
        .fullScreenCover(isPresented: $showPreferences) {
            PreferencesView(showOnboarding: $showOnboarding)
                .environmentObject(locationManager)
        }
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true), showPreferences: .constant(false))
}
