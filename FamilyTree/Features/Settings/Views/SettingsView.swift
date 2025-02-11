import SwiftUI

struct SettingsView: View {
    @AppStorage("useSystemTheme") private var useSystemTheme = true
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("showBirthdays") private var showBirthdays = true
    @AppStorage("showDeathDates") private var showDeathDates = true
    
    var body: some View {
        NavigationView {
            List {
                Section("显示设置") {
                    Toggle("使用系统主题", isOn: $useSystemTheme)
                    if !useSystemTheme {
                        Toggle("深色模式", isOn: $isDarkMode)
                    }
                    Toggle("显示生日信息", isOn: $showBirthdays)
                    Toggle("显示逝世信息", isOn: $showDeathDates)
                }
                
                Section("关于") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("关于家谱", systemImage: "info.circle")
                    }
                    
                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        Label("隐私政策", systemImage: "hand.raised")
                    }
                    
                    Link(destination: URL(string: "https://example.com/terms")!) {
                        Label("使用条款", systemImage: "doc.text")
                    }
                }
                
                Section {
                    Text("版本 1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
        }
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "tree")
                        .font(.system(size: 60))
                        .foregroundStyle(.tint)
                    
                    Text("家谱 App")
                        .font(.title2.bold())
                    
                    Text("版本 1.0.0")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            
            Section("开发者") {
                Text("Created with ❤️")
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("设置") {
    SettingsView()
}

#Preview("设置-深色") {
    SettingsView()
        .preferredColorScheme(.dark)
}

#Preview("关于") {
    NavigationView {
        AboutView()
    }
}