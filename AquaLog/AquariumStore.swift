import Foundation

@MainActor
final class AquariumStore: ObservableObject {
    @Published var tanks: [Aquarium] = [] {
        didSet { save() }
    }
    private let storageKey = "aqualog.tanks.v1"

    init() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let restored = try? JSONDecoder().decode([Aquarium].self, from: data)
        else { return }
        tanks = restored
    }

    func createTank(name: String, gallons: Double, waterType: WaterType) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty, gallons > 0 else { return }
        tanks.append(Aquarium(name: name, volumeGallons: gallons,
                              waterType: waterType, cycled: false))
    }

    func addReading(to tankID: UUID, parameter: Parameter, value: Double) {
        guard value.isFinite, let index = tanks.firstIndex(where: { $0.id == tankID }) else { return }
        tanks[index].readings.append(WaterReading(parameter: parameter, value: value,
                                                   recordedAt: Date()))
    }

    func setCycled(_ cycled: Bool, tankID: UUID) {
        guard let index = tanks.firstIndex(where: { $0.id == tankID }) else { return }
        tanks[index].cycled = cycled
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(tanks) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
