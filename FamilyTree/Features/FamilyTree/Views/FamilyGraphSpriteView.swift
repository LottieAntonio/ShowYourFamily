import SwiftUI
import SpriteKit
import UIKit

struct FamilyGraphSpriteView: View {
    @StateObject private var viewModel: FamilyGraphViewModel
    private let scene: FamilyGraphScene
    
    // 添加ID来解决视图重用问题
    private let viewID = UUID()
    
    init(familyTreeViewModel: FamilyTreeViewModel) {
        _viewModel = StateObject(wrappedValue: FamilyGraphViewModel(familyTreeViewModel: familyTreeViewModel))
        
        // 创建并配置场景
        let newScene = FamilyGraphScene()
        newScene.scaleMode = .resizeFill
        newScene.isUserInteractionEnabled = true  // 确保启用用户交互
        newScene.backgroundColor = .white  // 确保背景是白色
        self.scene = newScene
        
        print("FamilyGraphSpriteView initialized")
    }
    
    var body: some View {
        GeometryReader { geometry in
            SpriteView(scene: scene, options: [.allowsTransparency, .ignoresSiblingOrder])
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(Color.white)
                .allowsHitTesting(true)
                .id(viewID)
                .onAppear {
                    print("SpriteView appeared with size: \(geometry.size)")
                    scene.setupInitialView(with: geometry.size)
                    
                    // 确保数据只加载一次
                    Task {
                        if viewModel.graphData == nil {
                            await viewModel.loadData()
                            if let graphData = viewModel.graphData {
                                scene.updateGraph(with: graphData)
                                print("Graph data loaded and updated in onAppear")
                            }
                        } else if let graphData = viewModel.graphData {
                            scene.updateGraph(with: graphData)
                            print("Using existing graph data in onAppear")
                        }
                    }
                }
        }
        .edgesIgnoringSafeArea(.all)
        .background(Color.white)
        .onChange(of: viewModel.graphData) { _, newData in
            if let data = newData {
                scene.updateGraph(with: data)
                print("Graph data updated from onChange")
            }
        }
    }
}
