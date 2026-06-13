//
//  ModelRegistry.swift
//  Amazon Bedrock Client for Mac
//

import Foundation
import SwiftUI

// MARK: - Model Definition Types

enum ReasoningType: String, Codable, CaseIterable {
    case none
    case tokenBudget
    case effortBased
    case adaptiveEffort
    case alwaysOnEffort
    case alwaysOnFixed
}

enum APIRoute: String, Codable, CaseIterable {
    case converse
    case mantleResponses
    case imageGeneration
    case videoGeneration
    case embedding
}

struct ModelCapabilities: Codable, Equatable {
    var textGeneration: Bool = false
    var imageGeneration: Bool = false
    var videoGeneration: Bool = false
    var embedding: Bool = false
    var reasoning: Bool = false
    var documentChat: Bool = false
    var streamingToolUse: Bool = false
    var promptCaching: Bool = false
    var systemPrompt: Bool = true

    init(textGeneration: Bool = false, imageGeneration: Bool = false, videoGeneration: Bool = false, embedding: Bool = false, reasoning: Bool = false, documentChat: Bool = false, streamingToolUse: Bool = false, promptCaching: Bool = false, systemPrompt: Bool = true) {
        self.textGeneration = textGeneration
        self.imageGeneration = imageGeneration
        self.videoGeneration = videoGeneration
        self.embedding = embedding
        self.reasoning = reasoning
        self.documentChat = documentChat
        self.streamingToolUse = streamingToolUse
        self.promptCaching = promptCaching
        self.systemPrompt = systemPrompt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        textGeneration = try c.decodeIfPresent(Bool.self, forKey: .textGeneration) ?? false
        imageGeneration = try c.decodeIfPresent(Bool.self, forKey: .imageGeneration) ?? false
        videoGeneration = try c.decodeIfPresent(Bool.self, forKey: .videoGeneration) ?? false
        embedding = try c.decodeIfPresent(Bool.self, forKey: .embedding) ?? false
        reasoning = try c.decodeIfPresent(Bool.self, forKey: .reasoning) ?? false
        documentChat = try c.decodeIfPresent(Bool.self, forKey: .documentChat) ?? false
        streamingToolUse = try c.decodeIfPresent(Bool.self, forKey: .streamingToolUse) ?? false
        promptCaching = try c.decodeIfPresent(Bool.self, forKey: .promptCaching) ?? false
        systemPrompt = try c.decodeIfPresent(Bool.self, forKey: .systemPrompt) ?? true
    }
}

struct ModelParameterRanges: Codable, Equatable {
    var maxTokensMin: Int
    var maxTokensMax: Int
    var temperatureMin: Float
    var temperatureMax: Float
    var topPMin: Float
    var topPMax: Float
    var thinkingBudgetMin: Int
    var thinkingBudgetMax: Int
    var defaultMaxTokens: Int
    var defaultTemperature: Float
    var defaultTopP: Float
    var defaultThinkingBudget: Int
    var defaultReasoningEffort: String

    var maxTokensRange: ClosedRange<Int> { maxTokensMin...maxTokensMax }
    var temperatureRange: ClosedRange<Float> { temperatureMin...temperatureMax }
    var topPRange: ClosedRange<Float> { topPMin...topPMax }
    var thinkingBudgetRange: ClosedRange<Int> { thinkingBudgetMin...thinkingBudgetMax }
}

struct ParameterRestrictions: Codable, Equatable {
    var mutuallyExclusiveTopPAndTemperature: Bool = false
    var fixedTemperatureDuringReasoning: Bool = false
    var fixedTemperature: Float? = nil
    var omitSamplingParams: Bool = false

    init(mutuallyExclusiveTopPAndTemperature: Bool = false, fixedTemperatureDuringReasoning: Bool = false, fixedTemperature: Float? = nil, omitSamplingParams: Bool = false) {
        self.mutuallyExclusiveTopPAndTemperature = mutuallyExclusiveTopPAndTemperature
        self.fixedTemperatureDuringReasoning = fixedTemperatureDuringReasoning
        self.fixedTemperature = fixedTemperature
        self.omitSamplingParams = omitSamplingParams
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mutuallyExclusiveTopPAndTemperature = try c.decodeIfPresent(Bool.self, forKey: .mutuallyExclusiveTopPAndTemperature) ?? false
        fixedTemperatureDuringReasoning = try c.decodeIfPresent(Bool.self, forKey: .fixedTemperatureDuringReasoning) ?? false
        fixedTemperature = try c.decodeIfPresent(Float.self, forKey: .fixedTemperature)
        omitSamplingParams = try c.decodeIfPresent(Bool.self, forKey: .omitSamplingParams) ?? false
    }
}

struct ModelDefinition: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var provider: String
    var matchPatterns: [String]
    var matchPriority: Int = 0

    var capabilities: ModelCapabilities
    var reasoningType: ReasoningType
    var availableEffortLevels: [String]
    var apiRoute: APIRoute
    var parameterRanges: ModelParameterRanges
    var restrictions: ParameterRestrictions

    var isBuiltIn: Bool = true

    init(id: String, displayName: String, provider: String, matchPatterns: [String], matchPriority: Int = 0, capabilities: ModelCapabilities, reasoningType: ReasoningType, availableEffortLevels: [String], apiRoute: APIRoute, parameterRanges: ModelParameterRanges, restrictions: ParameterRestrictions, isBuiltIn: Bool = true) {
        self.id = id
        self.displayName = displayName
        self.provider = provider
        self.matchPatterns = matchPatterns
        self.matchPriority = matchPriority
        self.capabilities = capabilities
        self.reasoningType = reasoningType
        self.availableEffortLevels = availableEffortLevels
        self.apiRoute = apiRoute
        self.parameterRanges = parameterRanges
        self.restrictions = restrictions
        self.isBuiltIn = isBuiltIn
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        displayName = try c.decode(String.self, forKey: .displayName)
        provider = try c.decode(String.self, forKey: .provider)
        matchPatterns = try c.decode([String].self, forKey: .matchPatterns)
        matchPriority = try c.decodeIfPresent(Int.self, forKey: .matchPriority) ?? 0
        capabilities = try c.decode(ModelCapabilities.self, forKey: .capabilities)
        reasoningType = try c.decode(ReasoningType.self, forKey: .reasoningType)
        availableEffortLevels = try c.decodeIfPresent([String].self, forKey: .availableEffortLevels) ?? []
        apiRoute = try c.decode(APIRoute.self, forKey: .apiRoute)
        parameterRanges = try c.decode(ModelParameterRanges.self, forKey: .parameterRanges)
        restrictions = try c.decodeIfPresent(ParameterRestrictions.self, forKey: .restrictions) ?? ParameterRestrictions()
        isBuiltIn = try c.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? true
    }
}

// MARK: - Model Registry

@MainActor
class ModelRegistry: ObservableObject {
    static let shared = ModelRegistry()

    @Published private(set) var builtInModels: [ModelDefinition] = []
    @Published var userDefinedModels: [ModelDefinition] = [] {
        didSet { saveUserModels() }
    }

    var allModels: [ModelDefinition] {
        (userDefinedModels + builtInModels).sorted { $0.matchPriority > $1.matchPriority }
    }

    private init() {
        loadBuiltInModels()
        loadUserModels()
    }

    // MARK: - Lookup

    func definition(for modelId: String) -> ModelDefinition {
        let normalized = normalizeModelId(modelId)

        for model in allModels {
            for pattern in model.matchPatterns {
                if normalized.contains(pattern.lowercased()) {
                    return model
                }
            }
        }

        return fallbackDefinition
    }

    // MARK: - Capability Queries

    func isReasoningSupported(_ modelId: String) -> Bool {
        definition(for: modelId).capabilities.reasoning
    }

    func isImageGenerationModel(_ modelId: String) -> Bool {
        definition(for: modelId).capabilities.imageGeneration
    }

    func isVideoGenerationModel(_ modelId: String) -> Bool {
        definition(for: modelId).capabilities.videoGeneration
    }

    func isEmbeddingModel(_ modelId: String) -> Bool {
        definition(for: modelId).capabilities.embedding
    }

    func isDocumentChatSupported(_ modelId: String) -> Bool {
        definition(for: modelId).capabilities.documentChat
    }

    func isPromptCachingSupported(_ modelId: String) -> Bool {
        definition(for: modelId).capabilities.promptCaching
    }

    func supportsStreamingToolUse(_ modelId: String) -> Bool {
        definition(for: modelId).capabilities.streamingToolUse
    }

    func isTextGenerationModel(_ modelId: String) -> Bool {
        definition(for: modelId).capabilities.textGeneration
    }

    func hasAlwaysOnReasoning(_ modelId: String) -> Bool {
        let rt = definition(for: modelId).reasoningType
        return rt == .alwaysOnFixed || rt == .alwaysOnEffort
    }

    func hasConfigurableReasoning(_ modelId: String) -> Bool {
        let def = definition(for: modelId)
        return def.capabilities.reasoning && def.reasoningType != .alwaysOnFixed
    }

    func isMantleResponsesModel(_ modelId: String) -> Bool {
        definition(for: modelId).apiRoute == .mantleResponses
    }

    func isClaude45OrLater(_ modelId: String) -> Bool {
        definition(for: modelId).restrictions.mutuallyExclusiveTopPAndTemperature
    }

    // MARK: - User Model Management

    func addUserModel(_ model: ModelDefinition) {
        var m = model
        m.isBuiltIn = false
        userDefinedModels.append(m)
    }

    func updateUserModel(_ model: ModelDefinition) {
        if let idx = userDefinedModels.firstIndex(where: { $0.id == model.id }) {
            userDefinedModels[idx] = model
        }
    }

    func deleteUserModel(id: String) {
        userDefinedModels.removeAll { $0.id == id }
    }

    // MARK: - Private

    private func normalizeModelId(_ modelId: String) -> String {
        var id = modelId.lowercased()
        // Strip region prefixes like "us.", "eu.", "ap."
        let regionPrefixes = ["us.", "eu.", "ap.", "us-gov."]
        for prefix in regionPrefixes {
            if id.hasPrefix(prefix) {
                id = String(id.dropFirst(prefix.count))
                break
            }
        }
        return id
    }

    private func loadBuiltInModels() {
        guard let url = Bundle.main.url(forResource: "BuiltInModels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let models = try? JSONDecoder().decode([ModelDefinition].self, from: data) else {
            builtInModels = []
            return
        }
        builtInModels = models
    }

    private func loadUserModels() {
        guard let data = UserDefaults.standard.data(forKey: "userModelDefinitions"),
              let models = try? JSONDecoder().decode([ModelDefinition].self, from: data) else {
            return
        }
        userDefinedModels = models
    }

    private func saveUserModels() {
        guard let data = try? JSONEncoder().encode(userDefinedModels) else { return }
        UserDefaults.standard.set(data, forKey: "userModelDefinitions")
    }

    private var fallbackDefinition: ModelDefinition {
        ModelDefinition(
            id: "unknown",
            displayName: "Unknown Model",
            provider: "unknown",
            matchPatterns: [],
            matchPriority: -1,
            capabilities: ModelCapabilities(textGeneration: true, documentChat: true),
            reasoningType: .none,
            availableEffortLevels: [],
            apiRoute: .converse,
            parameterRanges: ModelParameterRanges(
                maxTokensMin: 1, maxTokensMax: 4096,
                temperatureMin: 0.0, temperatureMax: 2.0,
                topPMin: 0.01, topPMax: 1.0,
                thinkingBudgetMin: 1024, thinkingBudgetMax: 2048,
                defaultMaxTokens: 4096, defaultTemperature: 0.7,
                defaultTopP: 0.9, defaultThinkingBudget: 1024,
                defaultReasoningEffort: "medium"
            ),
            restrictions: ParameterRestrictions(),
            isBuiltIn: true
        )
    }
}
