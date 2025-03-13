import SwiftUI
import SpriteKit
import UIKit

struct FamilyGraphSpriteView: View {
    @EnvironmentObject var appViewModel: FamilyAppViewModel
    
    // 添加状态变量跟踪是否已加载数据
    @State private var hasLoadedData = false
    
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
        GeometryReader { geometry in
            SpriteView(scene: scene, options: [.allowsTransparency, .ignoresSiblingOrder])
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(Color.white)
                .allowsHitTesting(true)
                .onAppear {
                    scene.setupInitialView(with: geometry.size)
                    
                    // 修改防重复加载逻辑
                    Task {
                        // 只在有数据且未加载过的情况下更新图表
                        if let graphData = appViewModel.familyGraphViewModel.graphData {
                            scene.updateGraph(with: graphData)
                            hasLoadedData = true
                        }
                        // 不再在这里主动加载数据，由 ContentView 的 onChange 处理
                    }
                }
        }
        .id(appViewModel.currentFamily?.id ?? UUID())  // 使用当前家谱 ID
    }
}
