import SwiftUI

struct ItemFormView: View {
    @ObservedObject var appData: AppData
    let cycleId: UUID
    let initialCategory: Category?
    let editingItem: Item?
    
    @State private var itemName: String = ""
    @State private var dose: String = ""
    @State private var selectedUnit: Unit?
    @State private var selectedCategory: Category
    @State private var inputMode: InputMode = .decimal
    @State private var selectedFraction: Fraction?
    @State private var addFutureDoses: Bool = false
    @State private var weeklyDoses: [Int: (dose: String, unit: Unit?, fraction: Fraction?)] = [:]
    @State private var showingDeleteConfirmation = false
    
    @Environment(\.dismiss) var dismiss
    
    enum InputMode: String, CaseIterable {
        case decimal = "Decimal"
        case fraction = "Fraction"
    }
    
    init(appData: AppData, cycleId: UUID, initialCategory: Category? = nil, editingItem: Item? = nil) {
        self.appData = appData
        self.cycleId = cycleId
        self.initialCategory = initialCategory
        self.editingItem = editingItem
        
        print("ItemFormView initialized with initialCategory: \(initialCategory?.rawValue ?? "nil"), editingItem: \(editingItem != nil ? editingItem!.name : "none")")
        
        if let item = editingItem {
            self._itemName = State(initialValue: item.name)
            self._selectedCategory = State(initialValue: item.category)
            self._dose = State(initialValue: item.dose.map { String($0) } ?? "")
            
            if let unitName = item.unit, !unitName.isEmpty {
                if let existingUnit = appData.units.first(where: { $0.name == unitName }) {
                    self._selectedUnit = State(initialValue: existingUnit)
                } else {
                    let newUnit = Unit(name: unitName)
                    appData.addUnit(newUnit)
                    self._selectedUnit = State(initialValue: newUnit)
                }
            } else {
                self._selectedUnit = State(initialValue: nil)
            }
            
            self._addFutureDoses = State(initialValue: item.weeklyDoses != nil)
            
            if let dose = item.dose, let fraction = Fraction.fractionForDecimal(dose) {
                self._inputMode = State(initialValue: .fraction)
                self._selectedFraction = State(initialValue: fraction)
            } else {
                self._inputMode = State(initialValue: .decimal)
                self._selectedFraction = State(initialValue: nil)
            }
            
            if let weeklyDoses = item.weeklyDoses {
                let processedWeeklyDoses = weeklyDoses.mapValues { dose -> (dose: String, unit: Unit?, fraction: Fraction?) in
                    let unit: Unit?
                    if let unitName = item.unit, !unitName.isEmpty {
                        if let existingUnit = appData.units.first(where: { $0.name == unitName }) {
                            unit = existingUnit
                        } else {
                            let newUnit = Unit(name: unitName)
                            appData.addUnit(newUnit)
                            unit = newUnit
                        }
                    } else {
                        unit = nil
                    }
                    
                    if let fraction = Fraction.fractionForDecimal(dose) {
                        return (dose: String(dose), unit: unit, fraction: fraction)
                    } else {
                        return (dose: String(dose), unit: unit, fraction: nil)
                    }
                }
                self._weeklyDoses = State(initialValue: processedWeeklyDoses)
            } else {
                self._weeklyDoses = State(initialValue: [:])
            }
            print("Editing item, selectedCategory set to: \(item.category.rawValue)")
        } else {
            // For new items, use initialCategory if provided; otherwise, default to .maintenance
            if initialCategory == nil {
                print("WARNING: initialCategory is nil, falling back to .maintenance")
            }
            let defaultCategory = initialCategory ?? .maintenance
            self._itemName = State(initialValue: "")
            self._selectedCategory = State(initialValue: defaultCategory)
            self._dose = State(initialValue: "")
            self._selectedUnit = State(initialValue: nil)
            self._selectedFraction = State(initialValue: nil)
            self._weeklyDoses = State(initialValue: [:])
            self._addFutureDoses = State(initialValue: false)
            print("New item, selectedCategory set to: \(defaultCategory.rawValue) (initialCategory was: \(initialCategory?.rawValue ?? "nil"))")
        }
    }
    
    private var currentWeek: Int {
        guard let cycle = appData.cycles.last else { return 1 }
        let daysSinceStart = Calendar.current.dateComponents([.day], from: cycle.startDate, to: Date()).day ?? 0
        return (daysSinceStart / 7) + 1
    }
    
    private var totalWeeks: Int {
        guard let cycle = appData.cycles.last else { return 12 }
        let calendar = Calendar.current
        guard let lastDosingDay = calendar.date(byAdding: .day, value: -1, to: cycle.foodChallengeDate) else { return 12 }
        let days = calendar.dateComponents([.day], from: cycle.startDate, to: lastDosingDay).day ?? 83
        return (days / 7) + 1
    }
    
    var body: some View {
        Form {
            Section(header: Text("Item Details")) {
                TextField("Item Name", text: $itemName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Section(header: Text("Category")) {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(Category.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            if selectedCategory == .treatment {
                Section {
                    Toggle("Add Future Week Doses", isOn: $addFutureDoses)
                        .onChange(of: addFutureDoses) { newValue in
                            weeklyDoses = [:]
                        }
                }
                
                Picker("Input Mode", selection: $inputMode) {
                    ForEach(InputMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                if addFutureDoses {
                    ForEach(currentWeek...totalWeeks, id: \.self) { week in
                        Section(header: Text("Week \(week)")) {
                            weeklyDoseRow(week: week)
                        }
                    }
                } else {
                    Section(header: Text("Single Dose for All Weeks")) {
                        dosageInputRow()
                    }
                }
            } else {
                Section(header: Text("Dose")) {
                    Picker("Input Mode", selection: $inputMode) {
                        ForEach(InputMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    dosageInputRow()
                }
            }
            
            if editingItem != nil {
                Section {
                    Button("Delete Item", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                    .alert("Delete \(itemName)?", isPresented: $showingDeleteConfirmation) {
                        Button("Cancel", role: .cancel) { }
                        Button("Delete", role: .destructive) {
                            if let itemId = editingItem?.id {
                                appData.removeItem(itemId, fromCycleId: cycleId)
                            }
                            dismiss()
                        }
                    } message: {
                        Text("This action cannot be undone.")
                    }
                }
            }
        }
        .navigationTitle(editingItem == nil ? "Add Item" : "Edit Item")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveItem()
                }
                .disabled(!isValid())
            }
        }
    }
    
    private func dosageInputRow() -> some View {
        Group {
            if inputMode == .decimal {
                HStack {
                    TextField("Dose", text: $dose)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Picker("Unit", selection: $selectedUnit) {
                        Text("Select Unit").tag(nil as Unit?)
                        ForEach(appData.units) { unit in
                            Text(unit.name).tag(Unit?.some(unit))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            } else {
                HStack {
                    Picker("Dose", selection: $selectedFraction) {
                        Text("Select fraction").tag(nil as Fraction?)
                        ForEach(Fraction.commonFractions) { fraction in
                            Text(fraction.displayString).tag(fraction as Fraction?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    Picker("Unit", selection: $selectedUnit) {
                        Text("Select Unit").tag(nil as Unit?)
                        ForEach(appData.units) { unit in
                            Text(unit.name).tag(Unit?.some(unit))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            NavigationLink(destination: AddUnitFromItemView(appData: appData, selectedUnit: $selectedUnit)) {
                Text("Add a Unit")
            }
        }
    }
    
    private func weeklyDoseRow(week: Int) -> some View {
        Group {
            if inputMode == .decimal {
                HStack {
                    TextField("Dose", text: Binding(
                        get: { weeklyDoses[week]?.dose ?? "" },
                        set: { newValue in
                            let filtered = newValue.filter { "0123456789.".contains($0) }
                            weeklyDoses[week, default: ("", nil, nil)].dose = filtered
                        }
                    ))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Picker("Unit", selection: Binding(
                        get: { weeklyDoses[week]?.unit },
                        set: { weeklyDoses[week, default: ("", nil, nil)].unit = $0 }
                    )) {
                        Text("Select Unit").tag(Unit?.none)
                        ForEach(appData.units) { unit in
                            Text(unit.name).tag(Unit?.some(unit))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            } else {
                HStack {
                    Picker("Dose", selection: Binding(
                        get: { weeklyDoses[week]?.fraction },
                        set: { weeklyDoses[week, default: ("", nil, nil)].fraction = $0 }
                    )) {
                        Text("Select fraction").tag(nil as Fraction?)
                        ForEach(Fraction.commonFractions) { fraction in
                            Text(fraction.displayString).tag(fraction as Fraction?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Picker("Unit", selection: Binding(
                        get: { weeklyDoses[week]?.unit },
                        set: { weeklyDoses[week, default: ("", nil, nil)].unit = $0 }
                    )) {
                        Text("Select Unit").tag(Unit?.none)
                        ForEach(appData.units) { unit in
                            Text(unit.name).tag(Unit?.some(unit))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            NavigationLink(destination: AddUnitFromTreatmentView(appData: appData, selectedUnit: Binding(
                get: { weeklyDoses[week]?.unit },
                set: { weeklyDoses[week, default: ("", nil, nil)].unit = $0 }
            ))) {
                Text("Add a Unit")
            }
        }
    }
    
    private func isValid() -> Bool {
        if itemName.isEmpty { return false }
        
        if selectedCategory == .treatment && addFutureDoses {
            return weeklyDoses.contains { weekData in
                let doseValid = inputMode == .decimal ? 
                    (!weekData.value.dose.isEmpty && Double(weekData.value.dose) != nil) : 
                    (weekData.value.fraction != nil)
                return doseValid && weekData.value.unit != nil
            }
        } else {
            return (inputMode == .decimal && !dose.isEmpty && Double(dose) != nil) || 
                   (inputMode == .fraction && selectedFraction != nil) && 
                   selectedUnit != nil
        }
    }
    
    private func saveItem() {
        guard !itemName.isEmpty else { return }
        
        let newItem: Item
        
        if selectedCategory == .treatment && addFutureDoses {
            let validDoses = weeklyDoses.compactMap { (week, value) -> (Int, Double)? in
                let doseValue = inputMode == .decimal ? Double(value.dose) : value.fraction?.decimalValue
                guard let validDose = doseValue, value.unit != nil else { return nil }
                return (week, validDose)
            }
            guard !validDoses.isEmpty else { return }
            let firstUnit = weeklyDoses[validDoses.first!.0]?.unit?.name
            
            newItem = Item(
                id: editingItem?.id ?? UUID(),
                name: itemName,
                category: selectedCategory,
                dose: nil,
                unit: firstUnit,
                weeklyDoses: Dictionary(uniqueKeysWithValues: validDoses),
                order: editingItem?.order ?? 0
            )
        } else {
            guard let doseValue = inputMode == .decimal ? Double(dose) : selectedFraction?.decimalValue,
                  let unit = selectedUnit else { return }
            
            newItem = Item(
                id: editingItem?.id ?? UUID(),
                name: itemName,
                category: selectedCategory,
                dose: doseValue,
                unit: unit.name,
                weeklyDoses: nil,
                order: editingItem?.order ?? 0
            )
        }
        
        appData.addItem(newItem, toCycleId: cycleId) { success in
            if success {
                DispatchQueue.main.async {
                    dismiss()
                }
            }
        }
    }
}
