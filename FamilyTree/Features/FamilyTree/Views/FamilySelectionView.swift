import SwiftUI

struct FamilySelectionView: View {
    // 使用 environmentObject 而不是创建新实例
    @EnvironmentObject var appViewModel: FamilyAppViewModel
    
    @State private var showingError = false
    @State private var selectedFamily: Family?
    @State private var showingCreateOptions = false
    @State private var showingProfileSheet = false
    @State private var showingFamilyInfoForm = false
    @State private var createMode: FamilyCreateMode = .empty
    
    enum FamilyCreateMode {
        case empty
        case fromDefault
    }
    
    var body: some View {
        NavigationStack {
            mainContentView
                .navigationDestination(isPresented: Binding(
                    get: { selectedFamily != nil },
                    set: { if !$0 { selectedFamily = nil } }
                )) {
                    ContentView()
                        .environmentObject(appViewModel)
                        .navigationBarBackButtonHidden()
                        .interactiveDismissDisabled()
                }
        }
    }
    
    private var mainContentView: some View {
        VStack {
            Text("选择家谱")
                .font(.title)
                .padding(.top)
            
            Spacer()
            
            familyCardsView
            
            Spacer()
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                profileButton
            }
        }
        .sheet(isPresented: $showingProfileSheet) {
            profileSheetView
                .environmentObject(appViewModel)
        }
        .sheet(isPresented: $showingCreateOptions) {
            createOptionsSheetView
        }
        .sheet(isPresented: $showingFamilyInfoForm) {
            familyInfoFormSheetView
        }
        .task {
            await loadInitialData()
        }
        .alert("错误", isPresented: $showingError) {
            Button("确定", role: .cancel) { }
        } message: {
            if let error = appViewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    private var familyCardsView: some View {
        HStack(spacing: 20) {
            ForEach(appViewModel.familyManager.families) { family in
                familyCardLink(for: family)
            }
            
            if !appViewModel.familyManager.families.contains(where: { !$0.isDefault }) {
                createFamilyButton
            }
        }
    }
    
    private func familyCardLink(for family: Family) -> some View {
        NavigationLink {
            ContentView()
                .environmentObject(appViewModel)
                .navigationBarBackButtonHidden()
                .interactiveDismissDisabled()
                .onAppear {
                    Task {
                        await appViewModel.familyManager.switchFamily(family)
                    }
                }
        } label: {
            FamilyCard(
                family: family,
                memberCount: family.id == appViewModel.currentFamily?.id ?
                    appViewModel.familyManager.memberCount : 0
            )
            .onAppear {
                Task {
                    if family.id != appViewModel.currentFamily?.id {
                        await appViewModel.familyManager.loadMemberCount(for: family.id)
                    }
                }
            }
        }
    }
    
    private var createFamilyButton: some View {
        Button {
            showingCreateOptions = true
        } label: {
            VStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 40))
                Text("创建我的家谱")
                    .font(.headline)
            }
            .frame(width: 160, height: 180)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .background(Color(.systemBackground))
            )
        }
    }
    
    private var profileButton: some View {
        Button {
            showingProfileSheet = true
        } label: {
            Image(systemName: "person.circle")
                .font(.title2)
        }
    }
    
    private var profileSheetView: some View {
        NavigationStack {
            ProfileSettingsView()
                .environmentObject(appViewModel)
                .navigationTitle("个人中心")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") {
                            showingProfileSheet = false
                        }
                    }
                }
        }
    }
    
    private var createOptionsSheetView: some View {
        CreateFamilyOptionsView(
            isPresented: $showingCreateOptions,
            onCreateEmpty: {
                createMode = .empty
                showingCreateOptions = false
                showingFamilyInfoForm = true
            },
            onCreateFromDefault: {
                createMode = .fromDefault
                showingCreateOptions = false
                showingFamilyInfoForm = true
            }
        )
    }
    
    private var familyInfoFormSheetView: some View {
        FamilyInfoFormView(
            isPresented: $showingFamilyInfoForm,
            onComplete: { name, description in
                Task {
                    await createFamilyWithInfo(name: name, description: description)
                }
            }
        )
    }
    
    private func loadInitialData() async {
        do {
            await appViewModel.familyManager.loadFamilies()
            
            if let defaultFamily = appViewModel.familyManager.families.first(where: { $0.isDefault }) {
                await appViewModel.familyManager.switchFamily(defaultFamily)  // 修改这里
            }
        } catch {
            appViewModel.errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    
    private func createFamilyWithInfo(name: String, description: String) async {
        do {
            switch createMode {
            case .empty:
                try await appViewModel.familyManager.createEmptyFamily(name: name, description: description)
            case .fromDefault:
                try await appViewModel.familyManager.createFamilyFromDefault(name: name, description: description)
            }
            
            if let newFamily = appViewModel.currentFamily {
                await appViewModel.familyManager.switchFamily(newFamily)  // 修改这里
                selectedFamily = newFamily
            }
        } catch {
            appViewModel.errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// CreateFamilyOptionsView 保持不变
struct CreateFamilyOptionsView: View {
    @Binding var isPresented: Bool
    let onCreateEmpty: () -> Void
    let onCreateFromDefault: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: {
                        isPresented = false
                        onCreateEmpty()
                    }) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            VStack(alignment: .leading) {
                                Text("创建空白家谱")
                                    .font(.headline)
                                Text("从零开始创建您的家谱")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Button(action: {
                        isPresented = false
                        onCreateFromDefault()
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            VStack(alignment: .leading) {
                                Text("复制示例家谱")
                                    .font(.headline)
                                Text("基于示例家谱创建，包含示例数据")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("创建家谱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
