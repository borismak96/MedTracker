import SwiftUI
import SwiftData
import Charts

struct BloodPressureChartView: View {
    @Environment(\.dismiss) private var dismiss
    var logs: [MedicationLog]
    
    private var allReadings: [BloodPressureReading] {
        logs
            .flatMap { $0.allBPReadingsForExport() }
            .sorted { $0.recordedAt < $1.recordedAt }
    }
    
    private var recentReadings: [BloodPressureReading] {
        Array(allReadings.suffix(40))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if allReadings.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "chart.xyaxis.line")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                                Text(AppLocalization.string("No data to display yet."))
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(AppLocalization.string("Recent Trends"))
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                
                                Chart {
                                    ForEach(recentReadings) { reading in
                                        LineMark(
                                            x: .value("Date", reading.recordedAt),
                                            y: .value("Value", reading.systolic)
                                        )
                                        .foregroundStyle(by: .value("Type", AppLocalization.string("Systolic")))
                                        .symbol(Circle())
                                        
                                        LineMark(
                                            x: .value("Date", reading.recordedAt),
                                            y: .value("Value", reading.diastolic)
                                        )
                                        .foregroundStyle(by: .value("Type", AppLocalization.string("Diastolic")))
                                        .symbol(Circle())
                                    }
                                }
                                .chartForegroundStyleScale([
                                    AppLocalization.string("Systolic"): Color.red,
                                    AppLocalization.string("Diastolic"): Color.blue
                                ])
                                .chartYScale(domain: 40...200)
                                .chartXAxis {
                                    AxisMarks(values: .automatic(desiredCount: min(max(recentReadings.count, 1), 6))) { value in
                                        AxisGridLine()
                                        AxisTick()
                                        AxisValueLabel {
                                            if let date = value.as(Date.self) {
                                                Text(date, format: Date.FormatStyle().month(.abbreviated).day().locale(AppLocalization.locale))
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
                                Text(AppLocalization.string("History"))
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                
                                ForEach(Array(allReadings.reversed().prefix(40))) { reading in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(reading.recordedAt, format: Date.FormatStyle().year().month().day().locale(AppLocalization.locale))
                                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                                Text(reading.timeDescription)
                                                    .font(.system(.caption, design: .rounded))
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Text(reading.valueDescription)
                                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                                .foregroundColor(reading.category.color)
                                        }
                                        BloodPressureCategoryBadge(category: reading.category, compact: true)
                                    }
                                    .padding(14)
                                    .background(Color.white)
                                    .cornerRadius(14)
                                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(AppLocalization.string("BP Trends"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button(AppLocalization.string("Done")) { dismiss() }.font(.system(.body, design: .rounded, weight: .bold)))
        }
    }
}
