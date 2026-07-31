import SwiftUI
import SwiftData
import Charts

struct BloodPressureChartView: View {
    @Environment(\.dismiss) private var dismiss
    var logs: [MedicationLog]
    
    private var validLogs: [MedicationLog] {
        logs.filter { $0.systolic != nil && $0.diastolic != nil }.sorted(by: { $0.date < $1.date })
    }
    
    private var recentLogs: [MedicationLog] {
        Array(validLogs.suffix(14))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if validLogs.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "chart.xyaxis.line")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                                Text("No data to display yet.")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recent Trends")
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                
                                Chart {
                                    ForEach(recentLogs, id: \.id) { log in
                                        if let sys = log.systolic, let dia = log.diastolic {
                                            LineMark(
                                                x: .value("Date", log.date, unit: .day),
                                                y: .value("Value", sys)
                                            )
                                            .foregroundStyle(by: .value("Type", String(localized: "Systolic")))
                                            .symbol(Circle())
                                            
                                            LineMark(
                                                x: .value("Date", log.date, unit: .day),
                                                y: .value("Value", dia)
                                            )
                                            .foregroundStyle(by: .value("Type", String(localized: "Diastolic")))
                                            .symbol(Circle())
                                        }
                                    }
                                }
                                .chartForegroundStyleScale([
                                    String(localized: "Systolic"): Color.red,
                                    String(localized: "Diastolic"): Color.blue
                                ])
                                .chartYScale(domain: 40...200)
                                .chartXAxis {
                                    AxisMarks(values: .automatic(desiredCount: min(recentLogs.count, 6))) { value in
                                        AxisGridLine()
                                        AxisTick()
                                        AxisValueLabel {
                                            if let date = value.as(Date.self) {
                                                Text(date, format: .dateTime.month(.abbreviated).day())
                                                    .font(.system(.caption2, design: .rounded))
                                            }
                                        }
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks(position: .leading)
                                }
                                .chartLegend(position: .bottom, alignment: .center)
                                .frame(height: 280)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(20)
                                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text(LocalizedStringKey("History"))
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                
                                ForEach(validLogs.reversed().prefix(30), id: \.id) { log in
                                    if let sys = log.systolic, let dia = log.diastolic {
                                        HStack {
                                            Text(log.date, format: .dateTime.year().month().day())
                                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                            Spacer()
                                            Text("\(sys) / \(dia) mmHg")
                                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                                .foregroundColor(.red)
                                        }
                                        .padding(14)
                                        .background(Color.white)
                                        .cornerRadius(14)
                                        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("BP Trends")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() }.font(.system(.body, design: .rounded, weight: .bold)))
        }
    }
}
