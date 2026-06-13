//
//  UserPromptTemplateManager.swift
//  Amazon Bedrock Client for Mac
//

import Foundation
import Combine
import Logging

struct UserPromptTemplate: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, content: String) {
        self.id = id
        self.name = name
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    static let examples: [UserPromptTemplate] = [
        UserPromptTemplate(
            name: "Summarize this",
            content: "Please provide a concise summary of the following:"
        ),
        UserPromptTemplate(
            name: "Explain like I'm 5",
            content: "Explain the following concept in simple terms that a 5-year-old could understand:"
        ),
        UserPromptTemplate(
            name: "Write unit tests",
            content: "Write comprehensive unit tests for the following code:"
        ),
        UserPromptTemplate(
            name: "Fix this code",
            content: "Identify and fix any bugs in the following code. Explain what was wrong:"
        )
    ]
}

@MainActor
class UserPromptTemplateManager: ObservableObject {
    static let shared = UserPromptTemplateManager()
    private var logger = Logger(label: "UserPromptTemplateManager")

    @Published var templates: [UserPromptTemplate] = [] {
        didSet {
            saveTemplates()
        }
    }

    private let storageKey = "userPromptTemplates"

    private init() {
        loadTemplates()
    }

    // MARK: - CRUD Operations

    func addTemplate(_ template: UserPromptTemplate) {
        templates.append(template)
        logger.info("Added user prompt template: \(template.name)")
    }

    func addTemplate(name: String, content: String) {
        let template = UserPromptTemplate(name: name, content: content)
        addTemplate(template)
    }

    func updateTemplate(_ template: UserPromptTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            var updated = template
            updated.updatedAt = Date()
            templates[index] = updated
            logger.info("Updated user prompt template: \(template.name)")
        }
    }

    func deleteTemplate(_ template: UserPromptTemplate) {
        templates.removeAll { $0.id == template.id }
        logger.info("Deleted user prompt template: \(template.name)")
    }

    func deleteTemplate(at offsets: IndexSet) {
        templates.remove(atOffsets: offsets)
    }

    func moveTemplate(from source: IndexSet, to destination: Int) {
        templates.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Persistence

    private func loadTemplates() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([UserPromptTemplate].self, from: data),
           !decoded.isEmpty {
            self.templates = decoded
            logger.info("Loaded \(decoded.count) user prompt templates")
        } else {
            self.templates = UserPromptTemplate.examples
            logger.info("Initialized with example user prompt templates")
        }
    }

    private func saveTemplates() {
        if let encoded = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
            logger.debug("Saved \(templates.count) user prompt templates")
        }
    }

    // MARK: - Import Examples

    func importExampleTemplates() {
        for example in UserPromptTemplate.examples {
            if !templates.contains(where: { $0.name == example.name }) {
                templates.append(example)
            }
        }
        logger.info("Imported example user prompt templates")
    }
}
