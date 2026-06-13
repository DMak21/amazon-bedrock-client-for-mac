//
//  SidebarView.swift
//  Amazon Bedrock Client for Mac
//
//  Created by Na, Sanghwa on 2023/10/06.
//

import SwiftUI
import AppKit
import Logging

// MARK: - Chat Search Index

/// Optimized search index for O(log n) chat content searching with relevance scoring
@MainActor
class ChatSearchIndex: ObservableObject {
    static let shared = ChatSearchIndex()
    
    // Map of chat IDs to indexed chat content tokens
    var chatIndexMap: [String: Set<String>] = [:]
    private var _chatIndexMap: [String: Set<String>] = [:]

    // Inverted index: keyword -> chat IDs that contain it
    var keywordIndex: [String: Set<String>] = [:]
    private var _keywordIndex: [String: Set<String>] = [:]
    
    // Chat metadata for relevance scoring
    var chatMetadata: [String: ChatMetadata] = [:]
    
    // Track indexed chats to avoid reindexing
    var indexedChatIds: Set<String> = []
    var lastIndexUpdate: Date = Date.distantPast
    
    // Minimum word length for indexing (1 to catch single character searches)
    private let minWordLength = 1
    
    private init() {} // Singleton pattern
    
    struct ChatMetadata {
        let title: String
        let modelName: String
        let messageCount: Int
        let lastMessageDate: Date
        let totalTextLength: Int
    }

    func updateIndexDirect(chatIndexMap: [String: Set<String>], keywordIndex: [String: Set<String>]) {
        self.chatIndexMap = chatIndexMap
        self.keywordIndex = keywordIndex
    }
    
    /// Updates the search index with current chats and their content - optimized to avoid unnecessary reindexing
    func updateIndex(chats: [ChatModel], chatManager: ChatManager) {
        let currentChatIds = Set(chats.map { $0.chatId })
        
        // Force update if we have no indexed chats or if chats have changed significantly
        let needsUpdate = indexedChatIds.isEmpty || 
                         currentChatIds != indexedChatIds || 
                         Date().timeIntervalSince(lastIndexUpdate) > 300 // 5 minutes
        
        if !needsUpdate {
            return // Skip reindexing if nothing changed
        }
        
        // For simplicity and reliability, do a full reindex when there are changes
        var newChatIndexMap: [String: Set<String>] = [:]
        var newKeywordIndex: [String: Set<String>] = [:]
        var newChatMetadata: [String: ChatMetadata] = [:]
        
        // Index all current chats
        for chat in chats {
            indexSingleChat(chat, chatManager: chatManager, 
                          chatIndexMap: &newChatIndexMap, 
                          keywordIndex: &newKeywordIndex, 
                          chatMetadata: &newChatMetadata)
        }
        
        // Update class properties
        chatIndexMap = newChatIndexMap
        keywordIndex = newKeywordIndex
        chatMetadata = newChatMetadata
        indexedChatIds = currentChatIds
        lastIndexUpdate = Date()
    }
    
    /// Index a single chat - extracted for reuse
    private func indexSingleChat(_ chat: ChatModel, 
                               chatManager: ChatManager,
                               chatIndexMap: inout [String: Set<String>],
                               keywordIndex: inout [String: Set<String>],
                               chatMetadata: inout [String: ChatMetadata]) {
        // Get chat messages
        let messages = chatManager.getMessages(for: chat.chatId)
        
        // Index chat title and model name with higher weight
        var searchableContent = "\(chat.title.lowercased()) \(chat.name.lowercased())"
        var totalTextLength = searchableContent.count
        
        // Add message content
        for message in messages {
            let messageText = message.text.lowercased()
            searchableContent += " \(messageText)"
            totalTextLength += messageText.count
        }
        
        // Tokenize content into words for faster searching
        let words = searchableContent
            .split { !$0.isLetter && !$0.isNumber }
            .map { String($0) }
            .filter { $0.count >= minWordLength }
        
        // Store tokenized content
        let wordSet = Set(words)
        chatIndexMap[chat.chatId] = wordSet
        
        // Store metadata for relevance scoring
        chatMetadata[chat.chatId] = ChatMetadata(
            title: chat.title,
            modelName: chat.name,
            messageCount: messages.count,
            lastMessageDate: chat.lastMessageDate,
            totalTextLength: totalTextLength
        )
        
        // Update inverted index
        for word in wordSet {
            if keywordIndex[word] == nil {
                keywordIndex[word] = []
            }
            keywordIndex[word]?.insert(chat.chatId)
        }
    }
    
    /// Performs optimized search with relevance scoring
    func search(query: String) -> [String] {
        if query.isEmpty {
            // Return all chats sorted by last message date
            return chatMetadata.keys.sorted { chatId1, chatId2 in
                let date1 = chatMetadata[chatId1]?.lastMessageDate ?? Date.distantPast
                let date2 = chatMetadata[chatId2]?.lastMessageDate ?? Date.distantPast
                return date1 > date2
            }
        }
        
        // Normalize query for better matching
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Calculate relevance scores for each chat
        var chatScores: [String: Double] = [:]
        
        for (chatId, words) in chatIndexMap {
            guard let metadata = chatMetadata[chatId] else { continue }
            
            var score = 0.0
            
            // Check title match (highest priority)
            let titleLower = metadata.title.lowercased()
            if titleLower.contains(normalizedQuery) {
                score += 100.0
            }
            
            // Check model name match
            let modelLower = metadata.modelName.lowercased()
            if modelLower.contains(normalizedQuery) {
                score += 50.0
            }
            
            // Check word matches in content
            for word in words {
                if word.contains(normalizedQuery) {
                    if word == normalizedQuery {
                        score += 20.0 // Exact match
                    } else if word.hasPrefix(normalizedQuery) {
                        score += 10.0 // Prefix match
                    } else {
                        score += 5.0 // Contains match
                    }
                }
            }
            
            // Add recency bonus if there's any match
            if score > 0 {
                let daysSinceLastMessage = Date().timeIntervalSince(metadata.lastMessageDate) / (24 * 60 * 60)
                let recencyBonus = max(0, 5.0 - daysSinceLastMessage * 0.1)
                score += recencyBonus
                
                chatScores[chatId] = score
            }
        }
        
        // Sort by relevance score (highest first)
        return chatScores.keys.sorted { chatId1, chatId2 in
            let score1 = chatScores[chatId1] ?? 0
            let score2 = chatScores[chatId2] ?? 0
            return score1 > score2
        }
    }
}

struct SidebarView: View {
    // MARK: - Properties

    @Binding var selection: SidebarSelection?
    @Binding var menuSelection: SidebarSelection?
    @Binding var organizedChatModels: [String: [ChatModel]]
    @Binding var comparisons: [ComparisonEntry]
    var comparisonViewModels: [String: ComparisonViewModel]
    var onNewChat: () -> Void
    var onNewComparison: () -> Void
    var onDeleteComparison: ((String) -> Void)?
    @ObservedObject var chatManager: ChatManager = ChatManager.shared
    @ObservedObject var appCoordinator = AppCoordinator.shared

    private let logger = Logger(label: "SidebarView")

    @State private var showingClearChatAlert = false
    @State private var organizedChatsByDate: [String: [ChatModel]] = [:]
    @State private var selectionId = UUID()
    @State private var hoverStates: [String: Bool] = [:]
    @State private var searchText: String = ""
    @State private var searchIndex = ChatSearchIndex.shared
    @State private var searchResults: [String] = []
    @State private var isSearching: Bool = false
    @State private var searchDebounceTimer: Timer?
    @State private var hasInitiatedSearch: Bool = false
    @State private var renamingChatId: String? = nil
    @State private var renameText: String = ""
    @State private var isNewChatHovered = false
    @FocusState private var renamingTextfieldFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    // Performance optimization properties
    @State private var lastSortTime: Date = Date(timeIntervalSince1970: 0)
    @State private var sortingInProgress: Bool = false
    private let sortingThrottleInterval: TimeInterval = 0.5

    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM dd, yyyy"
        return formatter
    }()
    

    
    // Keys sorted by date for grouping chats
    private var sortedDateKeys: [String] {
        // Create a mapping of display keys to actual dates for proper sorting
        var keyToDateMap: [String: Date] = [:]

        for key in organizedChatsByDate.keys {
            // Try to parse the key back to a date
            if let date = dateFormatter.date(from: key) {
                keyToDateMap[key] = date
            } else {
                // Handle special cases like "Today" and "Yesterday"
                let calendar = Calendar.current
                if key == "Today" {
                    keyToDateMap[key] = calendar.startOfDay(for: Date())
                } else if key == "Yesterday" {
                    if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) {
                        keyToDateMap[key] = calendar.startOfDay(for: yesterday)
                    }
                }
            }
        }
        
        // Sort by actual dates (most recent first)
        return keyToDateMap.keys.sorted { key1, key2 in
            let date1 = keyToDateMap[key1] ?? Date.distantPast
            let date2 = keyToDateMap[key2] ?? Date.distantPast
            return date1 > date2
        }
    }
    
    // Filtered chat models based on search results
    private var filteredChatModels: [String: [ChatModel]] {
        if searchText.isEmpty {
            return organizedChatsByDate
        }

        var filtered: [String: [ChatModel]] = [:]

        for (dateKey, chats) in organizedChatsByDate {
            let filteredChats = chats.filter { chat in
                searchResults.contains(chat.chatId)
            }

            if !filteredChats.isEmpty {
                filtered[dateKey] = filteredChats
            }
        }

        return filtered
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            searchBarView
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, 2)
                .padding(.bottom, DS.Spacing.xs)

            chatListView
                .onReceive(timer) { _ in
                    if Date().timeIntervalSince(lastSortTime) > 10 {
                        throttledOrganizeChatsByDate()
                    }
                }
                .onChange(of: appCoordinator.shouldCreateNewChat) { _, newValue in
                    if newValue {
                        appCoordinator.shouldCreateNewChat = false
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            self.createNewChat()
                        }
                    }
                }
                .onChange(of: appCoordinator.shouldDeleteChat) { _, newValue in
                    if newValue {
                        deleteSelectedChat()
                        appCoordinator.shouldDeleteChat = false
                    }
                }
                .id(selectionId)
                .listStyle(SidebarListStyle())
                .frame(minWidth: 100, idealWidth: 250, maxWidth: .infinity, maxHeight: .infinity)

            // MARK: - New Chat Footer
            newChatFooterView
        }
        .background(Color.surface0.opacity(0.8))
        .onAppear {
            organizeChatsInitial()
        }
        .onChange(of: chatManager.chats) { oldChats, newChats in
            if oldChats.count != newChats.count {
                let calendar = Calendar.current
                let sortedChats = newChats.sorted { $0.lastMessageDate > $1.lastMessageDate }
                let groupedChats = Dictionary(grouping: sortedChats) { chat -> DateComponents in
                    calendar.dateComponents([.year, .month, .day], from: chat.lastMessageDate)
                }

                let sortedDateComponents = groupedChats.keys.sorted {
                    if $0.year != $1.year {
                        return $0.year! > $1.year!
                    } else if $0.month != $1.month {
                        return $0.month! > $1.month!
                    } else {
                        return $0.day! > $1.day!
                    }
                }

                var newOrganizedModels: [String: [ChatModel]] = [:]
                for components in sortedDateComponents {
                    if let date = calendar.date(from: components) {
                        let key = self.formatDate(date)
                        if let chatsForDate = groupedChats[components] {
                            newOrganizedModels[key] = chatsForDate
                        }
                    }
                }

                self.organizedChatsByDate = newOrganizedModels
            }
        }
        .onChange(of: searchText) { _, newValue in
            if !newValue.isEmpty && !hasInitiatedSearch {
                hasInitiatedSearch = true
                Task(priority: .background) {
                    await MainActor.run {
                        updateSearchIndexIfNeeded()
                    }
                }
            }
            performSearch()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: Amazon_Bedrock_Client_for_MacApp.toggleSidebar) {
                    Label("Toggle Sidebar", systemImage: "sidebar.left")
                        .help("Toggle Sidebar")
                }
            }
        }
    }

    // MARK: - New Chat Footer
    private var newChatFooterView: some View {
        HStack(spacing: DS.Spacing.sm) {
            Button(action: onNewChat) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text(newChatLabel)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isNewChatHovered ? Color.accent.opacity(0.12) : Color.surface2)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.border.opacity(0.4), lineWidth: 0.5)
                )
                .foregroundStyle(Color.accent)
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                withAnimation(.hover) {
                    isNewChatHovered = hovering
                }
            }

            Button(action: onNewComparison) {
                Image(systemName: "rectangle.split.3x1")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.surface2)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.border.opacity(0.4), lineWidth: 0.5)
                    )
                    .foregroundStyle(Color.accent)
            }
            .buttonStyle(PlainButtonStyle())
            .help("New model comparison")
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }

    private var newChatLabel: String {
        if case .chat(let model) = menuSelection {
            return "New \(model.name) Chat"
        }
        return "New Chat"
    }
    
    // MARK: - Search Bar View
    
    /// Enhanced search bar for filtering chats (Messages app style - compact)
    private var searchBarView: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 13))
            
            TextField("Search", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 13))
            
            if isSearching {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
            } else if !searchText.isEmpty {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        searchText = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.opacity)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .modifier(LiquidGlassSearchBarModifier(colorScheme: colorScheme))
    }
    
    // MARK: - Chat List View
    
    /// Enhanced chat list view
    private var chatListView: some View {
        List {
            if !comparisons.isEmpty {
                Section(header:
                    Text("Comparisons")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                ) {
                    ForEach(comparisons) { entry in
                        comparisonRowView(for: entry)
                    }
                }
            }

            ForEach(sortedDateKeys, id: \.self) { dateKey in
                if let chats = filteredChatModels[dateKey], !chats.isEmpty {
                    Section(header:
                                Text(dateKey)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                    ) {
                        ForEach(chats, id: \.self) { chat in
                            chatRowView(for: chat)
                        }
                    }
                }
            }
            
            if !searchText.isEmpty && searchResults.isEmpty {
                if isSearching {
                    Text("Indexing chats for search...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text("No matching chats found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .modifier(ScrollEdgeEffectModifier())
        .contextMenu {
            Button("Delete All Chats", action: {
                showingClearChatAlert = true
            })
        }
        .alert(isPresented: $showingClearChatAlert) {
            Alert(
                title: Text("Delete all messages"),
                message: Text("This will delete all chat histories"),
                primaryButton: .destructive(Text("Delete")) {
                    chatManager.clearAllChats()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    // MARK: - Chat Row View

    func chatRowView(for chat: ChatModel) -> some View {
        let isHovered = hoverStates[chat.chatId, default: false]
        let isSelected = selection == .chat(chat)
        let isRenaming = renamingChatId == chat.chatId
        let isLoading = chatManager.getIsLoading(for: chat.chatId)

        return HStack(spacing: 0) {
            // Active indicator bar
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? Color.accent : Color.clear)
                .frame(width: 3)
                .padding(.vertical, 6)

            HStack(spacing: 10) {
                // Model avatar
                ModelImageHelper.getImage(for: chat.id)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.border.opacity(0.3), lineWidth: 0.5)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    if isRenaming {
                        TextField("Chat title", text: $renameText)
                            .font(.system(size: 13, weight: .medium))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($renamingTextfieldFocused)
                            .onSubmit { finishRenaming(chat) }
                            .onExitCommand { cancelRenaming() }
                            .onChange(of: renamingTextfieldFocused) { _, newValue in
                                if !newValue { finishRenaming(chat) }
                            }
                    } else {
                        Text(chat.title)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }

                    // Message preview
                    Text(chatPreview(for: chat))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 4) {
                    // Relative time
                    Text(relativeTime(for: chat.lastMessageDate))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    // Loading indicator
                    if isLoading {
                        PulsingDotView()
                    }
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 10)
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(isSelected ?
                      Color.accentColor.opacity(0.15) :
                        (isHovered ? Color(NSColor.quaternaryLabelColor) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hover in
            if !isRenaming {
                withAnimation(.hover) {
                    hoverStates[chat.chatId] = hover
                }
            }
        }
        .contextMenu {
            Button("Rename") { startRenaming(chat) }
            Button("Copy Entire Chat") { copyEntireChat(chat) }
            Button("Export as Text File") { exportChatAsTextFile(chat) }
            Divider()
            Button("Delete", role: .destructive) { deleteChat(chat) }
        }
        .onTapGesture {
            if !isRenaming {
                selection = .chat(chat)
            }
        }
    }

    func comparisonRowView(for entry: ComparisonEntry) -> some View {
        let isSelected = selection == .comparison(entry.id)
        let vm = comparisonViewModels[entry.id]
        let modelNames = vm?.panes.map { $0.modelName }.joined(separator: " vs ") ?? "No models"
        let preview: String = {
            guard let panes = vm?.panes, let first = panes.first,
                  let lastMsg = first.viewModel.messages.last else {
                return "No messages yet"
            }
            let prefix = lastMsg.user == "User" ? "You: " : ""
            return prefix + lastMsg.text.prefix(50).replacingOccurrences(of: "\n", with: " ")
        }()

        return HStack(spacing: 10) {
            Image(systemName: "rectangle.split.3x1")
                .font(.system(size: 14))
                .foregroundStyle(Color.accent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(modelNames)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(preview)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text(relativeTime(for: entry.createdAt))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selection = .comparison(entry.id)
        }
        .contextMenu {
            Button("Delete", role: .destructive) {
                comparisons.removeAll { $0.id == entry.id }
                if selection == .comparison(entry.id) {
                    selection = nil
                }
                onDeleteComparison?(entry.id)
            }
        }
    }

    private func chatPreview(for chat: ChatModel) -> String {
        let messages = chatManager.getMessages(for: chat.chatId)
        if let last = messages.last {
            let prefix = last.user == "User" ? "You: " : ""
            return prefix + last.text.prefix(60).replacingOccurrences(of: "\n", with: " ")
        }
        return chat.name
    }

    private func relativeTime(for date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 604800 { return "\(Int(interval / 86400))d" }
        return "\(Int(interval / 604800))w"
    }
    
    struct PulsingDotView: View {
        @State private var isAnimating = false

        var body: some View {
            Circle()
                .fill(Color.accent)
                .frame(width: 6, height: 6)
                .opacity(isAnimating ? 1.0 : 0.3)
                .animation(
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .onAppear { isAnimating = true }
        }
    }
    
    // MARK: - Methods

    /// Executes search against the index and updates results with debouncing
    private func performSearch() {
        // Cancel previous timer
        searchDebounceTimer?.invalidate()
        
        if searchText.isEmpty {
            searchResults = []
            return
        }
        
        // If index is not ready yet, show loading state and wait for background indexing
        if searchIndex.indexedChatIds.isEmpty && !chatManager.chats.isEmpty {
            isSearching = true
            // Don't trigger immediate indexing here - it's already happening in background
            // Just wait for it to complete
            searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                Task { @MainActor in
                    executeSearch()
                }
            }
            return
        }
        
        // Set new timer for debounced search (faster than chat search - 0.2s)
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            Task { @MainActor in
                executeSearch()
            }
        }
    }
    
    private func executeSearch() {
        if searchText.isEmpty {
            searchResults = []
            return
        }
        
        // Run search in the background with higher priority for sidebar
        Task(priority: .userInitiated) {
            isSearching = true
            let results = await MainActor.run {
                return searchIndex.search(query: searchText)
            }
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        }
    }
    
    // MARK: - Chat Actions
    
    private func copyEntireChat(_ chat: ChatModel) {
        let messages = chatManager.getMessages(for: chat.chatId)
        var chatText = "Chat: \(chat.title)\nModel: \(chat.name)\n\n"
        
        for message in messages {
            chatText += "\(message.user):\n\(message.text)\n\n"
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(chatText, forType: .string)
    }
    
    /// Creates a new chat with the currently selected model
    private func createNewChat() {
        guard let modelSelection = menuSelection, case .chat(let model) = modelSelection else {
            logger.warning("No model selected for new chat creation")
            return
        }
        
        chatManager.createNewChat(modelId: model.id, modelName: model.name, modelProvider: model.provider) { newChat in
            // ChatManager already added the chat to its array, so we don't need to add it again
            // Just update the selection
            self.selection = .chat(newChat)
            self.selectionId = UUID()
            
            // Mark that search index needs update for this new chat
            Task(priority: .background) {
                await MainActor.run {
                    // Reset indexed chat IDs to force reindex when search is used
                    self.searchIndex.indexedChatIds.remove(newChat.chatId)
                }
            }
            
            // Handle quick access message and attachments if available
            if let _ = AppCoordinator.shared.quickAccessMessage,
               AppCoordinator.shared.isProcessingQuickAccess {
                
                // Set target chat ID for the message
                AppCoordinator.shared.targetChatId = newChat.chatId
                
                // Clear processing flag after a delay
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                    AppCoordinator.shared.isProcessingQuickAccess = false
                    AppCoordinator.shared.targetChatId = nil
                }
            }
        }
    }
    


    // Incremental update: Add a new chat to the appropriate date group
    private func incrementalAddChat(_ newChat: ChatModel) {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: newChat.lastMessageDate)
        
        if let date = calendar.date(from: dateComponents) {
            let key = formatDate(date)
            
            // If date key already exists, add to that group, otherwise create new group
            var mutableOrganizedModels = organizedChatsByDate
            if var chatsForDate = mutableOrganizedModels[key] {
                chatsForDate.insert(newChat, at: 0)
                mutableOrganizedModels[key] = chatsForDate
            } else {
                mutableOrganizedModels[key] = [newChat]
            }

            organizedChatsByDate = mutableOrganizedModels
        }
    }
    
    // Incremental update: Add new chat to search index - removed as it's now handled by lazy loading
    // The search index will be updated when actually needed during search
    
    // Throttled organization function (prevents multiple calls in short time)
    private func throttledOrganizeChatsByDate() {
        let now = Date()
        if !sortingInProgress && now.timeIntervalSince(lastSortTime) > sortingThrottleInterval {
            sortingInProgress = true

            // Move sorting work to background thread
            Task(priority: .userInitiated) {
                let calendar = Calendar.current
                let sortedChats = self.chatManager.chats.sorted { $0.lastMessageDate > $1.lastMessageDate }
                let groupedChats = Dictionary(grouping: sortedChats) { chat -> DateComponents in
                    calendar.dateComponents([.year, .month, .day], from: chat.lastMessageDate)
                }
                
                let sortedDateComponents = groupedChats.keys.sorted {
                    if $0.year != $1.year {
                        return $0.year! > $1.year! // Descending
                    } else if $0.month != $1.month {
                        return $0.month! > $1.month! // Descending
                    } else {
                        return $0.day! > $1.day! // Descending
                    }
                }
                
                var newOrganizedModels: [String: [ChatModel]] = [:]
                for components in sortedDateComponents {
                    if let date = calendar.date(from: components) {
                        let key = self.formatDate(date)
                        if let chatsForDate = groupedChats[components] {
                            newOrganizedModels[key] = chatsForDate
                        }
                    }
                }
                
                // UI updates on main thread
                await MainActor.run {
                    self.organizedChatsByDate = newOrganizedModels
                    self.lastSortTime = Date()
                    self.sortingInProgress = false
                }
            }
        }
    }
    
    // Initial organization (run once at app startup)
    private func organizeChatsInitial() {
        throttledOrganizeChatsByDate()
        // Don't update search index here - it will be updated lazily when needed
    }
    
    // Optimized search index update - only called when needed and chats have changed
    private func updateSearchIndexIfNeeded() {
        // Only update if we have chats and index is empty or outdated
        guard !chatManager.chats.isEmpty else { return }
        
        Task(priority: .background) {
            // Run indexing in background thread to avoid blocking UI
            await Task.detached(priority: .background) {
                await MainActor.run {
                    searchIndex.updateIndex(chats: chatManager.chats, chatManager: chatManager)
                }
            }.value
        }
    }
    
    /// Deletes the currently selected chat
    private func deleteSelectedChat() {
        guard let selectedChat = getSelectedChat() else {
            print("No chat selected to delete")
            return
        }
        selection = chatManager.deleteChat(with: selectedChat.chatId)
        throttledOrganizeChatsByDate()
    }
    
    /// Returns the currently selected chat model, if any
    private func getSelectedChat() -> ChatModel? {
        if case .chat(let chat) = selection {
            return chat
        }
        return nil
    }
    
    /// Formats a date for section headers
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        
        // Check if date is today
        if calendar.isDateInToday(date) {
            return "Today"
        }
        
        // Check if date is yesterday
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        
        // For all other dates, use the standard format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM dd, yyyy"
        return dateFormatter.string(from: date)
    }
    
    /// Deletes a specific chat
    private func deleteChat(_ chat: ChatModel) {
        hoverStates[chat.chatId] = false
        selection = chatManager.deleteChat(with: chat.chatId)
        throttledOrganizeChatsByDate() // Use optimized version
    }
    
    /// Exports a chat history as a text file
    private func exportChatAsTextFile(_ chat: ChatModel) {
        let chatMessages = chatManager.getMessages(for: chat.chatId)
        let fileContents = chatMessages.map { "\($0.sentTime): \($0.user): \($0.text)" }.joined(separator: "\n")
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.text]
        savePanel.nameFieldStringValue = "\(chat.title).txt"
        
        savePanel.begin { response in
            if response == .OK {
                guard let url = savePanel.url else { return }
                do {
                    try fileContents.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to save chat history: \(error)")
                }
            }
        }
    }
    
    /// Starts renaming a chat
    private func startRenaming(_ chat: ChatModel) {
        renamingChatId = chat.chatId
        renameText = chat.title
        renamingTextfieldFocused = true
    }
    
    /// Finishes renaming a chat and saves the new title
    private func finishRenaming(_ chat: ChatModel) {
        let trimmedTitle = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Only update if the title actually changed and is not empty
        if !trimmedTitle.isEmpty && trimmedTitle != chat.title {
            chatManager.updateChatTitle(for: chat.chatId, title: trimmedTitle, isManualRename: true)
        }
        
        // Reset renaming state
        renamingChatId = nil
        renameText = ""
        renamingTextfieldFocused = false
    }
    
    /// Cancels renaming a chat without saving changes
    private func cancelRenaming() {
        renamingChatId = nil
        renameText = ""
        renamingTextfieldFocused = false
    }
}


// MARK: - Liquid Glass Modifiers for Sidebar

// MARK: - Sidebar UI Modifiers (macOS 26+ Messages App Style, earlier versions with borders)

struct LiquidGlassButtonModifier: ViewModifier {
    let colorScheme: ColorScheme
    
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            // macOS 26+: Perfect circle with subtle glass effect
            content
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ?
                              Color.white.opacity(0.08) :
                              Color.black.opacity(0.05))
                )
        } else {
            // macOS 25 and earlier: Original style with border and shadow
            content
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ?
                              Color(NSColor.controlBackgroundColor) :
                              Color(NSColor.controlColor))
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(colorScheme == .dark ?
                                Color.white.opacity(0.1) :
                                Color.black.opacity(0.1),
                                lineWidth: 0.5)
                )
        }
    }
}

struct LiquidGlassSearchBarModifier: ViewModifier {
    let colorScheme: ColorScheme
    
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            // macOS 26+: Perfect circle with subtle glass effect
            content
                .background(
                    Capsule()
                        .fill(colorScheme == .dark ?
                              Color.white.opacity(0.08) :
                              Color.black.opacity(0.05))
                )
        } else {
            // macOS 25 and earlier: Original style with border and shadow
            content
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ?
                              Color(NSColor.textBackgroundColor).opacity(0.8) :
                              Color(NSColor.textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(colorScheme == .dark ?
                                Color.white.opacity(0.1) :
                                Color.black.opacity(0.1),
                                lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}

// MARK: - Chat Row Border Modifier (macOS 25 and earlier only)
struct ChatRowBorderModifier: ViewModifier {
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            // macOS 26+: No border
            content
        } else {
            // macOS 25 and earlier: Show border when selected
            content
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        }
    }
}
