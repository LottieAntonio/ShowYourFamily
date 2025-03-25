import SwiftUI
import SpriteKit
import UIKit

// 修改 SpriteKitView 结构体，添加 onUpdate 回调
struct SpriteKitView: UIViewControllerRepresentable {
    var scene: SKScene
    var onSetup: ((SKView) -> Void)?
    var onUpdate: ((SKView) -> Void)?  // 添加更新回调
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let skView = SKView(frame: UIScreen.main.bounds)
        skView.presentScene(scene)
        skView.ignoresSiblingOrder = true
        skView.allowsTransparency = true
        skView.backgroundColor = .white
        
        viewController.view = skView
        onSetup?(skView)
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // 更新逻辑
        if let skView = uiViewController.view as? SKView {
            onUpdate?(skView)
        }
    }
}

struct FamilyGraphSpriteView: View {
    @EnvironmentObject var appViewModel: FamilyAppViewModel
    
    // 添加状态变量跟踪是否已加载数据
    @State private var hasLoadedData = false
    
    // 添加筛选相关状态
    @State private var selectedCategories: [RelationCategory] = [.paternal, .children] // 修改默认选项为父系和子女
    @State private var displayDepth: Int = 1 // 修改默认深度为1代
    @State private var showFilterOptions = false
    
    // 添加浮动按钮状态
    @State private var showFilterButton = true
    
    // 添加当前选中人物的状态，用于触发更新
    @State private var currentPersonId: UUID?
    
    private static var sharedScene: FamilyGraphScene = {
        let scene = FamilyGraphScene()
        scene.scaleMode = .resizeFill
        scene.isUserInteractionEnabled = true
        scene.backgroundColor = .white
        return scene
    }()
    
    // 添加访问器
    private var scene: FamilyGraphScene {
        Self.sharedScene
    }
    
    var body: some View {
        ZStack {
            // 使用自定义的 SpriteKit 视图，添加 onUpdate 回调
            SpriteKitView(scene: scene, 
                          onSetup: { skView in
                // 在这里设置 SKView 的其他属性
                if let size = skView.window?.bounds.size {
                    scene.setupInitialView(with: size)
                }
                
                // 初始加载数据
                updateGraphWithCurrentPerson()
                
                // 确保初始视图能够自动缩放
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    scene.zoomToFitContent()
                }
            },
                          onUpdate: { _ in
                // 检查当前人物是否变化
                if currentPersonId != appViewModel.familyGraphViewModel.selectedPerson?.id {
                    print("检测到人物变化: \(String(describing: appViewModel.familyGraphViewModel.selectedPerson?.name))")
                    updateGraphWithCurrentPerson()
                }
            })
            
            // 空状态提示
            if appViewModel.familyGraphViewModel.filteredGraphData?.isEmpty == true {
                VStack {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                        .padding()
                    
                    Text("当前筛选条件下没有亲属关系")
                        .foregroundColor(.gray)
                    
                    Button("重置筛选") {
                        selectedCategories = [.all]
                        displayDepth = 3
                        applyFilter()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top)
                }
                .padding()
                .background(Color.white.opacity(0.9))
                .cornerRadius(12)
                .shadow(radius: 5)
            }
            
            // 添加浮动筛选按钮 - 放在右下角
            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        showFilterOptions = true
                    }) {
                        HStack {
                            Text("\(displayDepth)代")
                                .font(.system(size: 14))
                            Image(systemName: "line.horizontal.3.decrease.circle.fill")
                                .font(.system(size: 20))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                    }
                }
            }
            .padding(.bottom, 100) // 确保不会被 TabBar 遮挡
        }
        .id(appViewModel.currentFamily?.id ?? UUID())
        .sheet(isPresented: $showFilterOptions) {
            filterOptionsView
        }
        .onChange(of: appViewModel.familyGraphViewModel.selectedPerson?.id) { newValue in
            // 当选中人物变化时，更新图谱
            print("onChange 检测到人物变化: \(String(describing: newValue))")
            updateGraphWithCurrentPerson()
        }
        .onAppear {
            // 视图出现时也更新图谱
            print("视图出现，更新图谱")
            updateGraphWithCurrentPerson()
        }
    }
    
    // 添加一个方法来更新图谱
    private func updateGraphWithCurrentPerson() {
        if let currentPerson = appViewModel.familyGraphViewModel.selectedPerson {
            // 更新当前人物ID
            currentPersonId = currentPerson.id
            
            // 打印日志，帮助调试
            print("更新图谱: \(currentPerson.name), ID: \(currentPerson.id)")
            
            // 获取图谱数据
            if let graphData = appViewModel.familyGraphViewModel.filteredGraphData ?? appViewModel.familyGraphViewModel.graphData {
                // 更新筛选设置
                scene.updateFilter(categories: selectedCategories, depth: displayDepth)
                // 更新图谱
                scene.updateGraph(with: graphData)
                // 添加自动缩放到适合屏幕的代码
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    scene.zoomToFitContent()
                }
                hasLoadedData = true
            } else {
                print("图谱数据为空")
                // 强制触发 ViewModel 更新图谱数据
                appViewModel.familyGraphViewModel.forceUpdateGraphData()
            }
        } else {
            print("当前选中人物为空")
        }
    }
    
    // 筛选选项视图
    private var filterOptionsView: some View {
        NavigationView {
            Form {
                Section(header: Text("关系类型")) {
                    // 删除全部选项，直接显示各个类别
                    ForEach(RelationCategory.allCases.filter { $0 != .all }, id: \.self) { category in
                        Toggle(category.rawValue, isOn: Binding(
                            get: { selectedCategories.contains(category) },
                            set: { newValue in
                                if newValue {
                                    selectedCategories.append(category)
                                } else {
                                    selectedCategories.removeAll { $0 == category }
                                }
                            }
                        ))
                    }
                }
                
                Section(header: Text("显示深度")) {
                    Picker("显示几代亲属", selection: $displayDepth) {
                        ForEach(1...5, id: \.self) { depth in
                            Text("\(depth)代").tag(depth)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle("筛选选项")
            .navigationBarItems(
                leading: Button("取消") {
                    showFilterOptions = false
                },
                trailing: Button("应用") {
                    applyFilter()
                    showFilterOptions = false
                }
            )
        }
    }
    
    // 应用筛选方法
    private func applyFilter() {
        // 确保至少选择了一个类别
        if selectedCategories.isEmpty {
            // 如果没有选择任何类别，默认选择父系和子女
            selectedCategories = [.paternal, .children]
        }
        
        // 更新场景的筛选设置
        scene.updateFilter(categories: selectedCategories, depth: displayDepth)
        
        // 更新 ViewModel 的筛选设置
        appViewModel.familyGraphViewModel.updateFilter(categories: selectedCategories, depth: displayDepth)
    }
}
