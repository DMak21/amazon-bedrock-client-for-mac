//
//  ComparisonChatView.swift
//  Amazon Bedrock Client for Mac
//

import SwiftUI
import Logging

struct ComparisonChatView: View {
    @ObservedObject var viewModel: ComparisonViewModel
    @State private var showModelPicker = false
    var organizedChatModels: [String: [ChatModel]]
    var onStateChanged: (() -> Void)?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.panes.isEmpty {
                modelSetupView
            } else {
                splitPaneArea
                Divider()
                comparisonMessageBar
            }
        }
        .background(Color.surface0)
        .sheet(isPresented: $showModelPicker) {
            ModelPickerSheet(
                organizedChatModels: organizedChatModels,
                onDone: { models in
                    for model in models {
                        viewModel.addModel(model)
                    }
                    showModelPicker = false
                    onStateChanged?()
                }
            )
        }
    }

    // MARK: - Setup View

    private var modelSetupView: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            Image(systemName: "rectangle.split.3x1")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.tertiaryText.opacity(0.6))

            VStack(spacing: DS.Spacing.sm) {
                Text("Model Comparison")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(Color.text)

                Text("Add two or more models to compare their responses side by side")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
            }

            Button(action: { showModelPicker = true }) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Model")
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .background(
                    Capsule()
                        .fill(Color.accent.opacity(0.15))
                )
                .foregroundStyle(Color.accent)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Split Pane Area

    private var splitPaneArea: some View {
        HStack(spacing: 0) {
            ForEach(Array(viewModel.panes.enumerated()), id: \.element.id) { index, pane in
                if index > 0 {
                    Divider()
                }
                comparisonPane(pane: pane, index: index)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showModelPicker = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(LiquidGlassToolbarButtonStyle())
                .help("Add model to comparison")
            }
        }
    }

    private func comparisonPane(pane: ComparisonViewModel.ComparisonPane, index: Int) -> some View {
        let isFocused = viewModel.focusedPaneIndex == index

        return VStack(spacing: 0) {
            paneHeader(pane: pane, index: index, isFocused: isFocused)
            Divider()
            paneContent(pane: pane)
        }
        .background(isFocused ? Color.surface0 : Color.surface0.opacity(0.7))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .strokeBorder(isFocused ? Color.accent.opacity(0.4) : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.focusedPaneIndex = index
        }
    }

    private func paneHeader(pane: ComparisonViewModel.ComparisonPane, index: Int, isFocused: Bool) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            ModelImageHelper.getImage(for: pane.modelId)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .clipShape(Circle())

            Text(pane.modelName)
                .font(.system(size: 12, weight: isFocused ? .semibold : .medium))
                .lineLimit(1)

            Spacer()

            if isFocused {
                Text("Focused")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.accent.opacity(0.12))
                    )
            }

            Button(action: { viewModel.removePane(at: index) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.secondaryText)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(Color.surface1.opacity(0.6))
    }

    private func paneContent(pane: ComparisonViewModel.ComparisonPane) -> some View {
        ComparisonPaneContentView(viewModel: pane.viewModel, paneId: pane.id, modelId: pane.modelId)
    }

    // MARK: - Message Bar

    private var comparisonMessageBar: some View {
        HStack(spacing: DS.Spacing.md) {
            sendModeIndicator

            TextField("Type a message...", text: $viewModel.userInput, axis: .vertical)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 14))
                .lineLimit(1...5)
                .focused($isInputFocused)
                .onSubmit {
                    if NSEvent.modifierFlags.contains(.shift) { return }
                    sendCurrentMessage()
                }

            sendButton
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(Color.surface1)
    }

    private var sendModeIndicator: some View {
        Group {
            if viewModel.hasInitialPrompt {
                let focusedName = viewModel.panes.indices.contains(viewModel.focusedPaneIndex)
                    ? viewModel.panes[viewModel.focusedPaneIndex].modelName
                    : "—"
                Text("To: \(focusedName)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.accent.opacity(0.1)))
            } else {
                Text("To: All")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.accent.opacity(0.1)))
            }
        }
    }

    private var sendButton: some View {
        Button(action: sendCurrentMessage) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(viewModel.userInput.isEmpty ? Color.secondaryText : Color.accent)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(viewModel.userInput.isEmpty)
    }

    private func sendCurrentMessage() {
        if viewModel.hasInitialPrompt {
            viewModel.sendToFocused()
        } else {
            viewModel.sendToAll()
            onStateChanged?()
        }
    }
}

// MARK: - Pane Content View (owns observation of ChatViewModel)

private struct ComparisonPaneContentView: View {
    @ObservedObject var viewModel: ChatViewModel
    let paneId: String
    let modelId: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 2) {
                    if viewModel.messages.isEmpty {
                        Spacer()
                        Text("Waiting for prompt...")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondaryText)
                        Spacer()
                    } else {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.offset) { idx, message in
                            MessageView(
                                message: message,
                                searchResult: nil,
                                adjustedFontSize: 0,
                                modelId: modelId,
                                onRevert: idx > 0 ? {
                                    let target: Int
                                    if message.user == "User" {
                                        target = idx - 1
                                    } else {
                                        target = idx >= 2 ? idx - 2 : 0
                                    }
                                    viewModel.revertToMessage(at: target)
                                } : nil
                            )
                            .id(idx)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    Color.clear.frame(height: 1).id("Bottom-\(paneId)")
                }
                .padding()
            }
            .modifier(ScrollEdgeEffectModifier())
            .onChange(of: viewModel.messages.count) { _, _ in
                proxy.scrollTo("Bottom-\(paneId)", anchor: .bottom)
            }
        }
    }
}

// MARK: - Model Picker Sheet

struct ModelPickerSheet: View {
    let organizedChatModels: [String: [ChatModel]]
    let onDone: ([ChatModel]) -> Void
    @State private var searchText = ""
    @State private var selectedModelIds: Set<String> = []
    @ObservedObject private var settingManager = SettingManager.shared
    @Environment(\.dismiss) private var dismiss

    private var favoriteModels: [ChatModel] {
        organizedChatModels.values.flatMap { $0 }
            .filter { settingManager.isModelFavorite($0.id) }
            .filter {
                searchText.isEmpty ||
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.id.localizedCaseInsensitiveContains(searchText)
            }
    }

    private var filteredModels: [(String, [ChatModel])] {
        let allGroups = organizedChatModels.sorted { $0.key < $1.key }
        if searchText.isEmpty { return allGroups }

        return allGroups.compactMap { (provider, models) in
            let filtered = models.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.id.localizedCaseInsensitiveContains(searchText)
            }
            return filtered.isEmpty ? nil : (provider, filtered)
        }
    }

    private var selectedModels: [ChatModel] {
        let all = organizedChatModels.values.flatMap { $0 }
        return all.filter { selectedModelIds.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Models")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Button("Add \(selectedModelIds.count > 0 ? "(\(selectedModelIds.count))" : "")") {
                    onDone(selectedModels)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accent)
                .fontWeight(.semibold)
                .disabled(selectedModelIds.isEmpty)
            }
            .padding()

            TextField("Search models...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .padding(.bottom, DS.Spacing.sm)

            List {
                if !favoriteModels.isEmpty {
                    Section(header: Text("Favorites")) {
                        ForEach(favoriteModels, id: \.id) { model in
                            modelRow(model)
                        }
                    }
                }

                ForEach(filteredModels, id: \.0) { provider, models in
                    Section(header: Text(provider)) {
                        ForEach(models, id: \.id) { model in
                            modelRow(model)
                        }
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
    }

    private func modelRow(_ model: ChatModel) -> some View {
        let isSelected = selectedModelIds.contains(model.id)

        return Button(action: {
            if isSelected {
                selectedModelIds.remove(model.id)
            } else {
                selectedModelIds.insert(model.id)
            }
        }) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Color.accent : Color.secondaryText)

                ModelImageHelper.getImage(for: model.id)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(.system(size: 13, weight: .medium))
                    Text(model.id)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
