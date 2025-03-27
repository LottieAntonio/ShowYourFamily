import SwiftUI

struct FamilyTreeContentView: View {
    // 修改为使用 appViewModel
    @EnvironmentObject var appViewModel: FamilyAppViewModel
    @Binding var showingPersonCard: Bool
    @Binding var selectedMode: PersonCardMode
    @Binding var isTransitioning: Bool
    @Binding var selectedPersonId: UUID?
    @Binding var transitionOffset: CGSize
    var animation: Namespace.ID
    var showAddPerson: () -> Void
    var showAddRelation: (Person, RelationType, String?, Person.Gender?) async -> Void
    
    @State private var isLocalLoading = true  // 添加本地加载状态
    
    // 修改计算属性，从 appViewModel 获取数据
    private var persons: [Person] {
        appViewModel.getStateManager().state.persons
    }
    
    private var selectedPerson: Person? {
        appViewModel.getStateManager().state.selectedPerson
    }
    
    var body: some View {
        ZStack {
            Color.familyTheme.primary.opacity(0.4)
                .edgesIgnoringSafeArea([.top, .horizontal])
            
            if isLocalLoading {
                ProgressView("加载中...")
            } else if persons.isEmpty {
                FamilyTreeEmptyStateView(showAddPerson: {
                    Task { @MainActor in
                        showAddPerson()
                    }
                })
            } else if let currentPerson = selectedPerson {
                FamilyTreeGridView(
                    currentPerson: currentPerson,
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
            // 使用 appViewModel 加载数据
            await loadInitialData()
            isLocalLoading = false
        }
        .onChange(of: showingPersonCard) { oldValue, isShowing in
            if !isShowing {
                // 当表单关闭时重新加载数据
                Task {
                    await loadInitialData()
                }
            }
        }
    }
    
    // 修改数据加载方法，使用 appViewModel
    private func loadInitialData() async {
        do {
            isLocalLoading = true
            await appViewModel.refreshData()
            
            // 如果没有选中的人物，但有家谱成员，则选择第一个人物
            if appViewModel.getStateManager().state.selectedPerson == nil && 
               !appViewModel.getStateManager().state.persons.isEmpty {
                appViewModel.getStateManager().selectPerson(appViewModel.getStateManager().state.persons.first!)
            }
            
            isLocalLoading = false
        } catch {
            print("数据加载错误：\(error.localizedDescription)")
            isLocalLoading = false
        }
    }
}

// 可以继续拆分 FamilyTreeGridView 和 EmptyStateView 到单独的文件中
