import SwiftUI

struct InitialSetupView: View {
    @ObservedObject var appData: AppData
    @Environment(\.dismiss) var dismiss
    @Binding var isInitialSetupActive: Bool
    @State private var step = 0
    @State private var isLogOnly = false
    @State private var cycleNumber: Int
    @State private var startDate: Date
    @State private var foodChallengeDate: Date
    @State private var patientName: String
    @State private var roomCodeInput = ""
    @State private var showingRoomCodeError = false
    @State private var userName: String = ""
    @State private var newCycleId: UUID?
    @State private var profileImage: UIImage?
    @State private var showingImagePicker = false
    @State private var debugMessage = ""

    init(appData: AppData, isInitialSetupActive: Binding<Bool>) {
        self.appData = appData
        self._isInitialSetupActive = isInitialSetupActive
        let lastCycle = appData.cycles.last
        self._cycleNumber = State(initialValue: (lastCycle?.number ?? 0) + 1)
        self._startDate = State(initialValue: lastCycle?.foodChallengeDate.addingTimeInterval(3 * 24 * 3600) ?? Date())
        self._foodChallengeDate = State(initialValue: Calendar.current.date(byAdding: .weekOfYear, value: 12, to: lastCycle?.foodChallengeDate.addingTimeInterval(3 * 24 * 3600) ?? Date())!)
        self._patientName = State(initialValue: lastCycle?.patientName ?? "")
    }

    var body: some View {
        NavigationView {
            VStack {
                if step == 0 {
                    ZStack {
                        Color(red: 242/255, green: 247/255, blue: 255/255).ignoresSafeArea()
                        VStack(spacing: 20) {
                            Text("Welcome to TIPs")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("Please select an option to get started")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button(action: {
                                isLogOnly = false
                                step = 1
                            }) {
                                Text("Create New Setup")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            Button(action: {
                                isLogOnly = true
                                step = 1
                            }) {
                                Text("Join Existing Program")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.gray)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                    }
                }
                else if step == 1 && isLogOnly {
                    ZStack {
                        Color(red: 242/255, green: 247/255, blue: 255/255).ignoresSafeArea()
                        VStack(spacing: 20) {
                            TextField("Your Name", text: $userName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding()
                            TextField("Room Code", text: $roomCodeInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding()
                            if showingRoomCodeError {
                                Text("Please enter both a name and a room code")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                        .padding()
                    }
                }
                else if step == 1 && !isLogOnly {
                    Form {
                        Section(header: Text("Cycle Information")) {
                            TextField("Patient Name", text: $patientName)
                            DatePicker("Start Date", selection: $startDate, displayedComponents: [.date])
                            DatePicker("Food Challenge Date", selection: $foodChallengeDate, displayedComponents: [.date])
                        }
                        Section(header: Text("Your Name")) {
                            TextField("Your Name", text: $userName)
                        }
                        Section(header: Text("Profile Image")) {
                            if let profileImage = profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .onTapGesture {
                                        showingImagePicker = true
                                    }
                            } else {
                                Button("Add Profile Image") {
                                    showingImagePicker = true
                                }
                            }
                        }
                    }
                }
                else if step == 2 && isLogOnly {
                    RemindersView(appData: appData)
                }
                else if step == 2 && !isLogOnly {
                    EditItemsView(appData: appData, cycleId: newCycleId ?? UUID())
                }
                else if step == 3 && isLogOnly {
                    TreatmentFoodTimerView(appData: appData)
                }
                else if step == 3 && !isLogOnly {
                    EditGroupedItemsView(
                        appData: appData,
                        cycleId: newCycleId ?? UUID(),
                        step: Binding<Int?>(
                            get: { step },
                            set: { newValue in if let value = newValue { step = value } }
                        )
                    )
                }
                else if step == 4 && !isLogOnly {
                    RemindersView(appData: appData)
                }
                else if step == 5 && !isLogOnly {
                    TreatmentFoodTimerView(appData: appData)
                }
            }
            .navigationTitle(getNavigationTitle())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if step > 1 && step != 3 {
                        Button("Previous") {
                            step -= 1
                        }
                    }
                    else if step == 1 {
                        Button("Back") {
                            step = 0
                        }
                    }
                    else {
                        EmptyView()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if step == 0 || step == 3 {
                        EmptyView()
                    }
                    else {
                        Button(getNextButtonTitle()) {
                            if isLogOnly && step == 1 {
                                if !roomCodeInput.isEmpty && !userName.isEmpty {
                                    debugMessage = "Setting room code to: \(roomCodeInput)"
                                    appData.roomCode = roomCodeInput
                                    let newUser = User(id: UUID(), name: userName, isAdmin: false)
                                    appData.addUser(newUser)
                                    appData.currentUser = newUser
                                    UserDefaults.standard.set(newUser.id.uuidString, forKey: "currentUserId")
                                    debugMessage += "\nCreated user: \(newUser.name) with ID: \(newUser.id)"
                                    step = 2
                                }
                                else {
                                    showingRoomCodeError = true
                                }
                            }
                            else if !isLogOnly && step == 1 {
                                if !userName.isEmpty {
                                    debugMessage = "Creating new setup with name: \(userName)"
                                    let newRoomCode = appData.roomCode ?? UUID().uuidString
                                    appData.roomCode = newRoomCode
                                    debugMessage += "\nRoom code: \(newRoomCode)"

                                    if appData.currentUser == nil {
                                        let newUser = User(id: UUID(), name: userName, isAdmin: true)
                                        appData.addUser(newUser)
                                        appData.currentUser = newUser
                                        UserDefaults.standard.set(newUser.id.uuidString, forKey: "currentUserId")
                                        debugMessage += "\nCreated new user: \(newUser.name)"
                                    }
                                    else if let currentUser = appData.currentUser, currentUser.name != userName {
                                        let updatedUser = User(
                                            id: currentUser.id,
                                            name: userName,
                                            isAdmin: currentUser.isAdmin,
                                            remindersEnabled: currentUser.remindersEnabled,
                                            reminderTimes: currentUser.reminderTimes,
                                            treatmentFoodTimerEnabled: currentUser.treatmentFoodTimerEnabled,
                                            treatmentTimerDuration: currentUser.treatmentTimerDuration
                                        )
                                        appData.addUser(updatedUser)
                                        appData.currentUser = updatedUser
                                        debugMessage += "\nUpdated user name to: \(userName)"
                                    }

                                    let effectivePatientName = patientName.isEmpty ? "Unnamed" : patientName
                                    let newCycle = Cycle(
                                        id: UUID(),
                                        number: cycleNumber,
                                        patientName: effectivePatientName,
                                        startDate: startDate,
                                        foodChallengeDate: foodChallengeDate
                                    )
                                    newCycleId = newCycle.id
                                    appData.addCycle(newCycle)
                                    debugMessage += "\nCreated cycle: \(newCycle.id)"

                                    if let profileImage = profileImage, let cycleId = newCycleId {
                                        appData.saveProfileImage(profileImage, forCycleId: cycleId)
                                        debugMessage += "\nSaved profile image"
                                    }

                                    step = 2
                                }
                            }
                            else if (isLogOnly && step == 3) || (!isLogOnly && step == 5) {
                                debugMessage = "Setup completed"
                                UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
                                NotificationCenter.default.post(name: Notification.Name("SetupCompleted"), object: nil)
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isInitialSetupActive = false
                                }
                            }
                            else {
                                step += 1
                            }
                        }
                        .disabled(isNextDisabled())
                    }
                }
            }
            .onAppear {
                ensureUserInitialized()
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $profileImage)
            }
            .alert("Error", isPresented: $showingRoomCodeError) {
                Button("OK") { }
            } message: {
                Text("Please enter both a name and a room code")
            }
        }
    }

    private func getNavigationTitle() -> String {
        switch step {
        case 0: return ""
        case 1: return isLogOnly ? "Join Program" : "Setup Cycle"
        case 2: return isLogOnly ? "Dose Reminders" : "Edit Items"
        case 3: return isLogOnly ? "Treatment Food Timer" : "Edit Grouped Items"
        case 4: return "Dose Reminders"
        case 5: return "Treatment Timer"
        default: return "Setup"
        }
    }

    private func getNextButtonTitle() -> String {
        if (isLogOnly && step == 3) || (!isLogOnly && step == 5) {
            return "Finish"
        }
        return "Next"
    }

    private func isNextDisabled() -> Bool {
        if step == 1 && isLogOnly {
            return roomCodeInput.isEmpty || userName.isEmpty
        }
        else if step == 1 && !isLogOnly {
            return userName.isEmpty
        }
        return false
    }

    private func ensureUserInitialized() {
        if appData.currentUser == nil && !userName.isEmpty {
            let newUser = User(id: UUID(), name: userName, isAdmin: !isLogOnly)
            appData.addUser(newUser)
            appData.currentUser = newUser
            UserDefaults.standard.set(newUser.id.uuidString, forKey: "currentUserId")
            print("Initialized user in InitialSetupView: \(newUser.id) with name: \(userName)")
            debugMessage += "\nInitialized user: \(userName)"
        }
        else if let currentUser = appData.currentUser, currentUser.name != userName && !userName.isEmpty {
            let updatedUser = User(
                id: currentUser.id,
                name: userName,
                isAdmin: currentUser.isAdmin,
                remindersEnabled: currentUser.remindersEnabled,
                reminderTimes: currentUser.reminderTimes,
                treatmentFoodTimerEnabled: currentUser.treatmentFoodTimerEnabled,
                treatmentTimerDuration: currentUser.treatmentTimerDuration
            )
            appData.addUser(updatedUser)
            appData.currentUser = updatedUser
            print("Updated user name from \(currentUser.name) to \(userName)")
            debugMessage += "\nUpdated user name to: \(userName)"
        }
    }
}

struct InitialSetupView_Previews: PreviewProvider {
    static var previews: some View {
        InitialSetupView(appData: AppData(), isInitialSetupActive: .constant(true))
    }
}
