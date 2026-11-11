import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AquariumStore
    @State private var selectedTankID: UUID?
    @State private var showNewTank = false

    var body: some View {
        NavigationStack {
            List {
                Section("My Aquariums") {
                    ForEach(store.tanks) { tank in
                        NavigationLink {
                            TankDetailView(tankID: tank.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tank.name).font(.headline)
                                    Text("\(tank.volumeGallons.formatted()) gal • \(tank.waterType.rawValue.capitalized)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "drop.fill").foregroundStyle(.cyan)
                            }
                        }
                    }
                    if store.tanks.isEmpty {
                        ContentUnavailableView("Add your first tank",
                            systemImage: "water.waves",
                            description: Text("Create an aquarium, record tests, then check animal compatibility."))
                    }
                }
            }
            .navigationTitle("AquaLog")
            .toolbar {
                Button("Add tank", systemImage: "plus") { showNewTank = true }
            }
            .sheet(isPresented: $showNewTank) { NewTankView() }
        }
    }
}

struct NewTankView: View {
    @EnvironmentObject private var store: AquariumStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var gallons = "10"
    @State private var waterType: WaterType = .freshwater
    var body: some View {
        NavigationStack {
            Form {
                TextField("Tank name", text: $name)
                TextField("Volume in gallons", text: $gallons)
                Picker("Water type", selection: $waterType) {
                    ForEach(WaterType.allCases) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }
            }
            .navigationTitle("New aquarium")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let size = Double(gallons), size > 0 {
                            store.createTank(name: name, gallons: size, waterType: waterType)
                            dismiss()
                        }
                    }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                               (Double(gallons) ?? 0) <= 0)
                }
            }
        }
    }
}

struct TankDetailView: View {
    @EnvironmentObject private var store: AquariumStore
    let tankID: UUID
    @State private var selectedParameter: Parameter = .temperatureC
    @State private var readingInput = ""
    private var tank: Aquarium? { store.tanks.first(where: { $0.id == tankID }) }

    var body: some View {
        Group {
            if let tank {
                Form {
                    Section("Tank status") {
                        LabeledContent("Volume", value: "\(tank.volumeGallons.formatted()) gal")
                        LabeledContent("Water", value: tank.waterType.rawValue.capitalized)
                        Toggle("Biological cycle confirmed", isOn: Binding(
                            get: { tank.cycled },
                            set: { store.setCycled($0, tankID: tankID) }))
                    }
                    Section("Record a water test") {
                        Picker("Parameter", selection: $selectedParameter) {
                            ForEach(Parameter.allCases) { parameter in
                                Text("\(parameter.name) \(parameter.unit)").tag(parameter)
                            }
                        }
                        TextField("Measured value", text: $readingInput)
                                Button("Save reading") {
                            if let value = Double(readingInput), value >= 0 {
                                store.addReading(to: tankID, parameter: selectedParameter, value: value)
                                readingInput = ""
                            }
                        }.disabled(Double(readingInput) == nil || (Double(readingInput) ?? -1) < 0)
                    }
                    Section("Most recent readings") {
                        ForEach(Parameter.allCases) { parameter in
                            if let reading = tank.latest[parameter] {
                                LabeledContent(parameter.name, value:
                                    "\(reading.value.formatted()) \(parameter.unit)")
                            }
                        }
                    }
                    Section("Compatibility") {
                        NavigationLink {
                            AnimalFitView(tankID: tankID)
                        } label: {
                            Label("Check animal Fit Score", systemImage: "checkmark.shield")
                        }
                    }
                    Section {
                        Text("Tests are stored locally on this device in this starter build. No cloud account or syncing is configured.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .navigationTitle(tank.name)
            } else {
                ContentUnavailableView("Tank not found", systemImage: "exclamationmark.triangle")
            }
        }
    }
}

struct AnimalFitView: View {
    @EnvironmentObject private var store: AquariumStore
    let tankID: UUID
    @State private var search = ""
    @State private var selectedID: String?
    private var tank: Aquarium? { store.tanks.first(where: { $0.id == tankID }) }
    private var matches: [AnimalProfile] {
        SpeciesCatalog.all.filter { search.isEmpty ||
            $0.commonName.localizedCaseInsensitiveContains(search) ||
            $0.scientificName.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        List {
            Section {
                TextField("Search animals", text: $search)
                if SpeciesCatalog.all.isEmpty {
                    Text("No species loaded")
                } else {
                    Picker("Animal", selection: $selectedID) {
                        Text("Select animal").tag(String?.none)
                        ForEach(matches) { animal in
                            Text(animal.commonName).tag(Optional(animal.id))
                        }
                    }
                }
            } header: { Text("Species") }
            if let tank, let animal = SpeciesCatalog.all.first(where: { $0.id == selectedID }) {
                let report = FitScoreEngine.evaluate(animal, in: tank)
                Section("Fit assessment") {
                    HStack {
                        Text(report.score.map { "\($0)/100" } ?? "N/A")
                            .font(.largeTitle).bold()
                        Spacer()
                        Text(report.status).font(.headline)
                    }
                    LabeledContent("Measured range coverage", value: "\(report.measuredCoverage)%")
                    if report.provisional {
                        Text("Provisional: missing, stale, or unverified reference data.")
                            .foregroundStyle(.orange)
                    }
                    if report.blocked {
                        Label("Do not add this animal", systemImage: "hand.raised.fill")
                            .foregroundStyle(.red)
                    }
                }
                Section("Parameter assessment") {
                    ForEach(report.assessments) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.parameter.name)
                                Spacer()
                                Text("\(Int(item.score.rounded()))/100")
                                    .foregroundStyle(item.score >= 82 ? .green : .orange)
                            }
                            Text("Measured \(item.value.formatted()) \(item.parameter.unit); reference \(item.range.minimum.formatted())–\(item.range.maximum.formatted())")
                                .font(.caption).foregroundStyle(.secondary)
                            if item.stale {
                                Text("Stale reading").font(.caption).foregroundStyle(.orange)
                            }
                        }
                    }
                }
                if !report.missing.isEmpty {
                    Section("Missing information") {
                        ForEach(report.missing, id: \.self) { Text($0) }
                    }
                }
                if !report.warnings.isEmpty {
                    Section("Warnings and follow-up checks") {
                        ForEach(report.warnings, id: \.self) { Text($0) }
                    }
                }
                Section {
                    Text("The score is advisory, not a stocking authorization. Adult size, tankmates, food, oxygenation, group size and habitat need individual review. The example species ranges are not yet validated for production.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Animal Fit Score")
    }
}
