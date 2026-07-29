import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: MedTrackerViewModel
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Info")) {
                    TextField("Name", text: $viewModel.profile.name)
                }
                
                Section(header: Text("Medication Details")) {
                    TextField("Medication Name", text: $viewModel.profile.medicationName)
                    
                    Picker("Target Hour", selection: $viewModel.profile.targetTimeHour) {
                        ForEach(0..<24) { hour in
                            Text("\(hour):00").tag(hour)
                        }
                    }
                    
                    Picker("Target Minute", selection: $viewModel.profile.targetTimeMinute) {
                        ForEach(0..<60) { minute in
                            if minute % 5 == 0 {
                                Text("\(minute) min").tag(minute)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        // In a real app, this would schedule local notifications
                    }) {
                        HStack {
                            Image(systemName: "bell.badge")
                            Text("Enable Daily Reminders")
                        }
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}
