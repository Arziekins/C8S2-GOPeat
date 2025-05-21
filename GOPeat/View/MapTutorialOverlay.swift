import SwiftUI

struct MapTutorialOverlay: View {
    @Binding var isPresented: Bool
    var onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent dark background
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                // Add these modifiers to ensure overlay is above sheets
                .accessibilityHidden(true)
                .allowsHitTesting(true)
            
            VStack(spacing: 24) {
                Image(systemName: "map")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                
                VStack(spacing: 16) {
                    TutorialItem(
                        icon: "hand.draw",
                        title: "Drag to Move",
                        description: "Drag the map to explore different areas"
                    )
                    
                    TutorialItem(
                        icon: "arrow.up.backward.and.arrow.down.forward",
                        title: "Pinch to Zoom",
                        description: "Zoom in and out to see more details"
                    )
                    
                    TutorialItem(
                        icon: "hand.tap",
                        title: "Tap Markers",
                        description: "Tap on markers to see canteen details"
                    )
                }
                .padding(.horizontal)
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                        onDismiss()
                    }
                }) {
                    Text("Got it!")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 200)
                        .padding()
                        .background(Color.sample)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
        }
        // Add these modifiers to ensure proper z-index and interaction
        .zIndex(999)
        .ignoresSafeArea()
    }
}

struct TutorialItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .frame(width: 32)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    MapTutorialOverlay(isPresented: .constant(true)) {}
        .preferredColorScheme(.dark)
}
