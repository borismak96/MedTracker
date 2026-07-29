import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \MedicationLog.date, order: .reverse) private var logs: [MedicationLog]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(logs) { log in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(log.date, style: .date)
                                .font(.headline)
                            
                            if log.isTaken {
                                Text("Taken")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            } else if let skipped = log.skippedTime {
                                Text("Missed at \(skipped, style: .time)")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                
                                if let reaction = log.physicalReaction, !reaction.isEmpty {
                                    Text("Reaction: \(reaction)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("Not recorded yet")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if log.isTaken {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                        } else if log.skippedTime != nil {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.title2)
                        } else {
                            Image(systemName: "circle.dashed")
                                .foregroundColor(.gray)
                                .font(.title2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("History")
        }
    }
}
