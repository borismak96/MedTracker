import SwiftUI
import SwiftData

struct MedicalCardView: View {
    var profile: UserProfile
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Card Header
            HStack {
                Text("Medical Card")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isShowing = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding()
            .background(Color.mint)
                            
                            // User Info
                            HStack(spacing: 16) {
                                if let data = profile.profileImageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.mint, lineWidth: 3))
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .frame(width: 80, height: 80)
                                        .foregroundColor(.mint.opacity(0.3))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(profile.name.isEmpty ? "Name Not Set" : profile.name)
                                        .font(.system(.title2, design: .rounded, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text("Patient")
                                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(20)
                            
                            Divider()
                                .padding(.horizontal, 20)
                            
                            // Medications List
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Current Medications")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundColor(.primary)
                                    .padding(.bottom, 4)
                                
                                let activeMeds = profile.medications.filter { !$0.name.isEmpty }
                                
                                if activeMeds.isEmpty {
                                    Text("No medications added.")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                } else {
                                    ForEach(activeMeds) { med in
                                        HStack(spacing: 16) {
                                            Image(systemName: "pills.fill")
                                                .font(.title2)
                                                .foregroundColor(.mint)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(med.name)
                                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                                    .foregroundColor(.primary)
                                                if !med.dose.isEmpty {
                                                    Text(med.dose)
                                                        .font(.system(.caption, design: .rounded, weight: .medium))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                        }
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
                        .padding(20)
    }
}
