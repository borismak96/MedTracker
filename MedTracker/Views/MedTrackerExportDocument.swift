import UIKit
import SwiftUI

enum MedTrackerExportDocument {
    
    /// Same icon style as SplashView / loading page.
    @MainActor
    private static func splashIconImage(size: CGFloat = 120) -> UIImage? {
        let icon = ZStack {
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: size * 1.15, height: size * 1.15)
            
            Circle()
                .fill(Color.white)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
            
            Image(systemName: "pills.fill")
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundColor(.mint)
        }
        .frame(width: size * 1.2, height: size * 1.2)
        
        let renderer = ImageRenderer(content: icon)
        renderer.scale = 3
        return renderer.uiImage
    }
    
    @MainActor
    static func makePDF(profile: UserProfile, logs: [MedicationLog]) -> URL? {
        let pageWidth: CGFloat = 612   // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 36
        let contentWidth = pageWidth - margin * 2
        
        let mint = UIColor(red: 0.0, green: 0.78, blue: 0.75, alpha: 1.0)
        let mintSoft = UIColor(red: 0.85, green: 0.97, blue: 0.95, alpha: 1.0)
        let cardWhite = UIColor.white
        let textPrimary = UIColor(white: 0.15, alpha: 1)
        let textSecondary = UIColor(white: 0.45, alpha: 1)
        let splashIcon = splashIconImage(size: 100)
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = AppLocalization.locale
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.locale = AppLocalization.locale
        timeFormatter.dateStyle = .medium
        timeFormatter.timeStyle = .short
        
        let fileName = "PillPal_Export_\(dateFormatter.string(from: Date())).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        do {
            try renderer.writePDF(to: url) { context in
                var y: CGFloat = 0
                
                func beginPage() {
                    context.beginPage()
                    // Soft mint background wash
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
                    if y + needed > pageHeight - margin {
                        beginPage()
                    }
                }
                
                func drawRoundedRect(_ rect: CGRect, fill: UIColor, shadow: Bool = true) {
                    let path = UIBezierPath(roundedRect: rect, cornerRadius: 18)
                    if shadow {
                        context.cgContext.setShadow(offset: CGSize(width: 0, height: 4), blur: 10, color: UIColor.black.withAlphaComponent(0.06).cgColor)
                    }
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
                    let size = ns.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
                    ns.draw(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: ceil(size.height)), withAttributes: attrs)
                    return ceil(size.height)
                }
                
                beginPage()
                
                // Header card
                let headerHeight: CGFloat = 110
                ensureSpace(headerHeight + 20)
                let headerRect = CGRect(x: margin, y: y, width: contentWidth, height: headerHeight)
                drawRoundedRect(headerRect, fill: mint, shadow: true)
                
                // Same loading / splash icon
                let iconSize: CGFloat = 64
                let iconRect = CGRect(x: margin + 18, y: y + 23, width: iconSize, height: iconSize)
                if let splashIcon {
                    splashIcon.draw(in: iconRect)
                } else {
                    context.cgContext.setFillColor(UIColor.white.cgColor)
                    context.cgContext.fillEllipse(in: iconRect.insetBy(dx: 4, dy: 4))
                    let pillConfig = UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
                    if let pill = UIImage(systemName: "pills.fill", withConfiguration: pillConfig)?.withTintColor(mint, renderingMode: .alwaysOriginal) {
                        pill.draw(in: CGRect(x: iconRect.midX - 14, y: iconRect.midY - 14, width: 28, height: 28))
                    }
                }
                
                _ = drawText(
                    AppBrand.displayName,
                    font: .systemFont(ofSize: 26, weight: .heavy),
                    color: .white,
                    in: CGRect(x: margin + 90, y: y + 28, width: contentWidth - 110, height: 34)
                )
                _ = drawText(
                    AppLocalization.string("Data Export Report"),
                    font: .systemFont(ofSize: 14, weight: .semibold),
                    color: UIColor.white.withAlphaComponent(0.9),
                    in: CGRect(x: margin + 90, y: y + 62, width: contentWidth - 110, height: 22)
                )
                y += headerHeight + 18
                
                // Profile card
                let ageText: String = {
                    if profile.ageRange.isEmpty { return AppLocalization.string("Not selected") }
                    if let range = AgeRange(rawValue: profile.ageRange) { return range.localizedName }
                    return profile.ageRange
                }()
                let nameText = profile.name.isEmpty ? AppLocalization.string("Name Not Set") : profile.name
                let profileLines = [
                    (AppLocalization.string("Name"), nameText),
                    (AppLocalization.string("Age Range"), ageText),
                    (AppLocalization.string("Reminder Times"), profile.targetTimeDescription),
                    (AppLocalization.string("Exported At"), timeFormatter.string(from: Date()))
                ]
                let profileCardHeight: CGFloat = 48 + CGFloat(profileLines.count) * 28
                ensureSpace(profileCardHeight + 16)
                drawRoundedRect(CGRect(x: margin, y: y, width: contentWidth, height: profileCardHeight), fill: cardWhite)
                _ = drawText(
                    AppLocalization.string("Personal Info"),
                    font: .systemFont(ofSize: 16, weight: .bold),
                    color: mint,
                    in: CGRect(x: margin + 20, y: y + 16, width: contentWidth - 40, height: 22)
                )
                var rowY = y + 44
                for (label, value) in profileLines {
                    _ = drawText(label, font: .systemFont(ofSize: 12, weight: .semibold), color: textSecondary, in: CGRect(x: margin + 20, y: rowY, width: 120, height: 20))
                    _ = drawText(value, font: .systemFont(ofSize: 13, weight: .bold), color: textPrimary, in: CGRect(x: margin + 140, y: rowY, width: contentWidth - 160, height: 20))
                    rowY += 28
                }
                y += profileCardHeight + 14
                
                // Medications card — only when user has added medications
                let meds = profile.medications.filter { !$0.name.isEmpty }
                if !meds.isEmpty {
                    let medsHeight: CGFloat = 48 + CGFloat(meds.count) * 30
                    ensureSpace(medsHeight + 16)
                    drawRoundedRect(CGRect(x: margin, y: y, width: contentWidth, height: medsHeight), fill: cardWhite)
                    _ = drawText(
                        AppLocalization.string("Medications"),
                        font: .systemFont(ofSize: 16, weight: .bold),
                        color: mint,
                        in: CGRect(x: margin + 20, y: y + 16, width: contentWidth - 40, height: 22)
                    )
                    rowY = y + 44
                    for med in meds {
                        _ = drawText(med.name, font: .systemFont(ofSize: 13, weight: .semibold), color: textPrimary, in: CGRect(x: margin + 20, y: rowY, width: contentWidth - 100, height: 20))
                        // dose pill
                        let doseText = med.dose as NSString
                        let doseFont = UIFont.systemFont(ofSize: 12, weight: .bold)
                        let doseSize = doseText.size(withAttributes: [.font: doseFont])
                        let doseRect = CGRect(x: margin + contentWidth - 40 - doseSize.width - 16, y: rowY - 2, width: doseSize.width + 16, height: 22)
                        let dosePath = UIBezierPath(roundedRect: doseRect, cornerRadius: 8)
                        mintSoft.setFill()
                        dosePath.fill()
                        doseText.draw(in: CGRect(x: doseRect.minX + 8, y: doseRect.minY + 3, width: doseSize.width, height: 16), withAttributes: [.font: doseFont, .foregroundColor: mint])
                        rowY += 30
                    }
                    y += medsHeight + 14
                }
                
                // Blood pressure — only when readings exist
                let bpReadings = logs
                    .flatMap { $0.allBPReadingsForExport() }
                    .sorted { $0.recordedAt > $1.recordedAt }
                if !bpReadings.isEmpty {
                    ensureSpace(40)
                    _ = drawText(
                        AppLocalization.string("Blood Pressure"),
                        font: .systemFont(ofSize: 18, weight: .heavy),
                        color: textPrimary,
                        in: CGRect(x: margin, y: y, width: contentWidth, height: 28)
                    )
                    y += 34
                    
                    let sysValues = bpReadings.map(\.systolic)
                    let diaValues = bpReadings.map(\.diastolic)
                    let avgSys = sysValues.reduce(0, +) / sysValues.count
                    let avgDia = diaValues.reduce(0, +) / diaValues.count
                    let minSys = sysValues.min() ?? 0
                    let maxSys = sysValues.max() ?? 0
                    let minDia = diaValues.min() ?? 0
                    let maxDia = diaValues.max() ?? 0
                    
                    let statsLines = [
                        (AppLocalization.string("Readings"), "\(bpReadings.count)"),
                        (AppLocalization.string("Average"), "\(avgSys) / \(avgDia) mmHg"),
                        (AppLocalization.string("Systolic Range"), "\(minSys)–\(maxSys)"),
                        (AppLocalization.string("Diastolic Range"), "\(minDia)–\(maxDia)")
                    ]
                    let statsHeight: CGFloat = 48 + CGFloat(statsLines.count) * 28
                    ensureSpace(statsHeight + 16)
                    drawRoundedRect(CGRect(x: margin, y: y, width: contentWidth, height: statsHeight), fill: cardWhite)
                    _ = drawText(
                        AppLocalization.string("BP Statistics"),
                        font: .systemFont(ofSize: 16, weight: .bold),
                        color: mint,
                        in: CGRect(x: margin + 20, y: y + 16, width: contentWidth - 40, height: 22)
                    )
                    rowY = y + 44
                    for (label, value) in statsLines {
                        _ = drawText(label, font: .systemFont(ofSize: 12, weight: .semibold), color: textSecondary, in: CGRect(x: margin + 20, y: rowY, width: 140, height: 20))
                        _ = drawText(value, font: .systemFont(ofSize: 13, weight: .bold), color: textPrimary, in: CGRect(x: margin + 160, y: rowY, width: contentWidth - 180, height: 20))
                        rowY += 28
                    }
                    y += statsHeight + 14
                    
                    ensureSpace(30)
                    _ = drawText(
                        AppLocalization.string("BP History"),
                        font: .systemFont(ofSize: 16, weight: .bold),
                        color: mint,
                        in: CGRect(x: margin, y: y, width: contentWidth, height: 22)
                    )
                    y += 28
                    
                    let bpTimeFormatter = DateFormatter()
                    bpTimeFormatter.locale = AppLocalization.locale
                    bpTimeFormatter.dateStyle = .medium
                    bpTimeFormatter.timeStyle = .short
                    
                    for reading in bpReadings {
                        let category = reading.category
                        let dateText = bpTimeFormatter.string(from: reading.recordedAt)
                        let valueText = "\(reading.valueDescription) · \(category.localizedTitle)"
                        let adviceText = category.localizedAdvice
                        
                        let innerWidth = contentWidth - 40
                        let dateFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
                        let valueFont = UIFont.systemFont(ofSize: 14, weight: .bold)
                        let adviceFont = UIFont.systemFont(ofSize: 12, weight: .medium)
                        
                        let dateH = ceil((dateText as NSString).boundingRect(
                            with: CGSize(width: innerWidth, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: [.font: dateFont],
                            context: nil
                        ).height)
                        let valueH = ceil((valueText as NSString).boundingRect(
                            with: CGSize(width: innerWidth, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: [.font: valueFont],
                            context: nil
                        ).height)
                        let adviceH = ceil((adviceText as NSString).boundingRect(
                            with: CGSize(width: innerWidth, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: [.font: adviceFont],
                            context: nil
                        ).height)
                        
                        let cardH = 16 + dateH + 6 + valueH + 6 + adviceH + 16
                        ensureSpace(cardH + 10)
                        drawRoundedRect(CGRect(x: margin, y: y, width: contentWidth, height: cardH), fill: cardWhite)
                        
                        var textY = y + 16
                        _ = drawText(
                            dateText,
                            font: dateFont,
                            color: textSecondary,
                            in: CGRect(x: margin + 20, y: textY, width: innerWidth, height: dateH + 2)
                        )
                        textY += dateH + 6
                        
                        _ = drawText(
                            valueText,
                            font: valueFont,
                            color: UIColor.systemRed,
                            in: CGRect(x: margin + 20, y: textY, width: innerWidth, height: valueH + 2)
                        )
                        textY += valueH + 6
                        
                        _ = drawText(
                            adviceText,
                            font: adviceFont,
                            color: textSecondary,
                            in: CGRect(x: margin + 20, y: textY, width: innerWidth, height: adviceH + 4)
                        )
                        
                        y += cardH + 10
                    }
                    y += 6
                }
                
                // History — only days with actual recorded data
                func logHasRecordedData(_ log: MedicationLog) -> Bool {
                    if log.isTaken || log.skippedTime != nil { return true }
                    if log.doseRecords.contains(where: { $0.isTaken || $0.isSkipped }) { return true }
                    if let mood = log.mood, !mood.isEmpty { return true }
                    if let notes = log.notes, !notes.isEmpty { return true }
                    if let medicine = log.medicineName, !medicine.isEmpty { return true }
                    if !log.allBPReadingsForExport().isEmpty { return true }
                    return false
                }
                
                let recordedLogs = logs.filter(logHasRecordedData)
                if !recordedLogs.isEmpty {
                    ensureSpace(40)
                    _ = drawText(
                        AppLocalization.string("History"),
                        font: .systemFont(ofSize: 18, weight: .heavy),
                        color: textPrimary,
                        in: CGRect(x: margin, y: y, width: contentWidth, height: 28)
                    )
                    y += 34
                    
                    for log in recordedLogs {
                        let medicine = (log.medicineName ?? "").replacingOccurrences(of: "\n", with: ", ")
                        let dose = (log.dose ?? "").replacingOccurrences(of: "\n", with: ", ")
                        let status: String
                        let statusColor: UIColor
                        if log.isTaken || log.doseRecords.contains(where: \.isTaken) {
                            status = AppLocalization.string("Taken")
                            statusColor = UIColor.systemGreen
                        } else if log.skippedTime != nil || log.doseRecords.contains(where: \.isSkipped) {
                            status = AppLocalization.string("Skipped")
                            statusColor = UIColor.systemRed
                        } else {
                            status = AppLocalization.string("Recorded")
                            statusColor = mint
                        }
                        
                        var details: [String] = []
                        if let mood = log.mood, !mood.isEmpty { details.append("\(AppLocalization.string("Mood: "))\(mood)") }
                        if !medicine.isEmpty { details.append("\(medicine)\(dose.isEmpty ? "" : " · \(dose)")") }
                        let dayBP = log.allBPReadingsForExport()
                        if !dayBP.isEmpty {
                            let bpText = dayBP.map { "\($0.timeDescription) \($0.valueDescription)" }.joined(separator: " · ")
                            details.append(bpText)
                        }
                        if let notes = log.notes, !notes.isEmpty {
                            details.append("\(AppLocalization.string("Remark:")) \(notes)")
                        }
                        
                        let detailText = details.joined(separator: "\n")
                        let detailHeight = detailText.isEmpty ? 0 : (detailText as NSString).boundingRect(
                            with: CGSize(width: contentWidth - 40, height: .greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: [.font: UIFont.systemFont(ofSize: 12, weight: .medium)],
                            context: nil
                        ).height
                        
                        let cardH = 56 + ceil(detailHeight) + (detailText.isEmpty ? 0 : 8)
                        ensureSpace(cardH + 12)
                        drawRoundedRect(CGRect(x: margin, y: y, width: contentWidth, height: cardH), fill: cardWhite)
                        
                        _ = drawText(
                            dateFormatter.string(from: log.date),
                            font: .systemFont(ofSize: 14, weight: .bold),
                            color: textPrimary,
                            in: CGRect(x: margin + 20, y: y + 14, width: contentWidth - 140, height: 20)
                        )
                        
                        // status chip
                        let statusAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11, weight: .bold)]
                        let statusSize = (status as NSString).size(withAttributes: statusAttrs)
                        let chipRect = CGRect(x: margin + contentWidth - 20 - statusSize.width - 16, y: y + 12, width: statusSize.width + 16, height: 22)
                        let chipPath = UIBezierPath(roundedRect: chipRect, cornerRadius: 11)
                        statusColor.withAlphaComponent(0.15).setFill()
                        chipPath.fill()
                        (status as NSString).draw(in: CGRect(x: chipRect.minX + 8, y: chipRect.minY + 4, width: statusSize.width, height: 14), withAttributes: [
                            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                            .foregroundColor: statusColor
                        ])
                        
                        if !detailText.isEmpty {
                            _ = drawText(
                                detailText,
                                font: .systemFont(ofSize: 12, weight: .medium),
                                color: textSecondary,
                                in: CGRect(x: margin + 20, y: y + 40, width: contentWidth - 40, height: ceil(detailHeight) + 4)
                            )
                        }
                        
                        y += cardH + 10
                    }
                }
                
                // Footer
                ensureSpace(40)
                _ = drawText(
                    "\(AppBrand.displayName) · \(AppLocalization.string("Information for Reference Only"))",
                    font: .systemFont(ofSize: 10, weight: .medium),
                    color: textSecondary,
                    in: CGRect(x: margin, y: pageHeight - margin - 16, width: contentWidth, height: 16),
                    alignment: .center
                )
            }
            return url
        } catch {
            print("PDF export failed: \(error)")
            return nil
        }
    }
}
