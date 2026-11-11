import Foundation

enum Parameter: String, Codable, CaseIterable, Identifiable {
    case temperatureC, ph, gh, kh, tds, ammonia, nitrite, nitrate, chlorine, salinity
    var id: String { rawValue }
    var name: String {
        switch self {
        case .temperatureC: "Temperature"
        case .ph: "pH"
        case .gh: "GH"
        case .kh: "KH"
        case .tds: "TDS"
        case .ammonia: "Ammonia"
        case .nitrite: "Nitrite"
        case .nitrate: "Nitrate"
        case .chlorine: "Chlorine"
        case .salinity: "Salinity"
        }
    }
    var unit: String {
        switch self {
        case .temperatureC: "°C"
        case .ph: ""
        case .gh, .kh: "dH"
        case .tds, .ammonia, .nitrite, .nitrate, .chlorine: "ppm"
        case .salinity: "ppt"
        }
    }
}

struct WaterReading: Codable, Identifiable {
    var id: UUID = UUID()
    var parameter: Parameter
    var value: Double
    var recordedAt: Date
}

enum WaterType: String, Codable, CaseIterable, Identifiable {
    case freshwater, brackish, marine, pond
    var id: String { rawValue }
}

struct Aquarium: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var volumeGallons: Double
    var waterType: WaterType
    var cycled: Bool
    var readings: [WaterReading] = []
    var latest: [Parameter: WaterReading] {
        Dictionary(grouping: readings, by: \.parameter)
            .compactMapValues { $0.max(by: { $0.recordedAt < $1.recordedAt }) }
    }
}

struct CareRange: Codable {
    var minimum: Double
    var maximum: Double
    // Preferred range is an explicitly sourced target, not inferred automatically.
    var preferredMinimum: Double?
    var preferredMaximum: Double?
}

struct AnimalProfile: Codable, Identifiable {
    var id: String
    var commonName: String
    var scientificName: String
    var group: String
    var waterType: WaterType
    var ranges: [Parameter: CareRange]
    var minimumGallons: Double?
    var minimumGroup: Int?
    var referenceVerified: Bool
}

struct ParameterAssessment: Identifiable {
    var id: Parameter { parameter }
    let parameter: Parameter
    let value: Double
    let range: CareRange
    let score: Double
    let stale: Bool
}

struct FitReport {
    let score: Int?
    let status: String
    let blocked: Bool
    let provisional: Bool
    let assessments: [ParameterAssessment]
    let missing: [String]
    let warnings: [String]
    let measuredCoverage: Int
}
