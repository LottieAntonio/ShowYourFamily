import SwiftUI

struct FamilyTreeContentView: View {
    @ObservedObject var viewModel: FamilyTreeViewModel
    @ObservedObject var personManager: PersonManagementViewModel
    @Binding var showingPersonCard: Bool
    @Binding var selectedMode: PersonCardMode
    @Binding var isTransitioning: Bool
    @Binding var selectedPersonId: UUID?
    @Binding var transitionOffset: CGSize
    var animation: Namespace.ID
    var showAddPerson: () -> Void
    var showAddRelation: (Person, RelationType, String?, Person.Gender?) async -> Void
    
    @State private var isLocalLoading = true  // 添加本地加载状态
    
    var body: some View {
        ZStack {
            Color.familyTheme.primary.opacity(0.2)
                .ignoresSafeArea()
            
            if isLocalLoading {
                ProgressView("加载中...")
            } else if personManager.persons.isEmpty {
                FamilyTreeEmptyStateView(showAddPerson: {
                    Task { @MainActor in
                        showAddPerson()
                    }
                })
            } else if let currentPerson = personManager.selectedPerson {
                FamilyTreeGridView(
                    currentPerson: currentPerson,
                    personManager: personManager,
                    showingPersonCard: $showingPersonCard,
                    selectedMode: $selectedMode,
                    isTransitioning: $isTransitioning,
                    selectedPersonId: $selectedPersonId,
                    transitionOffset: $transitionOffset,
                    animation: animation,
                    showAddRelation: showAddRelation
                )
            }
        }
        .task {
            await loadInitialData()
        }
        .onChange(of: showingPersonCard) { isShowing in
            if !isShowing {
                // 当表单关闭时重新加载数据
                Task {
                    await loadInitialData()
                }
            }
        }
    }
    
    // 添加数据加载方法
    private func loadInitialData() async {
        do {
            isLocalLoading = true
            try await viewModel.loadData()
            try await personManager.loadData()
            isLocalLoading = false
        } catch {
            print("数据加载错误：\(error.localizedDescription)")
            isLocalLoading = false
        }
    }
}

// 可以继续拆分 FamilyTreeGridView 和 EmptyStateView 到单独的文件中
