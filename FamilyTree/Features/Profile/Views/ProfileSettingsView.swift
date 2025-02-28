import SwiftUI

struct ProfileSettingsView: View {
    var body: some View {
        List {
            Section("个人信息") {
                // 从原 ProfileView 迁移的内容
                NavigationLink {
                    Text("编辑个人信息")
                } label: {
                    Label("编辑个人信息", systemImage: "person.text.rectangle")
                }
                
                NavigationLink {
                    Text("隐私设置")
                } label: {
                    Label("隐私设置", systemImage: "hand.raised.fill")
                }
            }
            
            Section("应用设置") {
                // 从原 SettingsView 迁移的内容
                NavigationLink {
                    Text("通用设置")
                } label: {
                    Label("通用设置", systemImage: "gearshape")
                }
                
                NavigationLink {
                    Text("数据管理")
                } label: {
                    Label("数据管理", systemImage: "externaldrive")
                }
                
                NavigationLink {
                    Text("通知设置")
                } label: {
                    Label("通知设置", systemImage: "bell")
                }
            }
            
            Section("关于") {
                NavigationLink {
                    Text("关于应用")
                } label: {
                    Label("关于应用", systemImage: "info.circle")
                }
                
                NavigationLink {
                    Text("帮助与反馈")
                } label: {
                    Label("帮助与反馈", systemImage: "questionmark.circle")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileSettingsView()
    }
}