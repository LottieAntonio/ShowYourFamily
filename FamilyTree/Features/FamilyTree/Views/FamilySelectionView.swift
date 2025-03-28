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
    
    // 添加卡片堆叠和滑动所需的状态
    @State private var currentIndex = 0
    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    
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
                    if let family = selectedFamily {
                        FamilyHomePage(family: family)
                            .environmentObject(appViewModel)
                    }
                }
        }
    }
    
    private var mainContentView: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color.accentColor.opacity(0.3),
                    Color(.systemBackground)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 10) {  // 减小整体间距
                // 标题区域
                Text("家谱")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .padding(.top, 50)  // 减小顶部间距
                
                Text("选择或创建您的家族谱系")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)  // 减小底部间距
                
                // 卡片堆叠区域
                Spacer()
                    .frame(height: 40)  // 添加一个固定高度的小间距
                
                cardStackView
                
                Spacer()
                    .frame(minHeight: 0, maxHeight: .infinity, alignment: .bottom)  // 让底部空间可以伸缩
                
              
            }
            .padding()
        }
        .sheet(isPresented: $showingProfileSheet) {
            profileSheetView
                .environmentObject(appViewModel)
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
    
    private var familyInfoFormSheetView: some View {
        FamilyInfoFormView(isPresented: $showingFamilyInfoForm) { name, description, badgeImageName, badgeType, customImage in
            Task {
                do {
                    // 确保这里正确传递了族徽信息
                    if createMode == .empty {
                        try await appViewModel.familyManager.createFamily(
                            name: name,
                            description: description.isEmpty ? nil : description,
                            badgeType: badgeType,
                            badgeImageName: badgeImageName,
                            badgeImage: customImage
                        )
                    } else {
                        try await appViewModel.familyManager.createFamilyFromDefault(
                            name: name,
                            description: description.isEmpty ? "nil" : description
                        )
                    }
                    
                    // 选择新创建的家谱
                    if let newFamily = appViewModel.familyManager.families.last {
                        selectedFamily = newFamily
                    }
                } catch {
                    appViewModel.errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func createFamilyWithInfo(
        name: String, 
        description: String,
        badgeImageName: String?,
        badgeType: Family.BadgeType,
        customImage: UIImage?
    ) async {
        do {
            switch createMode {
            case .empty:
                try await appViewModel.familyManager.createEmptyFamily(
                    name: name, 
                    description: description
                )
            case .fromDefault:
                try await appViewModel.familyManager.createFamilyFromDefault(
                    name: name, 
                    description: description
                )
            }
            
            if let newFamily = appViewModel.currentFamily {
                await appViewModel.familyManager.switchFamily(newFamily)
                selectedFamily = newFamily
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
    
    
    // 卡片堆叠视图
    private var cardStackView: some View {
        let families = appViewModel.familyManager.families
        let hasCustomFamily = families.contains(where: { !$0.isDefault })
        let totalItems = hasCustomFamily ? families.count : families.count + 1
        
        // 添加分页指示器
        return VStack {
            ZStack {
                if families.isEmpty {
                    // 如果没有家谱，显示加载中
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    // 先渲染所有卡片，确保它们都在视图层次结构中
                    ForEach(0..<families.count, id: \.self) { index in
                        let family = families[index]
                        let isTopCard = index == currentIndex
                        let cardOffset = isTopCard ? offset : 0
                        
                        familyCardView(for: family, at: index)
                            .offset(x: cardOffset + CGFloat(index - currentIndex) * 50)
                            .offset(y: isTopCard ? 0 : -15)
                            .scaleEffect(isTopCard ? 1.0 : 0.9)
                            .rotationEffect(.degrees(isTopCard ? Double(offset / 20) : 0))
                            .zIndex(isTopCard ? 100 : Double(families.count - index))
                            .opacity(abs(index - currentIndex) <= 1 ? 1 : 0) // 只显示当前和相邻的卡片
                            .gesture(isTopCard ? dragGesture : nil)
                            .onTapGesture {
                                if isTopCard {
                                    Task {
                                        await appViewModel.familyManager.switchFamily(family)
                                        selectedFamily = family
                                    }
                                } else if index > currentIndex {
                                    // 点击后面的卡片，向左滑动
                                    withAnimation(.spring()) {
                                        currentIndex = index
                                    }
                                } else if index < currentIndex {
                                    // 点击前面的卡片，向右滑动
                                    withAnimation(.spring()) {
                                        currentIndex = index
                                    }
                                }
                            }
                    }
                    
                    // 创建家谱卡片 - 作为额外的一张卡片
                    if !hasCustomFamily {
                        let isCreateCardTop = currentIndex == families.count
                        let createCardOffset: CGFloat = isCreateCardTop ? offset : 50
                        
                        createFamilyCardView
                            .offset(x: createCardOffset)
                            .offset(y: isCreateCardTop ? 0 : -15)
                            .scaleEffect(isCreateCardTop ? 1.0 : 0.9)
                            .rotationEffect(.degrees(isCreateCardTop ? Double(offset / 20) : 0))
                            .zIndex(isCreateCardTop ? 100 : 0)
                            .opacity(currentIndex >= families.count - 1 ? 1 : 0) // 只在最后一张家谱卡片或当前是创建卡片时显示
                            .gesture(isCreateCardTop ? dragGesture : nil)
                            .onTapGesture {
                                if isCreateCardTop {
                                    // 直接设置为创建空白家谱模式并显示信息表单
                                    createMode = .empty
                                    showingFamilyInfoForm = true
                                } else {
                                    // 点击后面的创建卡片，向左滑动到创建卡片
                                    withAnimation(.spring()) {
                                        currentIndex = families.count
                                    }
                                }
                            }
                    }
                }
            }
            .frame(height: 400) // 增加卡片区域的高度
            
//            // 添加分页指示器
//            HStack(spacing: 8) {
//                ForEach(0..<totalItems, id: \.self) { index in
//                    Circle()
//                        .fill(index == currentIndex ? Color.accentColor : Color.gray.opacity(0.3))
//                        .frame(width: 8, height: 8)
//                        .scaleEffect(index == currentIndex ? 1.2 : 1)
//                        .animation(.spring(), value: currentIndex)
//                        .onTapGesture {
//                            // 点击指示器直接跳转到对应卡片
//                            withAnimation(.spring()) {
//                                currentIndex = index
//                            }
//                        }
//                }
//            }
//            .padding(.top, 20)
        }
        .frame(height: 450) // 增加整个卡片堆叠视图的高度
        .onChange(of: currentIndex) { newIndex in
            print("当前索引变更为: \(newIndex)")
            // 更新分页指示器
            let families = appViewModel.familyManager.families
            let hasCustomFamily = families.contains(where: { !$0.isDefault })
            let totalItems = hasCustomFamily ? families.count : families.count + 1
            
            if !hasCustomFamily && newIndex == families.count {
                // 当前是创建家谱卡片
                print("当前是创建家谱卡片")
            } else if newIndex < families.count {
                // 当前是家谱卡片
                print("当前是家谱卡片: \(families[newIndex].name)")
                Task {
                    let family = families[newIndex]
                    // 加载当前显示卡片的成员数量
                    await appViewModel.familyManager.loadMemberCount(for: family.id)
                }
            }
        }
    }

    // 拖动手势
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                // 添加阻尼效果：将实际拖动距离乘以一个系数（小于1）
                offset = value.translation.width * 0.8
                // 添加调试信息
                print("拖动中: \(offset)")
            }
            .onEnded { value in
                isDragging = false
                
                // 计算是否应该切换卡片
                let threshold: CGFloat = 50 // 降低阈值，使滑动更灵敏
                let families = appViewModel.familyManager.families
                let hasCustomFamily = families.contains(where: { !$0.isDefault })
                let totalItems = hasCustomFamily ? families.count : families.count + 1
                
                // 添加调试信息
                print("拖动结束: \(value.translation.width), 当前索引: \(currentIndex), 总项目: \(totalItems)")
                
                // 使用更自然的弹簧动画
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.5)) {
                    if value.translation.width < -threshold && currentIndex < totalItems - 1 {
                        // 向左滑动，显示下一张卡片
                        currentIndex += 1
                        print("向左滑动到卡片: \(currentIndex)")
                    } else if value.translation.width > threshold && currentIndex > 0 {
                        // 向右滑动，显示上一张卡片
                        currentIndex -= 1
                        print("向右滑动到卡片: \(currentIndex)")
                    }
                    
                    // 重置偏移量
                    offset = 0
                }
            }
    }
        
        // 计算卡片缩放比例
        private func calculateScale(for index: Int) -> CGFloat {
            let offset = index - currentIndex
            if offset == 0 {
                return 1.0
            } else if offset == 1 {
                return 0.9
            } else if offset == 2 {
                return 0.8
            } else {
                return 0.7
            }
        }
    
    // 单个家谱卡片视图 - 用于卡片堆叠效果
    // 修改 familyCardView 方法，使用 getMemberCount 获取缓存的成员数量
    // 在 FamilySelectionView 的属性中添加
    @State private var refreshID = UUID()
    
    // 然后在 familyCardView 方法中
    private func familyCardView(for family: Family, at index: Int) -> some View {
        let isTopCard = index == currentIndex
        
        // 修改这里：使用 getMemberCount 方法获取缓存的成员数量
        let memberCount = appViewModel.familyManager.getMemberCount(for: family.id)
        
        return VStack {
            Spacer()
            
            // 放大族徽部分并居中
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 160, height: 160)
                
                if family.badgeType == .custom, let image = family.badgeImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                } else if family.badgeType == .sfSymbol, let name = family.badgeImageName {
                    Image(systemName: name)
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)
                } else if family.badgeType == .emoji, let emoji = family.badgeImageName {
                    Text(emoji)
                        .font(.system(size: 80))
                } else {
                    // 默认图标
                    Image(systemName: family.isDefault ? "book.closed.fill" : "person.2.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)
                }
            }
            
            Spacer()
            
            // 底部信息区域
            VStack(spacing: 8) {
                // 家谱名称
                Text(family.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                // 家谱描述
                if let description = family.description, !description.isEmpty {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal)
                }
                
                // 成员数量
                Text("\(memberCount) 位成员")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
            }
            .padding(.bottom, 20)
            .padding(.horizontal)
            .frame(width: 320)
            .background(
                Rectangle()
                    .fill(Color(.systemBackground).opacity(0.8))
                    .cornerRadius(20, corners: [.bottomLeft, .bottomRight])
            )
        }
        .frame(width: 320, height: 400)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .onAppear {
            if isTopCard {
                Task {
                    // 只有当前卡片才加载成员数量
                    await appViewModel.familyManager.loadMemberCount(for: family.id)
                }
            }
        }
        // 简化通知监听逻辑
        .id("family-\(family.id)-\(memberCount)")
    }
    
    // 创建家谱卡片视图 - 用于卡片堆叠效果
    private var createFamilyCardView: some View {
        VStack {
            Spacer()
            
            // 图标
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 160, height: 160) // 放大图标区域
                
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 80)) // 放大图标
                    .foregroundColor(.accentColor)
            }
            
            Spacer()
            
            // 底部信息区域
            VStack(spacing: 8) {
                // 标题
                Text("创建您的家谱")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // 描述
                Text("开始记录您的家族历史和关系")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // 按钮
                Button(action: {
                    // 直接设置为创建空白家谱模式并显示信息表单
                    createMode = .empty
                    showingFamilyInfoForm = true
                }) {
                    Text("开始创建")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(25)
                }
                .padding(.top, 10)
            }
            .padding(.bottom, 30)
            .padding(.horizontal)
            .frame(width: 320) // 增加底部信息区域宽度
            .background(
                Rectangle()
                    .fill(Color(.systemBackground).opacity(0.8))
                    .cornerRadius(20, corners: [.bottomLeft, .bottomRight])
            )
        }
        .frame(width: 320, height: 400) // 增加整个卡片的尺寸
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .onTapGesture {
            createMode = .empty
            showingFamilyInfoForm = true
        }
    }
    
    // 创建家谱浮动按钮
    private var createFamilyFloatingButton: some View {
        Button(action: {
            showingCreateOptions = true
        }) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 5, x: 0, y: 3)
                
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
    
    private func loadInitialData() async {
        appViewModel.isLoading = true
        
        do {
            // 加载所有家谱数据
            try await appViewModel.familyManager.loadFamilies()
            
            // 如果没有家谱数据，确保当前索引为0，以便显示创建家谱卡片
            if appViewModel.familyManager.families.isEmpty {
                currentIndex = 0
                print("没有家谱数据，显示创建家谱卡片")
            } else {
                // 如果有家谱数据，加载第一个家谱的成员数量
                if let firstFamily = appViewModel.familyManager.families.first {
                    await appViewModel.familyManager.loadMemberCount(for: firstFamily.id)
                    currentIndex = 0
                    print("加载第一个家谱: \(firstFamily.name)")
                }
            }
            
            // 刷新视图
            refreshID = UUID()
        } catch {
            // 处理加载错误
            appViewModel.errorMessage = "加载家谱数据失败: \(error.localizedDescription)"
            showingError = true
            print("加载家谱数据错误: \(error.localizedDescription)")
        }
        appViewModel.isLoading = false

    }

}



