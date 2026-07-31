import SwiftUI
import SwiftData
import Charts

struct BloodPressureChartView: View {
    @Environment(\.dismiss) private var dismiss
    var logs: [MedicationLog]
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                
                VStack {
                    let validLogs = logs.filter { $0.systolic != nil && $0.diastolic != nil }.sorted(by: { $0.date < $1.date })
                    
                    if validLogs.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                            Text("No data to display yet.")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        VStack(alignment: .leading) {
                            Text("Recent Trends")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .padding(.bottom, 8)
                            
                            Chart {
                                ForEach(validLogs) { log in
                                    if let sys = log.systolic, let dia = log.diastolic {
                                        LineMark(
                                            x: .value("Date", log.date, unit: .day),
                                            y: .value("Value", sys)
                                        )
                                        .foregroundStyle(.red)
                                        .symbol(Circle())
                                        
                                        LineMark(
                                            x: .value("Date", log.date, unit: .day),
                                            y: .value("Value", dia)
                                        )
                                        .foregroundStyle(.blue)
                                        .symbol(Circle())
                                    }
                                }
                            }
                            .chartYScale(domain: 40...200)
                            .frame(height: 300)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                            
                            HStack(spacing: 24) {
                                HStack(spacing: 8) {
                                    Circle().fill(Color.red).frame(width: 12, height: 12)
                                    Text("Systolic")
                                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                                }
                                HStack(spacing: 8) {
                                    Circle().fill(Color.blue).frame(width: 12, height: 12)
                                    Text("Diastolic")
                                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                                }
                            }
                            .padding(.top, 16)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding()
                        Spacer()
                    }
                }
            }
            .navigationTitle("BP Trends")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() }.font(.system(.body, design: .rounded, weight: .bold)))
        }
    }
}