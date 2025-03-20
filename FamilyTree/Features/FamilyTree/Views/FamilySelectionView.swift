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
                    Color.accentColor.opacity(0.1),
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
                
                // 分页指示器
                pageIndicator
                    .padding(.bottom, 20)  // 减小底部间距
            }
            .padding()
        }
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                profileButton
//            }
//        }
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
        Button {
            Task {
                await appViewModel.familyManager.switchFamily(family)
                selectedFamily = family
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
        .buttonStyle(PlainButtonStyle())
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
    
    
    // 卡片堆叠视图
    private var cardStackView: some View {
        let families = appViewModel.familyManager.families
        let hasCustomFamily = families.contains(where: { !$0.isDefault })
        _ = hasCustomFamily ? families.count : families.count + 1
        
        return ZStack {
            if families.isEmpty {
                // 如果没有家谱，显示加载中
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                // 堆叠卡片 - 包括家谱卡片
                ForEach(0..<families.count, id: \.self) { index in
                    if index >= currentIndex && index < currentIndex + 3 {
                        let family = families[index]
                        let isTopCard = index == currentIndex
                        let offset = isTopCard ? self.offset : 0
                        
                        familyCardView(for: family, at: index)
                            .offset(x: offset, y: isTopCard ? 0 : CGFloat(index - currentIndex) * -15)
                            .offset(x: CGFloat(index - currentIndex) * 50, y: 0) // 让后面的卡片错开一点
                            .scaleEffect(calculateScale(for: index))
                            .rotationEffect(.degrees(isTopCard ? Double(offset / 20) : 0))
                            .zIndex(Double(families.count - index))
                            .gesture(
                                isTopCard ? dragGesture : nil
                            )
                            .onTapGesture {
                                if isTopCard {
                                    Task {
                                        await appViewModel.familyManager.switchFamily(family)
                                        selectedFamily = family
                                    }
                                }
                            }
                    }
                }
                
                // 创建家谱卡片 - 作为额外的一张卡片
                if !hasCustomFamily {
                    let isCreateCardTop = currentIndex == families.count
                    let createCardOffset: CGFloat = isCreateCardTop ? self.offset : 50
                    let createCardYOffset: CGFloat = isCreateCardTop ? 0 : -15
                    
                    createFamilyCardView
                        .offset(x: createCardOffset, y: createCardYOffset)
                        .scaleEffect(isCreateCardTop ? 1.0 : 0.9)
                        .rotationEffect(.degrees(isCreateCardTop ? Double(offset / 20) : 0))
                        .zIndex(isCreateCardTop ? Double(families.count + 1) : 0)
                        .gesture(
                            isCreateCardTop ? dragGesture : nil
                        )
                        .onTapGesture {
                            // 直接设置为创建空白家谱模式并显示信息表单
                            createMode = .empty
                            showingFamilyInfoForm = true
                        }
                }
            }
        }
        .frame(height: 400)
        .onChange(of: currentIndex) { newIndex in
            // 更新分页指示器
            if !hasCustomFamily && newIndex == families.count {
                // 当前是创建家谱卡片
            } else if newIndex < families.count {
                // 当前是家谱卡片
                Task {
                    let family = families[newIndex]
                    await appViewModel.familyManager.loadMemberCount(for: family.id)
                }
            }
        }
    }

    // 分页指示器
    private var pageIndicator: some View {
        let families = appViewModel.familyManager.families
        let hasCustomFamily = families.contains(where: { !$0.isDefault })
        let totalItems = hasCustomFamily ? families.count : families.count + 1
        
        return HStack(spacing: 8) {
            ForEach(0..<totalItems, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentIndex ? 1.2 : 1)
                    .animation(.spring(), value: currentIndex)
            }
        }
        .opacity(totalItems > 1 ? 1 : 0)
    }

    // 拖动手势
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                offset = value.translation.width
            }
            .onEnded { value in
                isDragging = false
                
                // 计算是否应该切换卡片
                let threshold: CGFloat = 100
                let families = appViewModel.familyManager.families
                let hasCustomFamily = families.contains(where: { !$0.isDefault })
                let totalItems = hasCustomFamily ? families.count : families.count + 1
                
                withAnimation(.spring()) {
                    if value.translation.width < -threshold && currentIndex < totalItems - 1 {
                        // 向左滑动，显示下一张卡片
                        currentIndex += 1
                        offset = 0
                        
                        // 预加载下一张卡片的成员数量
                        if currentIndex < families.count {
                            Task {
                                let nextFamily = families[currentIndex]
                                await appViewModel.familyManager.loadMemberCount(for: nextFamily.id)
                            }
                        }
                    } else if value.translation.width > threshold && currentIndex > 0 {
                        // 向右滑动，显示上一张卡片
                        currentIndex -= 1
                        offset = 0
                        
                        // 预加载上一张卡片的成员数量
                        if currentIndex >= 0 && currentIndex < families.count {
                            Task {
                                let prevFamily = families[currentIndex]
                                await appViewModel.familyManager.loadMemberCount(for: prevFamily.id)
                            }
                        }
                    } else {
                        // 回到原位
                        offset = 0
                    }
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
    private func familyCardView(for family: Family, at index: Int) -> some View {
        let isTopCard = index == currentIndex
        let memberCount = family.id == appViewModel.currentFamily?.id ?
            appViewModel.familyManager.memberCount : 0
        
        return VStack(spacing: 15) {
            // 放大族徽部分
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: family.isDefault ? "book.closed.fill" : "person.2.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.accentColor)
            }
            .padding(.top, 30)
            
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
            
            Spacer()
        }
        .padding(.vertical, 20)
        .frame(width: 300, height: 350)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
//        .overlay(
//            RoundedRectangle(cornerRadius: 20)
//                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
//        )
        .onAppear {
            if isTopCard {
                Task {
                    if family.id != appViewModel.currentFamily?.id {
                        await appViewModel.familyManager.loadMemberCount(for: family.id)
                    }
                }
            }
        }
    }
    
    // 创建家谱卡片视图 - 用于卡片堆叠效果
    private var createFamilyCardView: some View {
        VStack(spacing: 20) {
            // 图标
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.accentColor)
            }
            .padding(.top, 30)
            
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
            
            // 按钮 - 修改这里的点击事件
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
            .padding(.top, 20)
            
            Spacer()
        }
        .frame(width: 300, height: 350)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
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


