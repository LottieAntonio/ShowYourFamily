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
    @State private var refreshID = UUID()

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
            // 使用主题中定义的背景渐变
            ZStack {
                Color.familyTheme.primary
                Image("black")
                    .resizable()
                    .scaledToFill()
            }
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 10) {  // 减小整体间距
               
                // 卡片堆叠区域
                Spacer()
                
                cardStackView
                
                Spacer()
            }
            .padding()
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
                
                // 使用更自然的弹簧动画，并使用主题颜色
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
        
  
    
    // 然后在 familyCardView 方法中
    // 提取通用的卡片背景视图
    private func cardBackgroundView() -> some View {
        ZStack {
            // 基础卡片形状
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                
            // 添加镭射效果层 - 彩虹渐变
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.red.opacity(0.1),
                            Color.orange.opacity(0.1),
                            Color.yellow.opacity(0.1),
                            Color.green.opacity(0.1),
                            Color.blue.opacity(0.1),
                            Color.purple.opacity(0.1),
                            Color.red.opacity(0.1)
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    )
                )
                
            // 添加光泽效果层
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.7),
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.7)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(0.8)
                
            // 添加边框 - 增强镭射感
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white,
                            Color.white.opacity(0.5),
                            Color.white
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        }
    }
    
    // 提取通用的圆形背景视图
    private func circleBackgroundView() -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.familyTheme.primary.opacity(0.7),
                        Color.familyTheme.primary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 180, height: 180)
    }
    
    // 提取通用的底部信息区域背景
    private func bottomInfoBackgroundView() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.8))
            .cornerRadius(20, corners: .bottomLeft)
            .cornerRadius(20, corners: .bottomRight)
    }
    
    // 修改后的家谱卡片视图
    private func familyCardView(for family: Family, at index: Int) -> some View {
        let isTopCard = index == currentIndex
        let memberCount = appViewModel.familyManager.getMemberCount(for: family.id)
        
        return ZStack {
            cardBackgroundView()
                
            // 内容层
            VStack(spacing: 0) {
                Spacer()
                
                // 放大族徽部分并居中
                ZStack {
                    circleBackgroundView()
                    
                    // 族徽图标部分
                    badgeIconView(for: family, isTopCard: isTopCard)
                }
                Spacer()

                // 底部信息区域
                VStack(spacing: 6) {
                    // 家谱名称 - 添加emoji装饰
                    HStack(spacing: 6) {
                        // 添加emoji
                        Text("📜")
                            .font(.system(size: 16))
                            .padding(4)
                            .background(
                                Circle()
                                    .fill(Color.familyTheme.primary.opacity(0.3))
                            )
                        
                        Text(family.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.trailing, 8)
                            .foregroundColor(Color.familyTheme.primary)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.familyTheme.primary.opacity(0.1))
                    )
                    
                    // 添加分隔线
                    Rectangle()
                        .fill(Color.familyTheme.primary.opacity(0.3))
                        .frame(width: 40, height: 1)
                        .padding(.vertical, 3)
                    
                    // 家谱描述
                    if let description = family.description, !description.isEmpty {
                        Text(description)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal)
                    }
                    
                    // 成员数量
                    HStack {
                        Image(systemName: "person.3.fill")
                            .font(.footnote)
                            .foregroundColor(Color.familyTheme.primary.opacity(0.7))
                        Text("\(memberCount) 位成员")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical,3)
                }
                .frame(width: 320)
                .padding(.vertical, 15)
                .background(bottomInfoBackgroundView())
            }
        }
        .frame(width: 320, height: 450)
        .onAppear {
            if isTopCard {
                Task {
                    await appViewModel.familyManager.loadMemberCount(for: family.id)
                }
            }
        }
        .id("family-\(family.id)-\(memberCount)")
    }
    
    // 提取族徽图标视图
    private func badgeIconView(for family: Family, isTopCard: Bool) -> some View {
        Group {
            if family.badgeType == .custom {
                if let image = family.badgeImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 160)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                        .scaleEffect(isTopCard ? 1.05 : 1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isTopCard)
                } else if let imageName = family.badgeImageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                        .scaleEffect(isTopCard ? 1.05 : 1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isTopCard)
                }
            } else if family.badgeType == .sfSymbol, let name = family.badgeImageName {
                Image(systemName: name)
                    .font(.system(size: 80))
                    .foregroundColor(Color.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                    .scaleEffect(isTopCard ? 1.05 : 1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isTopCard)
            } else if family.badgeType == .emoji, let emoji = family.badgeImageName {
                Text(emoji)
                    .font(.system(size: 80))
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                    .scaleEffect(isTopCard ? 1.05 : 1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isTopCard)
            } else {
                Image(systemName: family.isDefault ? "book.closed.fill" : "person.2.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                    .scaleEffect(isTopCard ? 1.05 : 1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isTopCard)
            }
        }
    }
    
    // 修改后的创建家谱卡片视图
    private var createFamilyCardView: some View {
        let isTopCard = currentIndex == appViewModel.familyManager.families.count
        
        return ZStack {
            cardBackgroundView()
            
            // 内容层
            VStack(spacing: 0) {
                Spacer()
                // 图标
                ZStack {
                    circleBackgroundView()
                    
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color.white.opacity(0.8))
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                        .scaleEffect(isTopCard ? 1.05 : 1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentIndex)
                }
                Spacer()
                
                // 底部信息区域
                VStack(spacing: 6) {
                    // 标题 - 添加emoji装饰
                    HStack(spacing: 6) {
                        // 添加emoji
                        Text("✨")
                            .font(.system(size: 16))
                            .padding(4)
                            .background(
                                Circle()
                                    .fill(Color.familyTheme.primary.opacity(0.3))
                            )
                        
                        Text("创建您的家谱")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.trailing, 8)
                            .foregroundColor(Color.familyTheme.primary)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.familyTheme.primary.opacity(0.1))
                    )
                    
                    // 添加分隔线
                    Rectangle()
                        .fill(Color.familyTheme.primary.opacity(0.3))
                        .frame(width: 40, height: 1)
                        .padding(.vertical, 3)
                    
                    // 描述
                    Text("开始记录您的家族历史和关系")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // 按钮
                    Button(action: {
                        createMode = .empty
                        showingFamilyInfoForm = true
                    }) {
                        Text("开始创建")
                            .font(.footnote)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.familyTheme.primary)
                            .cornerRadius(15)
                    }
                    .padding(.top, 5)
                    .padding(.bottom, 8)
                }
                .frame(width: 320)
                .padding(.vertical, 12)
                .background(bottomInfoBackgroundView())
            }
        }
        .frame(width: 320, height: 450)
        .onTapGesture {
            createMode = .empty
            showingFamilyInfoForm = true
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



