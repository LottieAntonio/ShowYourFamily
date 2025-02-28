import SwiftUI

struct FamilySelectionView: View {
    @StateObject private var familyManager: FamilyManagementViewModel
    @State private var showingError = false
    @State private var selectedFamily: Family?
    @State private var showingCreateOptions = false
    @State private var showingProfileSheet = false  // 添加这行
    
    init(dataManager: LocalDataManager = LocalDataManager()) {
        // 1. 创建 FamilyManagementViewModel
        let familyManagerVM = FamilyManagementViewModel(dataManager: dataManager)
        
        // 2. 创建 FamilyTreeViewModel
        let familyTreeVM = FamilyTreeViewModel(familyManager: familyManagerVM)
        familyManagerVM.setFamilyTreeViewModel(familyTreeVM)
        
        // 3. 初始化 StateObject
        _familyManager = StateObject(wrappedValue: familyManagerVM)
    }
    
    @State private var showingFamilyInfoForm = false
    @State private var createMode: FamilyCreateMode = .empty
    
    enum FamilyCreateMode {
        case empty
        case fromDefault
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("选择家谱")
                    .font(.title)
                    .padding(.top)
                
                Spacer()
                
                HStack(spacing: 20) {
                    // 显示所有家谱卡片
                    ForEach(familyManager.families) { family in
                        NavigationLink {
                            ContentView(familyManager: familyManager)
                                .navigationBarBackButtonHidden()
                                .interactiveDismissDisabled()
                                .onAppear {
                                    print("📝 切换到家谱：\(family.name)")
                                    Task {
                                        await familyManager.switchFamily(family)
                                    }
                                }
                        } label: {
                            FamilyCard(
                                family: family,
                                memberCount: family.id == familyManager.currentFamily?.id ? familyManager.persons.count : 0
                            )
                            .onAppear {
                                // 当卡片出现时，加载该家谱的成员数量
                                Task {
                                    if family.id != familyManager.currentFamily?.id {
                                        let persons = try? await familyManager.loadPersonsForFamily(family.id)
                                        await MainActor.run {
                                            if family.id == familyManager.currentFamily?.id {
                                                familyManager.persons = persons ?? []
                                            }
                                        }
                                    }
                                }
                                print("📊 显示家谱卡片：\(family.name)")
                            }
                        }
                    }
                    
                    // 创建新家谱按钮（只在没有用户家谱时显示）
                    if !familyManager.families.contains(where: { !$0.isDefault }) {
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
                }
                
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingProfileSheet = true
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingProfileSheet) {
                NavigationStack {
                    ProfileSettingsView()
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
            .sheet(isPresented: $showingCreateOptions) {
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
            .sheet(isPresented: $showingFamilyInfoForm) {
                FamilyInfoFormView(
                    isPresented: $showingFamilyInfoForm,
                    onComplete: { name, description in
                        Task {
                            do {
                                switch createMode {
                                case .empty:
                                    try await familyManager.createEmptyFamily(name: name, description: description)
                                case .fromDefault:
                                    try await familyManager.createFamilyFromDefault(name: name, description: description)
                                }
                                if let newFamily = familyManager.currentFamily {
                                    await familyManager.switchFamily(newFamily)
                                    selectedFamily = newFamily
                                }
                            } catch {
                                familyManager.setError(error.localizedDescription)
                                showingError = true
                            }
                        }
                    }
                )
            }
            .task {
                print("🔄 开始加载家谱数据...")
                do {
                    // 加载家谱数据（包括内置的示例家谱）
                    await familyManager.loadFamilies()
                    
                    // 加载示例家谱的数据
                    if let defaultFamily = familyManager.families.first(where: { $0.isDefault }) {
                        await familyManager.switchFamily(defaultFamily)
                        let persons = try await familyManager.loadPersonsForFamily(defaultFamily.id)
                        familyManager.persons = persons
                        let relationships = try await familyManager.loadRelationships(for: defaultFamily.id)
                        print("📊 加载完成：\(persons.count) 个成员，\(relationships.count) 个关系")
                    }
                } catch {
                    print("❌ 加载失败：\(error.localizedDescription)")
                }
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定", role: .cancel) { }
            } message: {
                if let error = familyManager.errorMessage {
                    Text(error)
                }
            }
            // 使用新的导航 API
            .navigationDestination(isPresented: Binding(
                get: { selectedFamily != nil },
                set: { if !$0 { selectedFamily = nil } }
            )) {
                ContentView(familyManager: familyManager)
                    .navigationBarBackButtonHidden()
                    .interactiveDismissDisabled()
            }
        }
    }
    
    
    
    private func createEmptyFamily(name: String, description: String) async {
        do {
            try await familyManager.createEmptyFamily(name: name, description: description)
            if let newFamily = familyManager.currentFamily {
                await familyManager.switchFamily(newFamily)
                selectedFamily = newFamily
            }
        } catch {
            familyManager.setError(error.localizedDescription)
            showingError = true
        }
    }
    
    private func createFamily(name: String, description: String) async {
        do {
            try await familyManager.createFamilyFromDefault(name: name, description: description)
            if let newFamily = familyManager.currentFamily {
                await familyManager.switchFamily(newFamily)
                selectedFamily = newFamily
            }
        } catch {
            familyManager.setError(error.localizedDescription)
            showingError = true
        }
    }
}


// 删除这个预览
// #Preview("有数据") {
//     let dataManager = PreviewDataManager()
//     let familyManager = FamilyManagementViewModel(dataManager: dataManager)
//     return FamilySelectionView(dataManager: dataManager)
// }

// 添加预览用的 DataManager
private class PreviewDataManager: LocalDataManager {
    override func loadFamilies() async throws -> [Family] {
        return [
            Family(
                id: UUID(),
                name: "示例家谱",
                description: "这是一个示例家谱，用于展示功能",
                isDefault: true
            ),
            Family(
                id: UUID(),
                name: "我的家谱",
                description: "这是一个用户创建的家谱",
                isDefault: false
            )
        ]
    }
    
    override func loadPersons(familyId: UUID) async throws -> [Person] {
        return [
            Person(familyId: familyId, firstName: "张", lastName: "三", gender: .male),
            Person(familyId: familyId, firstName: "李", lastName: "四", gender: .female)
        ]
    }
    
    override func loadRelationships(familyId: UUID) async throws -> [Relationship] {
        return []
    }
}

#Preview("家谱选择") {
    FamilySelectionView(dataManager: PreviewDataManager())
}

// 添加新的选项视图
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
