import SwiftUI

struct ProfileView: View {
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("未设置姓名")
                                .font(.headline)
                            Text("点击设置个人信息")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.vertical, 8)
                }
                
                Section("家谱统计") {
                    InfoRow(title: "家庭成员", value: "0人")
                    InfoRow(title: "家系代数", value: "1代")
                    InfoRow(title: "最后更新", value: Date().formatted())
                }
                
                Section("数据管理") {
                    Button("导出家谱数据") {
                        // TODO: 实现导出功能
                    }
                    Button("导入家谱数据") {
                        // TODO: 实现导入功能
                    }
                    Button("清空所有数据", role: .destructive) {
                        // TODO: 实现清空功能
                    }
                }
            }
            .navigationTitle("个人资料")
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview("个人资料") {
    ProfileView()
}

#Preview("个人资料-深色") {
    ProfileView()
        .preferredColorScheme(.dark)
}