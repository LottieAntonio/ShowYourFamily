import SwiftUI

struct PersonStoriesSection: View {
    @ObservedObject var viewModel: PersonCardViewModel
    @State private var showingAddStory = false
    @State private var newStoryTitle = ""
    @State private var newStoryContent = ""
    @State private var newStoryDate = Date()
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .foregroundStyle(Color.red.opacity(0.1))
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("生活故事")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if viewModel.isEditable {
                        Button(action: { showingAddStory = true }) {
                            Label("添加故事", systemImage: "plus.circle")
                        }
                    }
                }
                
                if viewModel.state.stories.isEmpty {
                    Text("暂无生活故事")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.state.stories) { story in
                        StoryRow(story: story)
                    }
                }
            }
            .padding(30)
            .sheet(isPresented: $showingAddStory) {
                NavigationView {
                    Form {
                        TextField("标题", text: $newStoryTitle)
                        
                        DatePicker("日期", selection: $newStoryDate)
                        
                        TextField("内容", text: $newStoryContent, axis: .vertical)
                            .lineLimit(5...10)
                    }
                    .navigationTitle("添加故事")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                showingAddStory = false
                            }
                        }
                        
                        ToolbarItem(placement: .confirmationAction) {
                            Button("添加") {
                                addStory()
                            }
                            .disabled(newStoryTitle.isEmpty || newStoryContent.isEmpty)
                        }
                    }
                }
            }
        }
    }
    
    private func addStory() {
        let story = Story(
            title: newStoryTitle,
            content: newStoryContent,
            date: newStoryDate
        )
        viewModel.updateStories(viewModel.state.stories + [story])
        showingAddStory = false
        
        // 重置表单
        newStoryTitle = ""
        newStoryContent = ""
        newStoryDate = Date()
    }
}

private struct StoryRow: View {
    let story: Story
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(story.title)
                    .font(.headline)
                
                Spacer()
                
                Text(story.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text(story.content)
                .font(.body)
        }
        .padding()
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

