import Foundation
import UIKit
import Combine

@MainActor
class FamilyManagementViewModel: ObservableObject {
    @Published private(set) var families: [Family] = []
    @Published private(set) var currentFamily: Family?
    @Published private(set) var errorMessage: String?
    @Published private(set) var memberCount: Int = 0
    
    // 添加成员数量缓存
    private var memberCountCache: [UUID: Int] = [:]
    
    private let stateManager: StateManager
    // 添加对 FamilyAppViewModel 的弱引用
    private weak var appViewModel: FamilyAppViewModel?
    private var cancellables = Set<AnyCancellable>()
    
    // 修改初始化方法，移除 appViewModel 参数
    init(stateManager: StateManager) {
        self.stateManager = stateManager
        setupBindings()
    }
    
    // 添加设置 appViewModel 的方法
    func setAppViewModel(_ viewModel: FamilyAppViewModel) {
        self.appViewModel = viewModel
    }
    
    private func setupBindings() {
        // 保持现有的绑定逻辑
        stateManager.$state
            .sink { [weak self] state in
                guard let self = self else { return }
                
                self.families = state.families
                self.currentFamily = state.currentFamily
                
                // 更新成员数量
                if let currentFamily = state.currentFamily {
                    self.memberCount = state.persons.count
                }
            }
            .store(in: &cancellables)
    }
    
    // 添加加载成员数量的方法
    func loadMemberCount(for familyId: UUID) async {
        do {
            print("正在加载家族 \(familyId) 的成员数量...")
            let persons = try await loadPersonsForFamily(familyId)
            await MainActor.run {
                let count = persons.count
                print("家族 \(familyId) 的成员数量加载完成: \(count)")
                
                // 更新当前家族的成员数量
                if let currentFamily = currentFamily, currentFamily.id == familyId {
                    self.memberCount = count
                    print("更新当前家族的成员数量: \(count)")
                }
                
                // 更新缓存
                self.memberCountCache[familyId] = count
                print("更新缓存: familyId=\(familyId), count=\(count)")
                
                // 发送通知，让使用该数据的视图刷新
                NotificationCenter.default.post(
                    name: NSNotification.Name("FamilyMemberCountUpdated"), 
                    object: nil,
                    userInfo: ["familyId": familyId]
                )
                print("已发送成员数量更新通知: familyId=\(familyId)")
            }
        } catch {
            print("加载成员数量失败: \(error.localizedDescription)")
        }
    }
    
    // 添加获取成员数量的方法
    func getMemberCount(for familyId: UUID) -> Int {
        // 如果是当前选中的家族，直接返回已加载的成员数量
        if let currentFamily = currentFamily, currentFamily.id == familyId {
            return memberCount
        }
        
        // 如果缓存中有该家族的成员数量，返回缓存值
        if let cachedCount = memberCountCache[familyId] {
            print("从缓存获取家族 \(familyId) 的成员数量: \(cachedCount)")
            return cachedCount
        }
        
        // 如果没有缓存，立即开始加载
        Task {
            print("开始异步加载家族 \(familyId) 的成员数量")
            await loadMemberCount(for: familyId)
        }
        
        // 暂时返回0
        print("家族 \(familyId) 的成员数量暂未加载，返回0")
        return 0
    }
    
    // 添加更新成员数量缓存的方法
    func updateMemberCount(for familyId: UUID, count: Int) {
        // 更新缓存
        memberCountCache[familyId] = count
        
        // 如果是当前家族，也更新 memberCount
        if let currentFamily = currentFamily, currentFamily.id == familyId {
            memberCount = count
        }
        
        print("FamilyManagementViewModel: 更新家族 \(familyId) 的成员数量缓存: \(count)")
    }
    
    // 添加加载家谱成员的方法
    func loadPersonsForFamily(_ familyId: UUID) async throws -> [Person] {
        // 使用 stateManager 提供的方法而不是直接访问 dataManager
        return try await stateManager.loadPersons(for: familyId)
    }
    
    // 添加加载关系的方法
    func loadRelationships(for familyId: UUID) async throws -> [Relationship] {
        // 使用 stateManager 提供的方法而不是直接访问 dataManager
        return try await stateManager.loadRelationships(for: familyId)
    }
    
    func loadFamilies() async {
        // 使用 stateManager 的 loadInitialData 方法
        await stateManager.loadInitialData()
    }
    
   
    // 添加创建空白家谱的方法
    func createEmptyFamily(name: String, description: String) async throws {
        // 创建一个空白家谱
        let emptyFamily = Family(
            id: UUID(),
            name: name,
            description: description,
            isDefault: false
        )
        try await stateManager.addFamily(emptyFamily)
        await stateManager.setCurrentFamily(emptyFamily)
        
        // 通知 appViewModel 刷新数据
        if let appViewModel = appViewModel {
            await appViewModel.refreshData()
        }
    }
    
    
    // 添加切换家谱的方法
    func switchFamily(_ family: Family) async {
        // 使用 stateManager 切换当前家谱
        await stateManager.selectFamily(family)
        
        // 通知 appViewModel 刷新数据
        if let appViewModel = appViewModel {
            await appViewModel.refreshData()
        }
    }
    
    // 添加更新家谱信息的方法
    // 修改 updateFamily 方法，确保更新及时
    // 更新家谱信息
    func updateFamily(_ family: Family) async throws {
        do {
            // 保存到数据库
            try await stateManager.updateFamily(family)
            
            // 更新内存中的数据
            await MainActor.run {
                if let index = families.firstIndex(where: { $0.id == family.id }) {
                    families[index] = family
                }
            }
            
            // 打印调试信息
            print("更新家谱成功 - ID: \(family.id), 名称: \(family.name), 族徽类型: \(family.badgeType), 族徽名称: \(family.badgeImageName ?? "无")")
            
            // 发送通知
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("FamilyUpdated"),
                    object: nil,
                    userInfo: ["familyId": family.id]
                )
            }
            
            return
        } catch {
            errorMessage = "更新家谱失败: \(error.localizedDescription)"
            throw error
        }
    }
    
    // 添加删除家谱的方法
    func deleteFamily(_ familyId: UUID) async throws {
        // 使用 stateManager 删除家谱
        try await stateManager.deleteFamily(familyId)
        
        // 通知 appViewModel 刷新数据
        if let appViewModel = appViewModel {
            await appViewModel.refreshData()
        }
    }
    
    // 创建空白家谱
    func createFamily(name: String, description: String?, badgeType: Family.BadgeType, badgeImageName: String?, badgeImage: UIImage?) async throws {
        do {
            // 创建一个新的家谱
            var newFamily = Family(name: name, description: description)
            newFamily.isDefault = false
            
            // 设置族徽信息
            newFamily.badgeType = badgeType
            newFamily.badgeImageName = badgeImageName
            newFamily.badgeImage = badgeImage
            
            // 添加到 stateManager
            try await stateManager.addFamily(newFamily)
            
            // 打印日志，帮助调试
            print("创建家谱成功: \(name), 族徽类型: \(badgeType), 族徽名称: \(badgeImageName ?? "无")")
            
            return
        } catch {
            errorMessage = "创建家谱失败: \(error.localizedDescription)"
            throw error
        }
    }
    
   
}

