import SwiftUI
import SpriteKit
import UIKit

struct FamilyGraphSpriteView: View {
    @EnvironmentObject var appViewModel: FamilyAppViewModel
    
    private static var sharedScene: FamilyGraphScene = {
        let scene = FamilyGraphScene()
        scene.scaleMode = .resizeFill
        scene.isUserInteractionEnabled = true
        scene.backgroundColor = .white
        print("创建共享 FamilyGraphScene 实例")
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
                    print("SpriteView appeared with size: \(geometry.size)")
                    scene.setupInitialView(with: geometry.size)
                    
                    // 添加防重复加载逻辑
                    Task {
                        if appViewModel.familyGraphViewModel.graphData == nil {
                            await appViewModel.familyGraphViewModel.loadData()
                        } else {
                            if let graphData = appViewModel.familyGraphViewModel.graphData {
                                scene.updateGraph(with: graphData)
                            }
                        }
                    }
                }
        }
        .id(appViewModel.currentFamily?.id ?? UUID())  // 使用当前家谱 ID
    }
}
