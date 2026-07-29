import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: MedTrackerViewModel
    @State private var showingSkipSheet = false
    @State private var skipNotes = ""
    @State private var skipReaction = ""
    @State private var skippedTime = Date()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    todayCard
                    statsSection
                }
                .padding()
            }
            .navigationTitle("MedTracker")
            .sheet(isPresented: $showingSkipSheet) {
                skipSheetContent
            }
        }
    }
    
    var headerSection: some View {
        HStack {
            VStack(alignment: .leading) {
                if viewModel.profile.name.isEmpty {
                    Text("Hello!")
                        .font(.title2)
                        .bold()
                } else {
                    Text("Hello, \(viewModel.profile.name)!")
                        .font(.title2)
                        .bold()
                }
                Text("Let's stay on track today.")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    @ViewBuilder
    var todayCard: some View {
        if let todayBinding = viewModel.todayLog {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Medication")
                            .font(.headline)
                        if viewModel.profile.medicationName.isEmpty {
                            Text("Your Medication")
                                .font(.title)
                                .bold()
                                .foregroundColor(.blue)
                        } else {
                            Text(viewModel.profile.medicationName)
                                .font(.title)
                                .bold()
                                .foregroundColor(.blue)
                        }
                        
                        HStack {
                            Image(systemName: "clock")
                            Text("Scheduled for \(viewModel.profile.targetTimeDescription)")
                        }
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    }
                    Spacer()
                    Image(systemName: "pills.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue.opacity(0.8))
                }
                
                if todayBinding.wrappedValue.isTaken {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Taken Today")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    
                    Button(action: {
                        todayBinding.wrappedValue.isTaken = false
                    }) {
                        Text("Undo")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                } else if todayBinding.wrappedValue.skippedTime != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Skipped Today")
                                .bold()
                        }
                        
                        if let reaction = todayBinding.wrappedValue.physicalReaction, !reaction.isEmpty {
                            Text("Reaction: \(reaction)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    
                    Button(action: {
                        todayBinding.wrappedValue.skippedTime = nil
                        todayBinding.wrappedValue.physicalReaction = nil
                        todayBinding.wrappedValue.notes = nil
                    }) {
                        Text("Undo")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack(spacing: 16) {
                        Button(action: {
                            todayBinding.wrappedValue.isTaken = true
                        }) {
                            Text("Take Now")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            showingSkipSheet = true
                        }) {
                            Text("Skip / Missed")
                                .font(.headline)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
        }
    }
    
    var statsSection: some View {
        HStack {
            VStack {
                Text("\(viewModel.streakCount)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                Text("Day Streak")
                    .font(.subheadline)
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(16)
            
            VStack {
                let takenCount = viewModel.logs.prefix(30).filter { $0.isTaken }.count
                Text("\(takenCount)/30")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                Text("Last 30 Days")
                    .font(.subheadline)
                    .bold()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(16)
        }
    }
    
    var skipSheetContent: some View {
        NavigationView {
            Form {
                Section(header: Text("Missed Details")) {
                    DatePicker("Time", selection: $skippedTime, displayedComponents: .hourAndMinute)
                    
                    TextField("Physical Reaction (Optional)", text: $skipReaction)
                    
                    TextField("Additional Notes (Optional)", text: $skipNotes)
                }
                
                Button(action: {
                    if let todayBinding = viewModel.todayLog {
                        todayBinding.wrappedValue.skippedTime = skippedTime
                        todayBinding.wrappedValue.physicalReaction = skipReaction
                        todayBinding.wrappedValue.notes = skipNotes
                    }
                    showingSkipSheet = false
                }) {
                    Text("Save")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .bold()
                }
            }
            .navigationTitle("Missed Medication")
            .navigationBarItems(trailing: Button("Cancel") {
                showingSkipSheet = false
            })
        }
    }
}
