import SwiftUI

struct AboutUsView: View {
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(Color.mint.opacity(0.15))
                                .frame(width: 100, height: 100)
                            Image(systemName: "pills.fill")
                                .font(.system(size: 42))
                                .foregroundColor(.mint)
                        }
                        .padding(.top, 8)
                        
                        VStack(spacing: 6) {
                            Text("MedTracker")
                                .font(.system(.title, design: .rounded, weight: .heavy))
                                .foregroundColor(.primary)
                            
                            Text("Version 1.0")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(LocalizedStringKey("About_Us_Content"))
                            .font(.system(.body, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.top, 4)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(30)
                    .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(LocalizedStringKey("About Us"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
