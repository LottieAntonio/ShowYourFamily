import SwiftUI

struct PersonEventsSection: View {
    @ObservedObject var viewModel: PersonCardViewModel
    @State private var showingAddEvent = false
    @State private var newEventType = LifeEvent.EventType.birth
    @State private var newEventDate = Date()
    @State private var newEventLocation = ""
    @State private var newEventDescription = ""
    
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10)
                .foregroundStyle(Color.red.opacity(0.1))
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("生活事件")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if viewModel.isEditable {
                        Button(action: { showingAddEvent = true }) {
                            Label("添加事件", systemImage: "plus.circle")
                        }
                    }
                }
                
                if viewModel.state.events.isEmpty {
                    Text("暂无生活事件")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.state.events) { event in
                        EventRow(event: event)
                    }
                }
            }
            .padding(30)
            .sheet(isPresented: $showingAddEvent) {
                NavigationView {
                    Form {
                        Picker("事件类型", selection: $newEventType) {
                            ForEach(LifeEvent.EventType.allCases, id: \.self) { type in
                                Text(type.description).tag(type)
                            }
                        }
                        
                        DatePicker("日期", selection: $newEventDate)
                        
                        TextField("地点", text: $newEventLocation)
                        
                        TextField("描述", text: $newEventDescription, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    .navigationTitle("添加事件")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                showingAddEvent = false
                            }
                        }
                        
                        ToolbarItem(placement: .confirmationAction) {
                            Button("添加") {
                                addEvent()
                            }
                            .disabled(newEventDescription.isEmpty)
                        }
                    }
                }
            }
        }
    }
    
    private func addEvent() {
        let event = LifeEvent(
            type: newEventType,
            date: newEventDate,
            location: newEventLocation.isEmpty ? nil : newEventLocation,
            description: newEventDescription
        )
        viewModel.updateEvents(viewModel.state.events + [event])
        showingAddEvent = false
        
        // 重置表单
        newEventType = .birth
        newEventDate = Date()
        newEventLocation = ""
        newEventDescription = ""
    }
}

private struct EventRow: View {
    let event: LifeEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.type.description)
                    .font(.subheadline.bold())
                
                Spacer()
                
                Text(event.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if let location = event.location {
                Text(location)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text(event.description ?? "")
                .font(.body)
        }
        .padding()
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

