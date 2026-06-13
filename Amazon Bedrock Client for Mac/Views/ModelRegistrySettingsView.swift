//
//  ModelRegistrySettingsView.swift
//  Amazon Bedrock Client for Mac
//

import SwiftUI

struct ModelRegistrySettingsView: View {
    @ObservedObject private var registry = ModelRegistry.shared
    @State private var searchText = ""
    @State private var selectedModelId: String?
    @State private var editingModel: ModelDefinition?

    private var filteredModels: [(String, [ModelDefinition])] {
        let all = registry.allModels
        let filtered: [ModelDefinition]
        if searchText.isEmpty {
            filtered = all
        } else {
            filtered = all.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText) ||
                $0.provider.localizedCaseInsensitiveContains(searchText) ||
                $0.id.localizedCaseInsensitiveContains(searchText)
            }
        }
        let grouped = Dictionary(grouping: filtered) { $0.provider }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        HSplitView {
            modelListPanel
                .frame(minWidth: 250, maxWidth: 300)
            detailPanel
                .frame(maxWidth: .infinity)
        }
        .sheet(item: $editingModel) { model in
            ModelDefinitionEditorView(model: model, isNew: !registry.allModels.contains(where: { $0.id == model.id })) { saved in
                if registry.userDefinedModels.contains(where: { $0.id == saved.id }) {
                    registry.updateUserModel(saved)
                } else {
                    registry.addUserModel(saved)
                }
                selectedModelId = saved.id
                editingModel = nil
            }
            .frame(width: 500, height: 600)
        }
    }

    // MARK: - List Panel

    private var modelListPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("Filter models...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 12))
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            List(selection: $selectedModelId) {
                ForEach(filteredModels, id: \.0) { provider, models in
                    Section(header: Text(provider.capitalized).font(.system(size: 11, weight: .semibold))) {
                        ForEach(models) { model in
                            modelRow(model)
                                .tag(model.id)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack {
                Button(action: addCustomModel) {
                    Label("Add Custom Model", systemImage: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                Spacer()
            }
            .padding(8)
        }
    }

    private func modelRow(_ model: ModelDefinition) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(model.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    if !model.isBuiltIn {
                        Text("Custom")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.accentColor))
                    }
                }
                HStack(spacing: 3) {
                    capabilityBadge("T", active: model.capabilities.textGeneration)
                    capabilityBadge("R", active: model.capabilities.reasoning)
                    capabilityBadge("I", active: model.capabilities.imageGeneration)
                    capabilityBadge("D", active: model.capabilities.documentChat)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func capabilityBadge(_ letter: String, active: Bool) -> some View {
        Text(letter)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(active ? Color.accentColor : Color.secondary.opacity(0.3))
            .frame(width: 14, height: 14)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(active ? Color.accentColor.opacity(0.1) : Color.clear)
            )
    }

    // MARK: - Detail Panel

    @ViewBuilder
    private var detailPanel: some View {
        if let id = selectedModelId, let model = registry.allModels.first(where: { $0.id == id }) {
            ModelDetailView(model: model, onEdit: {
                if model.isBuiltIn {
                    var copy = model
                    copy.isBuiltIn = false
                    copy.matchPriority = model.matchPriority + 10
                    editingModel = copy
                } else {
                    editingModel = model
                }
            }, onDuplicate: {
                duplicateModel(model)
            }, onDelete: model.isBuiltIn ? nil : {
                registry.deleteUserModel(id: model.id)
                selectedModelId = nil
            })
        } else {
            VStack {
                Spacer()
                Image(systemName: "cpu")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary.opacity(0.5))
                Text("Select a model to view its configuration")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    // MARK: - Actions

    private func addCustomModel() {
        editingModel = ModelDefinition(
            id: "custom-\(UUID().uuidString.prefix(8))",
            displayName: "New Custom Model",
            provider: "custom",
            matchPatterns: ["custom-model"],
            matchPriority: 100,
            capabilities: ModelCapabilities(textGeneration: true, documentChat: true, systemPrompt: true),
            reasoningType: .none,
            availableEffortLevels: [],
            apiRoute: .converse,
            parameterRanges: ModelParameterRanges(
                maxTokensMin: 1, maxTokensMax: 8192,
                temperatureMin: 0.0, temperatureMax: 2.0,
                topPMin: 0.01, topPMax: 1.0,
                thinkingBudgetMin: 1024, thinkingBudgetMax: 4096,
                defaultMaxTokens: 4096, defaultTemperature: 0.7,
                defaultTopP: 0.9, defaultThinkingBudget: 2048,
                defaultReasoningEffort: "medium"
            ),
            restrictions: ParameterRestrictions(),
            isBuiltIn: false
        )
            }

    private func duplicateModel(_ model: ModelDefinition) {
        var copy = model
        copy.id = "\(model.id)-custom-\(UUID().uuidString.prefix(4))"
        copy.displayName = "\(model.displayName) (Custom)"
        copy.isBuiltIn = false
        copy.matchPriority = model.matchPriority + 10
        editingModel = copy
            }
}

// MARK: - Detail View

private struct ModelDetailView: View {
    let model: ModelDefinition
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()
                capabilitiesSection
                Divider()
                reasoningSection
                Divider()
                parametersSection
                Divider()
                restrictionsSection
                Divider()
                matchingSection
            }
            .padding()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.title2.weight(.semibold))
                    if model.isBuiltIn {
                        Text("Built-in")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                    }
                }
                Text("Provider: \(model.provider) • Route: \(model.apiRoute.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(model.isBuiltIn ? "Customize" : "Edit", action: onEdit)
            Button("Duplicate", action: onDuplicate)
            if let onDelete = onDelete {
                Button("Delete", role: .destructive, action: onDelete)
            }
        }
    }

    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Capabilities").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], alignment: .leading, spacing: 6) {
                capRow("Text Generation", model.capabilities.textGeneration)
                capRow("Image Generation", model.capabilities.imageGeneration)
                capRow("Video Generation", model.capabilities.videoGeneration)
                capRow("Embedding", model.capabilities.embedding)
                capRow("Reasoning", model.capabilities.reasoning)
                capRow("Document Chat", model.capabilities.documentChat)
                capRow("Streaming Tool Use", model.capabilities.streamingToolUse)
                capRow("Prompt Caching", model.capabilities.promptCaching)
            }
        }
    }

    private func capRow(_ label: String, _ enabled: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(enabled ? .green : .secondary.opacity(0.4))
                .font(.system(size: 12))
            Text(label).font(.system(size: 12))
        }
    }

    private var reasoningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reasoning").font(.headline)
            LabeledContent("Type") { Text(model.reasoningType.rawValue) }
            if !model.availableEffortLevels.isEmpty {
                LabeledContent("Effort Levels") { Text(model.availableEffortLevels.joined(separator: ", ")) }
            }
        }
        .font(.system(size: 12))
    }

    private var parametersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Parameter Ranges").font(.headline)
            let p = model.parameterRanges
            LabeledContent("Max Tokens") { Text("\(p.maxTokensMin)–\(p.maxTokensMax) (default: \(p.defaultMaxTokens))") }
            LabeledContent("Temperature") { Text("\(p.temperatureMin, specifier: "%.1f")–\(p.temperatureMax, specifier: "%.1f") (default: \(p.defaultTemperature, specifier: "%.1f"))") }
            LabeledContent("Top P") { Text("\(p.topPMin, specifier: "%.2f")–\(p.topPMax, specifier: "%.2f") (default: \(p.defaultTopP, specifier: "%.2f"))") }
            if model.capabilities.reasoning {
                LabeledContent("Thinking Budget") { Text("\(p.thinkingBudgetMin)–\(p.thinkingBudgetMax) (default: \(p.defaultThinkingBudget))") }
            }
        }
        .font(.system(size: 12))
    }

    private var restrictionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Restrictions").font(.headline)
            let r = model.restrictions
            capRow("Top P / Temperature mutually exclusive", r.mutuallyExclusiveTopPAndTemperature)
            capRow("Fixed temperature during reasoning", r.fixedTemperatureDuringReasoning)
            capRow("Omit sampling params", r.omitSamplingParams)
            if let fixed = r.fixedTemperature {
                LabeledContent("Fixed Temperature") { Text("\(fixed, specifier: "%.1f")") }
            }
        }
        .font(.system(size: 12))
    }

    private var matchingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pattern Matching").font(.headline)
            LabeledContent("Patterns") { Text(model.matchPatterns.joined(separator: ", ")).font(.system(size: 11, design: .monospaced)) }
            LabeledContent("Priority") { Text("\(model.matchPriority)") }
        }
        .font(.system(size: 12))
    }
}

// MARK: - Editor View

struct ModelDefinitionEditorView: View {
    @State var model: ModelDefinition
    let isNew: Bool
    let onSave: (ModelDefinition) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isNew ? "Add Custom Model" : "Edit Model")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                Button("Save") { onSave(model) }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.displayName.isEmpty || model.matchPatterns.isEmpty)
            }
            .padding()

            Divider()

            Form {
                Section("Identity") {
                    TextField("Display Name", text: $model.displayName)
                    TextField("Provider", text: $model.provider)
                    TextField("Match Patterns (comma-separated)", text: Binding(
                        get: { model.matchPatterns.joined(separator: ", ") },
                        set: { model.matchPatterns = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                    ))
                    Stepper("Priority: \(model.matchPriority)", value: $model.matchPriority, in: 0...100)
                }

                Section("Capabilities") {
                    Toggle("Text Generation", isOn: $model.capabilities.textGeneration)
                    Toggle("Image Generation", isOn: $model.capabilities.imageGeneration)
                    Toggle("Video Generation", isOn: $model.capabilities.videoGeneration)
                    Toggle("Embedding", isOn: $model.capabilities.embedding)
                    Toggle("Reasoning", isOn: $model.capabilities.reasoning)
                    Toggle("Document Chat", isOn: $model.capabilities.documentChat)
                    Toggle("Streaming Tool Use", isOn: $model.capabilities.streamingToolUse)
                    Toggle("Prompt Caching", isOn: $model.capabilities.promptCaching)
                }

                Section("Reasoning") {
                    Picker("Type", selection: $model.reasoningType) {
                        ForEach(ReasoningType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    Picker("API Route", selection: $model.apiRoute) {
                        ForEach(APIRoute.allCases, id: \.self) { route in
                            Text(route.rawValue).tag(route)
                        }
                    }
                }

                Section("Parameter Ranges") {
                    HStack {
                        Text("Max Tokens:")
                        TextField("Min", value: $model.parameterRanges.maxTokensMin, format: .number).frame(width: 60)
                        Text("–")
                        TextField("Max", value: $model.parameterRanges.maxTokensMax, format: .number).frame(width: 60)
                        Text("Default:")
                        TextField("", value: $model.parameterRanges.defaultMaxTokens, format: .number).frame(width: 60)
                    }
                    HStack {
                        Text("Temperature:")
                        TextField("Min", value: $model.parameterRanges.temperatureMin, format: .number).frame(width: 50)
                        Text("–")
                        TextField("Max", value: $model.parameterRanges.temperatureMax, format: .number).frame(width: 50)
                        Text("Default:")
                        TextField("", value: $model.parameterRanges.defaultTemperature, format: .number).frame(width: 50)
                    }
                }

                Section("Restrictions") {
                    Toggle("Top P / Temperature mutually exclusive", isOn: $model.restrictions.mutuallyExclusiveTopPAndTemperature)
                    Toggle("Fixed temperature during reasoning", isOn: $model.restrictions.fixedTemperatureDuringReasoning)
                    Toggle("Omit sampling params", isOn: $model.restrictions.omitSamplingParams)
                }
            }
            .formStyle(.grouped)
        }
    }
}
