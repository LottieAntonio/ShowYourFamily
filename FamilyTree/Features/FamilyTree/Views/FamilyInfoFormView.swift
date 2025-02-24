import SwiftUI

struct FamilyInfoFormView: View {
    @Binding var isPresented: Bool
    let onComplete: (String, String) -> Void
    
    @State private var familyName: String = ""
    @State private var familyDescription: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("家谱名称", text: $familyName)
                    TextField("家谱描述", text: $familyDescription)
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        onComplete(familyName, familyDescription)
                        isPresented = false
                    }
                    .disabled(familyName.isEmpty)  // 移动到 Button 上
                }
            }
        }
    }
}