//
//  MessageView.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 04/11/23.
//

import OptionalKit
import SwiftUI
import SwiftUIIntrospect

struct MessageView: View {
    private var chat: Chat
    
    @Environment(\.modelContext) private var modelContext
    @Environment(MessageViewModel.self) private var messageViewModel
    @Environment(OllamaViewModel.self) private var ollamaViewModel
    
    @FocusState private var isInputFocused: Bool
    @State private var prompt: String = ""
    
    init(for chat: Chat) {
        self.chat = chat
    }
    
    var isGenerating: Bool {
        messageViewModel.generateViewState == .loading
    }
    
    var disabledPromptInput: Bool {
        if isGenerating { return true }
        if ollamaViewModel.checkConnectionViewState == .loading { return true }
        if ollamaViewModel.checkConnectionViewState == .error { return true }
        if let model = chat.model, model.isNotAvailable { return true }
        
        return false
    }
    
    var disabledSendButton: Bool {
        if prompt.isEmpty { return true }
        if isGenerating { return true }
        if ollamaViewModel.checkConnectionViewState == .loading { return true }
        if ollamaViewModel.checkConnectionViewState == .error { return true }
        if let model = chat.model, model.isNotAvailable { return true }
        
        return false
    }
    
    var body: some View {
        ScrollViewReader { scrollViewProxy in
            List(messageViewModel.messages) { message in
                MessageListItemView(
                    message.prompt ?? "",
                    isAssistant: false
                )
                
                MessageListItemView(
                    message.response ?? "",
                    isAssistant: true,
                    isGenerating: message.response.isNil && isGenerating
                )
                .id(message)
            }
            .onAppear {
                scrollToBottom(scrollViewProxy, messages: messageViewModel.messages)
            }
            .onChange(of: messageViewModel.messages) { _, newMessages in
                scrollToBottom(scrollViewProxy, messages: newMessages)
            }
            .onChange(of: messageViewModel.messages.last?.response?.count) {
                scrollToBottom(scrollViewProxy, messages: messageViewModel.messages)
            }
            
            VStack(spacing: 8) {
                HStack(alignment: .bottom, spacing: 16) {
                    TextEditor(text: $prompt)
                        .introspect(.textEditor, on: .macOS(.v14)) { textView in
                            textView.enclosingScrollView?.hasVerticalScroller = false
                            textView.enclosingScrollView?.hasHorizontalScroller = false
                            textView.backgroundColor = .clear
                            textView.isEditable = !self.disabledPromptInput
                        }
                        .padding(8)
                        .lineSpacing(8)
                        .font(.title3.weight(.regular))
                        .frame(minHeight: 32, maxHeight: 256)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(
                            RoundedRectangle(cornerRadius: 6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor))
                        )
                        .focused($isInputFocused)
                        .onChange(of: messageViewModel.generateViewState) { _, newState in
                            isInputFocused = newState.isNil
                        }
                    
                    Button(action: send) {
                        Label("Send", systemImage: "paperplane")
                            .foregroundStyle(.white)
                            .padding(8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(disabledSendButton)
                }
                .padding(.horizontal)
                
                if ollamaViewModel.checkConnectionViewState == .loading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.mini)
                            .progressViewStyle(.circular)
                        
                        Text("Checking connection...")
                            .foregroundStyle(.secondary)
                    }
                } else if ollamaViewModel.checkConnectionViewState == .error {
                    HStack(alignment: .center) {
                        Text(Constants.ollamaConnectionErrorMessage)
                        
                        Button("Check Again") { self.initialize(for: chat) }
                            .buttonStyle(.plain)
                            .foregroundStyle(.accent)
                    }
                    .foregroundStyle(.secondary)
                } else if let model = chat.model, model.isNotAvailable {
                    Text(Constants.modelNotAvailableErrorMessage)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .navigationTitle(chat.name)
        .navigationSubtitle(chat.model?.name ?? "")
        .task {
            self.initialize(for: chat)
        }
        .onChange(of: chat) { _, newChat in
            self.initialize(for: newChat)
        }
    }
    
    private func initialize(for chat: Chat) {
        Task {
            await ollamaViewModel.checkConnection()
            await ollamaViewModel.fetch()
        }
        
        messageViewModel.fetch(for: chat)
        isInputFocused = true
    }
    
    private func send() {
        let message = Message(prompt: prompt, response: nil)
        message.chat = chat
        message.context = messageViewModel.messages.last?.context ?? []
        
        Task {
            await messageViewModel.generate(message)
        }
        
        prompt = ""
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy, messages: [Message]) {
        guard messages.count > 0 else { return }
        let lastIndex = messages.count - 1
        let lastMessage = messages[lastIndex]
        
        proxy.scrollTo(lastMessage, anchor: .bottom)
    }
}