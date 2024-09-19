//
//  ChatView.swift
//  irl
//  TODO: for the AI name i want it to say the plugin name if a system prompt and plugin is in use i.e. Moo GPT not saying friend
//  make more imessage like
//
//  Created by Elijah Arbee on 9/5/24.
//
// TODO: a double \\ tap to resend if message fails, and the message if failed to look like on ios imessage, max tokens and temperature are shit and both incorrect from an gui interface but also in functionality.

// TODO: if message fails make the message box color red add a double tap to resend
// i want this to look more like imessage with the `plugins/bubbles` as the favorited contacts

//  Created by Elijah Arbee on 9/2/24.
import SwiftUI

// MARK: - Main Chat View
struct ChatView: View {
    @StateObject private var viewModel: ClaudeViewModel
    @State private var message: String = ""
    @State private var messages: [ChatMessage] = []
    @FocusState private var isInputFocused: Bool
    @State private var showParametersModal = false

    init() {
        _viewModel = StateObject(wrappedValue: ClaudeViewModel(apiClient: ClaudeAPIClient()))
    }

    var body: some View {
        ZStack {
            BackgroundView()
            VStack(spacing: 0) {
                ChatScrollView(messages: groupedMessages, onDelete: deleteMessage, onStash: stashMessage)
                InputView(message: $message, isInputFocused: $isInputFocused, onSend: sendMessage, isLoading: viewModel.isLoading)
            }
            ModalButton(showParametersModal: $showParametersModal)
        }
        .navigationTitle("Chat")
        .alert(item: Binding<AlertItem?>(
            get: { viewModel.error.map { AlertItem(message: $0) } },
            set: { _ in viewModel.error = nil }
        )) { alertItem in
            Alert(title: Text("Error"), message: Text(alertItem.message))
        }
        .sheet(isPresented: $showParametersModal) {
            ChatParametersModal(claudeViewModel: viewModel)
        }
        .onReceive(viewModel.$response) { response in
            if !response.isEmpty {
                appendFriendMessage(response)
            }
        }
    }
    
    // MARK: - Helper Methods
    private var groupedMessages: [(key: Date, value: [ChatMessage])] {
        messages.groupByDate()
    }

    private func sendMessage() {
        let userMessage = ChatMessage(content: message, isUser: true, timestamp: Date())
        messages.append(userMessage)
        viewModel.sendMessage(message)
        message = ""
        isInputFocused = false
    }

    private func appendFriendMessage(_ response: String) {
        let friendMessage = ChatMessage(content: response, isUser: false, timestamp: Date())
        messages.append(friendMessage)
    }

    private func deleteMessage(_ message: ChatMessage) {
        messages.removeAll(where: { $0.id == message.id })
    }

    private func stashMessage(_ message: ChatMessage) {
        // Implement stash functionality here
        print("Stashed message: \(message.content)")
    }
}

// MARK: - Modal Button View
struct ModalButton: View {
    @Binding var showParametersModal: Bool
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: { showParametersModal = true }) {
                    Image(systemName: "gear")
                        .foregroundColor(.blue)
                        .padding()
                }
            }
            Spacer()
        }
    }
}

// MARK: - Extensions for Message Grouping and Formatting
extension Array where Element == ChatMessage {
    func groupByDate() -> [(key: Date, value: [ChatMessage])] {
        let grouped = Dictionary(grouping: self) { message in
            Calendar.current.startOfDay(for: message.timestamp)
        }
        return grouped.sorted { $0.key < $1.key }
    }
}

extension Date {
    func formatForSeparator() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: self)
    }

    func formatTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

// MARK: - Background View
struct BackgroundView: View {
    var body: some View {
        Color.gray.opacity(0.1).edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Chat Scroll View
struct ChatScrollView: View {
    let messages: [(key: Date, value: [ChatMessage])]
    let onDelete: (ChatMessage) -> Void
    let onStash: (ChatMessage) -> Void
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(messages, id: \.key) { date, messagesForDate in
                    Section(header: DaySeparator(date: date)) {
                        ForEach(messagesForDate) { chatMessage in
                            MessageView(chatMessage: chatMessage)
                                .swipeActions(edge: .leading) {
                                    Button(action: { onStash(chatMessage) }) {
                                        Label("Stash", systemImage: "archivebox")
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive, action: { onDelete(chatMessage) }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Day Separator View
struct DaySeparator: View {
    let date: Date
    var body: some View {
        HStack {
            Capsule()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
                .overlay(
                    Text(date.formatForSeparator())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .background(Color.gray.opacity(0.1))
                )
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Message View
struct MessageView: View {
    let chatMessage: ChatMessage
    var body: some View {
        VStack(alignment: chatMessage.isUser ? .trailing : .leading, spacing: 8) {
            HStack {
                if chatMessage.isUser {
                    Spacer()
                }
                Text(chatMessage.isUser ? "You" : "Friend")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(chatMessage.timestamp.formatTime())
                    .font(.caption)
                    .foregroundColor(.secondary)
                if !chatMessage.isUser {
                    Spacer()
                }
            }
            Text(chatMessage.content)
                .padding()
                .background(chatMessage.isUser ? Color.blue : Color.white)
                .foregroundColor(chatMessage.isUser ? .white : .black)
                .cornerRadius(12)
                .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
        }
        .frame(maxWidth: .infinity, alignment: chatMessage.isUser ? .trailing : .leading)
    }
}

// MARK: - Input View
struct InputView: View {
    @Binding var message: String
    @FocusState.Binding var isInputFocused: Bool
    let onSend: () -> Void
    let isLoading: Bool
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                TextField("Type your message...", text: $message)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isInputFocused)
                    .padding(.horizontal)
                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(message.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(20)
                }
                .disabled(message.isEmpty || isLoading)
                .padding(.trailing)
            }
            .padding(.top)
            .background(Color.white)
            .cornerRadius(25)
            .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: -2)
            if isLoading {
                ProgressView()
                    .padding(.bottom)
            }
        }
        .padding(.vertical, 10)
        .background(Color.white)
    }
}

// MARK: - ChatMessage Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}

// MARK: - Helper Struct for Alerts
struct AlertItem: Identifiable {
    let id = UUID()
    let message: String
}
