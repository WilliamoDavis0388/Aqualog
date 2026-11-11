import Foundation

enum FitScoreEngine {
    private static let weights: [Parameter: Double] = [
        .temperatureC: 28, .ph: 22, .gh: 15, .kh: 12, .tds: 3, .salinity: 20
    ]
    private static let critical: [Parameter] = [.ammonia, .nitrite, .chlorine]

    static func evaluate(_ animal: AnimalProfile, in tank: Aquarium, now: Date = Date()) -> FitReport {
        var warnings: [String] = []
        var missing: [String] = []
        var assessments: [ParameterAssessment] = []
        var weighted = 0.0
        var denominator = 0.0
        var totalExpected = 0.0
        var cap: Double = 100
        let latest = tank.latest

        for (parameter, weight) in weights {
            guard let range = animal.ranges[parameter] else { continue }
            totalExpected += weight
            guard let reading = latest[parameter] else {
                missing.append(parameter.name)
                continue
            }
            let age = now.timeIntervalSince(reading.recordedAt)
            let stale = age > 7 * 86400 || age < -300
            let points = match(reading.value, range: range)
            weighted += points * weight
            denominator += weight
            assessments.append(ParameterAssessment(parameter: parameter,
                value: reading.value, range: range, score: points, stale: stale))
            if stale { warnings.append("Old or future-dated \(parameter.name) test") }
            if points < 75 {
                cap = min(cap, points < 35 ? 35 : 65)
                warnings.append("\(parameter.name) is outside the care range")
            }
        }

        for parameter in critical {
            guard let reading = latest[parameter] else {
                missing.append(parameter.name)
                continue
            }
            let age = now.timeIntervalSince(reading.recordedAt)
            if age > 2 * 86400 || age < -300 {
                warnings.append("\(parameter.name) test is stale")
            }
            if reading.value > 0 {
                if parameter == .chlorine { cap = 0 }
                else { cap = min(cap, reading.value >= 0.25 ? 20 : 39) }
                warnings.append("Detectable \(parameter.name); investigate before adding animals")
            }
        }

        if let nitrate = latest[.nitrate] {
            let age = now.timeIntervalSince(nitrate.recordedAt)
            if age > 7 * 86400 || age < -300 { warnings.append("Nitrate test is stale") }
            if nitrate.value > 40 { cap = min(cap, 45); warnings.append("Nitrate exceeds 40 ppm") }
            else if nitrate.value > 20 { cap = min(cap, 75); warnings.append("Nitrate above preferred baseline") }
        } else { missing.append("Nitrate") }

        if let minVolume = animal.minimumGallons, tank.volumeGallons < minVolume {
            cap = min(cap, 35)
            warnings.append("Tank is smaller than the recorded minimum")
        }
        if tank.waterType != animal.waterType {
            cap = 0
            warnings.append("Incompatible freshwater, brackish, marine, or pond designation")
        }
        if !tank.cycled {
            cap = 0
            warnings.append("Tank has not been marked cycled")
        }
        let necessary: [Parameter] = animal.group == "Shrimp" || animal.group == "Aquatic snail"
            ? [.temperatureC, .ph, .gh, .kh] : [.temperatureC, .ph]
        for parameter in necessary where latest[parameter] == nil {
            if !missing.contains(parameter.name) { missing.append(parameter.name) }
        }
        if animal.waterType == .brackish || animal.waterType == .marine {
            if latest[.salinity] == nil { missing.append("Salinity") }
        }
        if animal.minimumGroup != nil {
            warnings.append("Check required group size against planned tank inhabitants")
        }
        warnings.append("Tankmate predation, oxygen, diet and swimming space require separate review")
        if !animal.referenceVerified {
            warnings.append("Species care range has not been independently verified")
        }

        let numeric: Int? = denominator > 0 ? Int(min(cap, weighted / denominator).rounded()) : nil
        let provisional = !missing.isEmpty || !animal.referenceVerified ||
            !warnings.filter { $0.contains("stale") || $0.contains("future-dated") }.isEmpty
        let blocked = cap == 0
        let status: String
        if blocked { status = "Do not add" }
        else if numeric == nil { status = "Insufficient data" }
        else if provisional { status = "Provisional" }
        else if numeric! >= 90 { status = "Excellent" }
        else if numeric! >= 75 { status = "Good" }
        else if numeric! >= 60 { status = "Caution" }
        else { status = "Not recommended" }
        return FitReport(score: numeric, status: status, blocked: blocked,
            provisional: provisional, assessments: assessments.sorted { $0.parameter.rawValue < $1.parameter.rawValue },
            missing: missing, warnings: warnings,
            measuredCoverage: totalExpected > 0 ? Int((100 * denominator / totalExpected).rounded()) : 0)
    }

    private static func match(_ value: Double, range: CareRange) -> Double {
        guard range.minimum <= range.maximum else { return 0 }
        let width = max(0.1, range.maximum - range.minimum)
        let lower = range.preferredMinimum ?? range.minimum + width * 0.25
        let upper = range.preferredMaximum ?? range.maximum - width * 0.25
        if value >= lower && value <= upper { return 100 }
        if value >= range.minimum && value <= range.maximum {
            let fraction = value < lower
                ? (value - range.minimum) / max(0.001, lower - range.minimum)
                : (range.maximum - value) / max(0.001, range.maximum - upper)
            return 82 + 18 * max(0, min(1, fraction))
        }
        let distance = value < range.minimum ? range.minimum - value : value - range.maximum
        return max(0, 65 - 65 * distance / max(0.1, width * 0.5))
    }
}
