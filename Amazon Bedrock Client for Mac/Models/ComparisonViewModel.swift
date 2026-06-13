//
//  ComparisonViewModel.swift
//  Amazon Bedrock Client for Mac
//

import SwiftUI
import Combine
import Logging

// MARK: - Persistence Model

struct PersistedComparison: Codable {
    let id: String
    let createdAt: Date
    var hasInitialPrompt: Bool
    var panes: [PersistedPane]

    struct PersistedPane: Codable {
        let chatId: String
        let modelId: String
        let modelName: String
        let modelProvider: String
    }
}

// MARK: - Comparison Store

@MainActor
class ComparisonStore {
    static let shared = ComparisonStore()
    private init() {}

    private var fileURL: URL {
        let base = URL(fileURLWithPath: SettingManager.shared.defaultDirectory)
        return base.appendingPathComponent("comparisons.json")
    }

    func save(comparisons: [ComparisonEntry], viewModels: [String: ComparisonViewModel]) {
        let persisted = comparisons.compactMap { entry -> PersistedComparison? in
            guard let vm = viewModels[entry.id] else { return nil }
            return vm.toPersistedComparison(createdAt: entry.createdAt)
        }

        do {
            let data = try JSONEncoder().encode(persisted)
            try data.write(to: fileURL, options: .atomic)
        } catch {}
    }

    func load() -> [PersistedComparison] {
        guard let data = try? Data(contentsOf: fileURL),
              let persisted = try? JSONDecoder().decode([PersistedComparison].self, from: data) else {
            return []
        }
        return persisted
    }
}

// MARK: - View Model

@MainActor
class ComparisonViewModel: ObservableObject {
    let comparisonId: String
    let backendModel: BackendModel
    let chatManager: ChatManager

    @Published var panes: [ComparisonPane] = []
    @Published var focusedPaneIndex: Int = 0
    @Published var userInput: String = ""
    @Published var hasInitialPrompt: Bool = false

    private var logger = Logger(label: "ComparisonViewModel")
    private var cancellables: Set<AnyCancellable> = []

    struct ComparisonPane: Identifiable {
        let id: String
        let chatId: String
        let modelId: String
        let modelName: String
        let modelProvider: String
        let viewModel: ChatViewModel
        let sharedMediaDataSource: SharedMediaDataSource
    }

    var modelNames: String {
        panes.map { $0.modelName }.joined(separator: " vs ")
    }

    init(comparisonId: String, backendModel: BackendModel, chatManager: ChatManager = .shared) {
        self.comparisonId = comparisonId
        self.backendModel = backendModel
        self.chatManager = chatManager
    }

    func addModel(_ model: ChatModel) {
        let mediaDataSource = SharedMediaDataSource()
        let newChat = chatManager.createHiddenChat(
            modelId: model.id,
            modelName: model.name,
            modelProvider: model.provider
        )

        let vm = ChatViewModel(
            chatId: newChat.chatId,
            backendModel: backendModel,
            sharedMediaDataSource: mediaDataSource
        )

        let pane = ComparisonPane(
            id: newChat.chatId,
            chatId: newChat.chatId,
            modelId: model.id,
            modelName: model.name,
            modelProvider: model.provider,
            viewModel: vm,
            sharedMediaDataSource: mediaDataSource
        )

        panes.append(pane)
        observePane(vm)
    }

    func restorePane(chatId: String, modelId: String, modelName: String, modelProvider: String) {
        let mediaDataSource = SharedMediaDataSource()
        _ = chatManager.restoreHiddenChat(
            chatId: chatId,
            modelId: modelId,
            modelName: modelName,
            modelProvider: modelProvider
        )

        let vm = ChatViewModel(
            chatId: chatId,
            backendModel: backendModel,
            sharedMediaDataSource: mediaDataSource
        )
        vm.loadInitialData()

        let pane = ComparisonPane(
            id: chatId,
            chatId: chatId,
            modelId: modelId,
            modelName: modelName,
            modelProvider: modelProvider,
            viewModel: vm,
            sharedMediaDataSource: mediaDataSource
        )

        panes.append(pane)
        observePane(vm)
    }

    private func observePane(_ vm: ChatViewModel) {
        vm.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func removePane(at index: Int) {
        guard index < panes.count else { return }
        let pane = panes[index]
        chatManager.deleteHiddenChat(chatId: pane.chatId)
        panes.remove(at: index)
        if focusedPaneIndex >= panes.count {
            focusedPaneIndex = max(0, panes.count - 1)
        }
    }

    func sendToAll() {
        guard !userInput.isEmpty else { return }
        let message = userInput
        userInput = ""
        hasInitialPrompt = true

        for pane in panes {
            pane.viewModel.sendMessage(message)
        }
    }

    func sendToFocused() {
        guard !userInput.isEmpty, focusedPaneIndex < panes.count else { return }
        let message = userInput
        userInput = ""

        panes[focusedPaneIndex].viewModel.sendMessage(message)
    }

    func toPersistedComparison(createdAt: Date) -> PersistedComparison {
        PersistedComparison(
            id: comparisonId,
            createdAt: createdAt,
            hasInitialPrompt: hasInitialPrompt,
            panes: panes.map {
                PersistedComparison.PersistedPane(
                    chatId: $0.chatId,
                    modelId: $0.modelId,
                    modelName: $0.modelName,
                    modelProvider: $0.modelProvider
                )
            }
        )
    }
}
