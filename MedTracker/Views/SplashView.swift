import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    @State private var textOpacity = 0.0
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.mint.opacity(0.6), Color.mint]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Animated Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                        .opacity(isAnimating ? 0.0 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 100, height: 100)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: "pills.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.mint)
                        .scaleEffect(isAnimating ? 1.1 : 0.9)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                }
                .padding(.bottom, 10)
                
                // App Title
                Text("MedTracker")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(textOpacity)
                
                Text("Stay on track with your health")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(textOpacity)
                
                Spacer()
                    .frame(height: 50)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            isAnimating = true
            withAnimation(.easeIn(duration: 1.2)) {
                textOpacity = 1.0
            }
        }
    }
}

#Preview {
    SplashView()
}
