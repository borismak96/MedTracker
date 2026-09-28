import Foundation
import UIKit

/// On-device clinic summary for the active household profile (no upload).
struct VisitPackSnapshot {
    var profileName: String
    var generatedAt: Date
    var windowDays: Int
    var medications: [VisitPackMedication]
    var summary: AdherenceStats.WindowSummary
    
    struct VisitPackMedication {
        var name: String
        var dose: String
        var scheduleEN: String
        var scheduleZH: String
    }
    
    static func build(profile: UserProfile, logs: [MedicationLog], days: Int, now: Date = Date()) -> VisitPackSnapshot {
        profile.ensureRemindersMigrated()
        let meds = profile.activeMedications.map { med in
            VisitPackMedication(
                name: med.name.trimmingCharacters(in: .whitespacesAndNewlines),
                dose: med.dose.trimmingCharacters(in: .whitespacesAndNewlines),
                scheduleEN: profile.scheduleDescription(for: med, chinese: false),
                scheduleZH: profile.scheduleDescription(for: med, chinese: true)
            )
        }
        return VisitPackSnapshot(
            profileName: profile.displayName,
            generatedAt: now,
            windowDays: days,
            medications: meds,
            summary: AdherenceStats.windowSummary(logs: logs, days: days, now: now)
        )
    }
    
    var mostCommonMood: MoodStatus? {
        var counts: [MoodStatus: Int] = [:]
        for raw in summary.moods {
            guard let mood = MoodStatus.from(string: raw) else { continue }
            counts[mood, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    var averageBPText: String? {
        let readings = summary.bpReadings
        guard !readings.isEmpty else { return nil }
        let sys = readings.map(\.systolic).reduce(0, +) / readings.count
        let dia = readings.map(\.diastolic).reduce(0, +) / readings.count
        return "\(sys) / \(dia) mmHg"
    }
    
    var averageHRText: String? {
        let readings = summary.hrReadings
        guard !readings.isEmpty else { return nil }
        let bpm = readings.map(\.bpm).reduce(0, +) / readings.count
        return "\(bpm) bpm"
    }
}

enum VisitPackPDF {
    @MainActor
    static func makePDF(snapshot: VisitPackSnapshot) -> URL? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 36
        let contentWidth = pageWidth - margin * 2
        
        let mint = UIColor(red: 0.0, green: 0.78, blue: 0.75, alpha: 1.0)
        let mintSoft = UIColor(red: 0.85, green: 0.97, blue: 0.95, alpha: 1.0)
        let cardWhite = UIColor.white
        let textPrimary = UIColor(white: 0.15, alpha: 1)
        let textSecondary = UIColor(white: 0.45, alpha: 1)
        
        let dateFormatterEN = DateFormatter()
        dateFormatterEN.locale = Locale(identifier: "en")
        dateFormatterEN.dateStyle = .medium
        
        let dateFormatterZH = DateFormatter()
        dateFormatterZH.locale = Locale(identifier: "zh-Hant")
        dateFormatterZH.dateStyle = .medium
        
        let stampEN = DateFormatter()
        stampEN.locale = Locale(identifier: "en")
        stampEN.dateStyle = .medium
        stampEN.timeStyle = .short
        
        let stampZH = DateFormatter()
        stampZH.locale = Locale(identifier: "zh-Hant")
        stampZH.dateStyle = .medium
        stampZH.timeStyle = .short
        
        let fileStamp = DateFormatter()
        fileStamp.locale = Locale(identifier: "en_US_POSIX")
        fileStamp.dateFormat = "yyyy-MM-dd"
        let fileName = "PillPal_VisitPack_\(fileStamp.string(from: snapshot.generatedAt)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        do {
            try renderer.writePDF(to: url) { context in
                var y: CGFloat = 0
                
                func beginPage() {
                    context.beginPage()
                    let bg = CGGradient(
                        colorsSpace: CGColorSpaceCreateDeviceRGB(),
                        colors: [
                            mintSoft.withAlphaComponent(0.9).cgColor,
                            UIColor.white.cgColor,
                            mintSoft.withAlphaComponent(0.7).cgColor
                        ] as CFArray,
                        locations: [0, 0.45, 1]
                    )!
                    context.cgContext.drawLinearGradient(
                        bg,
                        start: CGPoint(x: 0, y: 0),
                        end: CGPoint(x: pageWidth, y: pageHeight),
                        options: []
                    )
                    y = margin
                }
                
                func ensureSpace(_ needed: CGFloat) {
                    if y + needed > pageHeight - margin - 22 {
                        beginPage()
                    }
                }
                
                func drawRoundedRect(_ rect: CGRect, fill: UIColor) {
                    let path = UIBezierPath(roundedRect: rect, cornerRadius: 16)
                    context.cgContext.setShadow(offset: CGSize(width: 0, height: 3), blur: 8, color: UIColor.black.withAlphaComponent(0.06).cgColor)
                    fill.setFill()
                    path.fill()
                    context.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
                }
                
                func drawText(_ text: String, font: UIFont, color: UIColor, in rect: CGRect, alignment: NSTextAlignment = .left) -> CGFloat {
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.alignment = alignment
                    paragraph.lineBreakMode = .byWordWrapping
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: color,
                        .paragraphStyle: paragraph
                    ]
                    let ns = text as NSString
                    let size = ns.boundingRect(
                        with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: attrs,
                        context: nil
                    )
                    ns.draw(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: ceil(size.height)), withAttributes: attrs)
                    return ceil(size.height)
                }
                
                func L(_ key: String, chinese: Bool) -> String {
                    AppLocalization.string(key, chinese: chinese)
                }
                
                func F(_ key: String, chinese: Bool, _ args: CVarArg...) -> String {
                    AppLocalization.format(key, chinese: chinese, arguments: args)
                }
                
                func drawLanguageBlock(chinese: Bool) {
                    let dateFmt = chinese ? dateFormatterZH : dateFormatterEN
                    let stampFmt = chinese ? stampZH : stampEN
                    
                    ensureSpace(96)
                    let headerH: CGFloat = 88
                    drawRoundedRect(CGRect(x: margin, y: y, width: contentWidth, height: headerH), fill: mint)
                    _ = drawText(
                        L("Clinic Visit Pack", chinese: chinese),
                        font: .systemFont(ofSize: 22, weight: .heavy),
                        color: .white,
                        in: CGRect(x: margin + 18, y: y + 16, width: contentWidth - 36, height: 28)
                    )
                    _ = drawText(
                        "\(snapshot.profileName) · \(F("Last %lld days", chinese: chinese, snapshot.windowDays))",
                        font: .systemFont(ofSize: 13, weight: .semibold),
                        color: UIColor.white.withAlphaComponent(0.92),
                        in: CGRect(x: margin + 18, y: y + 48, width: contentWidth - 36, height: 22)
                    )
                    y += headerH + 12
                    
                    let disclaimer = L("Visit pack disclaimer", chinese: chinese)
                    let discFont = UIFont.systemFont(ofSize: 11, weight: .medium)
                    let discH = ceil((disclaimer as NSString).boundingRect(
                        with: CGSize(width: contentWidth - 32, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: [.font: discFont],
                        context: nil
                    ).height) + 20
                    ensureSpace(discH + 10)
                    drawRoundedRect(CGRect(x: margin, y: y, width: contentWidth, height: discH), fill: UIColor.systemYellow.withAlphaComponent(0.18))
                    _ = drawText(
                        disclaimer,
                        font: discFont,
                        color: textPrimary,
                        in: CGRect(x: margin + 16, y: y + 10, width: contentWidth - 32, height: discH)
                    )
                    y += discH + 12
                    
                    // Medications
                    ensureSpace(40)
                    _ = drawText(
                        L("Current Medications", chinese: chinese),
                        font: .systemFont(ofSize: 16, weight: .bold),
                        color: mint,
                        in: CGRect(x: margin, y: y, width: contentWidth, height: 22)
                    )
                    y += 28
                    
                    if snapshot.medications.isEmpty {
                        let empty = L("No medications added.", chinese: chinese)
                        let emptyH: CGFloat = 48
                        ensureSpace(emptyH + 8)
                        drawRoundedRect(CGRect(x: margin, y: y, width: contentWidth, height: emptyH), fill: cardWhite)
                        _ = drawText(empty, font: .systemFont(ofSize: 13, weight: .medium), color: textSecondary, in: CGRect(x: margin + 16, y: y + 14, width: contentWidth - 32, height: 22))
                        y += emptyH + 12
                    } else {
                        for med in snapshot.medications {
                            let schedule = chinese ? med.scheduleZH : med.scheduleEN
                            let dose = med.dose.isEmpty ? "—" : med.dose
                            let line2 = "\(L("Dose", chinese: chinese)): \(dose)  ·  \(L("Schedule", chinese: chinese)): \(schedule)"
                            let h: CGFloat = 58
                            ensureSpace(h + 8)
                            drawRoundedRect(CGRect(x: margin, y: y, width: contentWidth, height: h), fill: cardWhite)
                            _ = drawText(med.name, font: .systemFont(ofSize: 14, weight: .bold), color: textPrimary, in: CGRect(x: margin + 16, y: y + 10, width: contentWidth - 32, height: 20))
                            _ = drawText(line2, font: .systemFont(ofSize: 11, weight: .medium), color: textSecondary, in: CGRect(x: margin + 16, y: y + 32, width: contentWidth - 32, height: 18))
                            y += h + 8
                        }
                    }
                    
                    // Adherence
                    ensureSpace(40)
                    _ = drawText(
                        L("Adherence", chinese: chinese),
                        font: .systemFont(ofSize: 16, weight: .bold),
                        color: mint,
                        in: CGRect(x: margin, y: y, width: contentWidth, height: 22)
                    )
                    y += 28
                    
                    if !snapshot.summary.hasAdherenceHistory {
                        let emptyH: CGFloat = 48
                        ensureSpace(emptyH + 8)
                        drawRoundedRect(CGRect(x: margin, y: y, width: contentWidth, height: emptyH), fill: cardWhite)
                        _ = drawText(
                            L("No adherence history in this period.", chinese: chinese),
                            font: .systemFont(ofSize: 13, weight: .medium),
                            color: textSecondary,
                            in: CGRect(x: margin + 16, y: y + 14, width: contentWidth - 32, height: 22)
                        )
                        y += emptyH + 12
                    } else {
                        let totals = [
                            (L("Taken", chinese: chinese), "\(snapshot.summary.takenDoses)"),
                            (L("Skipped", chinese: chinese), "\(snapshot.summary.skippedDoses)"),
                            (L("Missed", chinese: chinese), "\(snapshot.summary.missedDoses)"),
                            (L("Adherence", chinese: chinese), "\(snapshot.summary.adherencePercent)%")
                        ]
                        let statsH: CGFloat = 44 + CGFloat(totals.count) * 24
                        ensureSpace(statsH + 8)
                        drawRoundedRect(CGRect(x: margin, y: y, width: contentWidth, height: statsH), fill: cardWhite)
                        var rowY = y + 14
                        for (label, value) in totals {
                            _ = drawText(label, font: .systemFont(ofSize: 12, weight: .semibold), color: textSecondary, in: CGRect(x: margin + 16, y: rowY, width: 160, height: 18))
                            _ = drawText(value, font: .systemFont(ofSize: 13, weight: .bold), color: textPrimary, in: CGRect(x: margin + 180, y: rowY, width: contentWidth - 210, height: 18))
                            rowY += 24
                        }
                        y += statsH + 10
                        
                        for row in snapshot.summary.dayRows {
                            let dayText = dateFmt.string(from: row.date)
                            let counts = F("%lld taken · %lld skipped · %lld missed", chinese: chinese, row.taken, row.skipped, row.missed)
                            let h: CGFloat = 46
                            ensureSpace(h + 6)
                            drawRoundedRect(CGRect(x: margin, y: y, width: contentWidth, height: h), fill: cardWhite)
                            _ = drawText(dayText, font: .systemFont(ofSize: 12, weight: .bold), color: textPrimary, in: CGRect(x: margin + 16, y: y + 8, width: contentWidth - 32, height: 16))
                            if row.hasActivity {
                                _ = drawText(counts, font: .systemFont(ofSize: 11, weight: .medium), color: textSecondary, in: CGRect(x: margin + 16, y: y + 24, width: contentWidth - 32, height: 16))
                            } else {
                                _ = drawText(L("Not Recorded", chinese: chinese), font: .systemFont(ofSize: 11, weight: .medium), color: textSecondary, in: CGRect(x: margin + 16, y: y + 24, width: contentWidth - 32, height: 16))
                            }
                            y += h + 6
                        }
                    }
                    
                    // BP
                    ensureSpace(40)
                    _ = drawText(L("Blood Pressure", chinese: chinese), font: .systemFont(ofSize: 16, weight: .bold), color: mint, in: CGRect(x: margin, y: y, width: contentWidth, height: 22))
                    y += 28
                    if snapshot.summary.bpReadings.isEmpty {
                        let emptyH: CGFloat = 48
                        ensureSpace(emptyH + 8)
                        drawRoundedRect(CGRect(x: margin, y: y, width: contentWidth, height: emptyH), fill: cardWhite)
                        _ = drawText(L("No blood pressure recorded in this period.", chinese: chinese), font: .systemFont(ofSize: 13, weight: .medium), color: textSecondary, in: CGRect(x: margin + 16, y: y + 14, width: contentWidth - 32, height: 22))
                        y += emptyH + 12
                    } else {
                        var lines = [
                            "\(L("Readings", chinese: chinese)): \(snapshot.summary.bpReadings.count)"
                        ]
                        if let avg = snapshot.averageBPText {
                            lines.append("\(L("Average", chinese: chinese)): \(avg)")
                        }
                        let sys = snapshot.summary.bpReadings.map(\.systolic)
                        let dia = snapshot.summary.bpReadings.map(\.diastolic)
                        if let minS = sys.min(), let maxS = sys.max(), let minD = dia.min(), let maxD = dia.max() {
                            lines.append("\(L("Systolic Range", chinese: chinese)): \(minS)–\(maxS)")
                            lines.append("\(L("Diastolic Range", chinese: chinese)): \(minD)–\(maxD)")
                        }
                        let h = 20 + CGFloat(lines.count) * 22
                        ensureSpace(h + 8)
                        drawRoundedRect(CGRect(x: margin, y: y, width: contentWidth, height: h), fill: cardWhite)
                        var rowY = y + 12
                        for line in lines {
                            _ = drawText(line, font: .systemFont(ofSize: 12, weight: .medium), color: textPrimary, in: CGRect(x: margin + 16, y: rowY, width: contentWidth - 32, height: 18))
                            rowY += 22
                        }
                        y += h + 12
                    }
                    
                    // HR
                    ensureSpace(40)
                    _ = drawText(L("Heart Rate", chinese: chinese), font: .systemFont(ofSize: 16, weight: .bold), color: mint, in: CGRect(x: margin, y: y, width: contentWidth, height: 22))
                    y += 28
                    if snapshot.summary.hrReadings.isEmpty {
                        let emptyH: CGFloat = 48
                        ensureSpace(emptyH + 8)
                        drawRoundedRect(CGRect(x: margin, y: y, width: contentWidth, height: emptyH), fill: cardWhite)
                        _ = drawText(L("No heart rate recorded in this period.", chinese: chinese), font: .systemFont(ofSize: 13, weight: .medium), color: textSecondary, in: CGRect(x: margin + 16, y: y + 14, width: contentWidth - 32, height: 22))
                        y += emptyH + 12
                    } else {
                        var lines = ["\(L("Readings", chinese: chinese)): \(snapshot.summary.hrReadings.count)"]
                        if let avg = snapshot.averageHRText {
                            lines.append("\(L("Average", chinese: chinese)): \(avg)")
                        }
                        let h = 20 + CGFloat(lines.count) * 22
                        ensureSpace(h + 8)
                        drawRoundedRect(CGRect(x: margin, y: y, width: contentWidth, height: h), fill: cardWhite)
                        var rowY = y + 12
                        for line in lines {
                            _ = drawText(line, font: .systemFont(ofSize: 12, weight: .medium), color: textPrimary, in: CGRect(x: margin + 16, y: rowY, width: contentWidth - 32, height: 18))
                            rowY += 22
                        }
                        y += h + 12
                    }
                    
                    // Mood
                    ensureSpace(40)
                    _ = drawText(L("Mood", chinese: chinese), font: .systemFont(ofSize: 16, weight: .bold), color: mint, in: CGRect(x: margin, y: y, width: contentWidth, height: 22))
                    y += 28
                    if snapshot.summary.moods.isEmpty {
                        let emptyH: CGFloat = 48
                        ensureSpace(emptyH + 8)
                        drawRoundedRect(CGRect(x: margin, y: y, width: contentWidth, height: emptyH), fill: cardWhite)
                        _ = drawText(L("No mood recorded in this period.", chinese: chinese), font: .systemFont(ofSize: 13, weight: .medium), color: textSecondary, in: CGRect(x: margin + 16, y: y + 14, width: contentWidth - 32, height: 22))
                        y += emptyH + 12
                    } else {
                        let moodName: String
                        if let mood = snapshot.mostCommonMood {
                            moodName = "\(mood.emoji) \(L(mood.rawValue, chinese: chinese))"
                        } else {
                            moodName = snapshot.summary.moods.last ?? "—"
                        }
                        let h: CGFloat = 48
                        ensureSpace(h + 8)
                        drawRoundedRect(CGRect(x: margin, y: y, width: contentWidth, height: h), fill: cardWhite)
                        _ = drawText(
                            "\(L("Most Common", chinese: chinese)): \(moodName)",
                            font: .systemFont(ofSize: 13, weight: .medium),
                            color: textPrimary,
                            in: CGRect(x: margin + 16, y: y + 14, width: contentWidth - 32, height: 22)
                        )
                        y += h + 12
                    }
                    
                    ensureSpace(36)
                    _ = drawText(
                        "\(AppLocalization.string("PillPal", chinese: chinese)) · \(stampFmt.string(from: snapshot.generatedAt)) · \(L("On this device only", chinese: chinese))",
                        font: .systemFont(ofSize: 10, weight: .medium),
                        color: textSecondary,
                        in: CGRect(x: margin, y: y, width: contentWidth, height: 16),
                        alignment: .center
                    )
                    y += 24
                }
                
                beginPage()
                drawLanguageBlock(chinese: false)
                ensureSpace(40)
                y += 8
                drawLanguageBlock(chinese: true)
            }
            return url
        } catch {
            print("Visit pack PDF failed: \(error)")
            return nil
        }
    }
}
