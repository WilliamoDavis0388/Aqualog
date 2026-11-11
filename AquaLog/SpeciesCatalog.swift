import Foundation

enum SpeciesCatalog {
    // Sample species profiles, not a complete or verified production reference database.
    static let all: [AnimalProfile] = {
        guard let url = Bundle.main.url(forResource: "starter_species", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let profiles = try? JSONDecoder().decode([AnimalProfile].self, from: data)
        else { return [] }
        return profiles
    }()
}
