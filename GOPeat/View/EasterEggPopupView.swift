import SwiftUI

struct EasterEggPopupView: View {
    @Binding var isPresented: Bool // This will bind to $easterEggViewModel.presentFullscreenFoodDetail
    let foodDetails: (name: String, desc: String, categories: String, tenantName: String, canteenName: String)

    @State private var showContent = false // For entry animation
    @State private var celebrateScale: CGFloat = 1.0 // For celebration animation
    @State private var celebrateOpacity: Double = 0.0 // For particle/confetti effect, if added

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissView()
                }

            VStack(spacing: 20) {
                Text("✨ Bingung Mau Makan Apa? ✨")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .scaleEffect(celebrateScale * (foodDetails.name == "No Food Found!" ? 0.9 : 1.0)) // Slightly smaller if no food
                    .opacity(showContent ? 1 : 0)

                VStack(alignment: .leading, spacing: 12) {
                    Text(foodDetails.name)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(foodDetails.name == "No Food Found!" ? .orange : .white)
                    
                    if foodDetails.name != "No Food Found!" {
                        Text("Dari: \(foodDetails.tenantName) (\(foodDetails.canteenName))")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }

                    if !foodDetails.desc.isEmpty {
                        Text(foodDetails.desc)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(foodDetails.name == "No Food Found!" ? .gray : .white.opacity(0.9))
                            .lineLimit(3)
                    }

                    if !foodDetails.categories.isEmpty {
                        Text("Kategori: \(foodDetails.categories)")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.black.opacity(0.6))
                        .shadow(color: .yellow.opacity(0.3), radius: 5, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.yellow.opacity(0.7), lineWidth: 1.5)
                )
                .padding(.horizontal, 10) // Ensure it doesn't touch edges
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

                Button(action: {
                    dismissView()
                }) {
                    Text(foodDetails.name == "No Food Found!" ? "Mengerti" : "Mantap! Tutup")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color("Sample")) // Using Color from asset catalog
                        .cornerRadius(10)
                        .shadow(radius: 3)
                }
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.8)
            }
            .padding(EdgeInsets(top: 40, leading: 20, bottom: 40, trailing: 20)) // Overall padding for the content VStack
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Simple celebration: repeating pulse on title
            .onAppear {
                // Haptic for popup appearance
                let haptic = UIImpactFeedbackGenerator(style: .light)
                haptic.impactOccurred()
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6, blendDuration: 0).delay(0.1)) {
                    showContent = true
                }
                if foodDetails.name != "No Food Found!" { // Only animate if food is found
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.5)) {
                        celebrateScale = 1.05
                    }
                }
            }
        }
        .background(ClearBackgroundView().ignoresSafeArea()) // Allow tap-through for dimming layer
    }
    
    private func dismissView() {
        withAnimation(.easeOut(duration: 0.3)) {
            showContent = false // Optional: animate content out
        }
        // Delay dismissal to allow animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}

// Helper for full screen cover tap-to-dismiss if needed, though .onTapGesture on ZStack bg should work
struct ClearBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            // Attempt to make the hosting controller's view background clear
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

#if DEBUG
struct EasterEggPopupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            EasterEggPopupView(
                isPresented: .constant(true),
                foodDetails: (
                    name: "Nasi Goreng Spesial Super Pedas Menggoda Selera Anak Kosan",
                    desc: "Nasi goreng legendaris dengan bumbu rahasia turun temurun, dijamin membuat lidah bergoyang dan dompet tetap tenang.",
                    categories: "Rice, Chicken, Spicy, Savory",
                    tenantName: "Warung Pojok Anti Galau",
                    canteenName: "Kantin Kejujuran Lt. 7"
                )
            )
            .previewDisplayName("Food Found")
            
            EasterEggPopupView(
                isPresented: .constant(true),
                foodDetails: (
                    name: "No Food Found!",
                    desc: "Yah, kayaknya belum ada makanan yang cocok sama seleramu saat ini. Coba atur ulang preferensimu ya!",
                    categories: "",
                    tenantName: "GOPeat System",
                    canteenName: "Universe"
                )
            )
            .previewDisplayName("No Food Found")
        }
    }
}
#endif 