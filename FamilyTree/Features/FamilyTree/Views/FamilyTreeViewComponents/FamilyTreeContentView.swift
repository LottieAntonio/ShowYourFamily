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
    
    var body: some View {
        ZStack {
            Color.familyTheme.primary.opacity(0.2)
                .ignoresSafeArea()
            
            if viewModel.isLoading {
                ProgressView("加载中...")
            } else if personManager.persons.isEmpty {
                // 修改这里，确保 showAddPerson 在主线程执行
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
            do {
                // 先加载 viewModel 的数据
                try await viewModel.loadData()
                // 确保 viewModel 加载完成后再加载 personManager 的数据
                try await personManager.loadData()
            } catch {
                print("数据加载错误：\(error.localizedDescription)")
            }
        }
    }
}

// 可以继续拆分 FamilyTreeGridView 和 EmptyStateView 到单独的文件中
