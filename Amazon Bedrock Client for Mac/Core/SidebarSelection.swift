//
//  SidebarSelection.swift
//  Amazon Bedrock Client for Mac
//
//  Created by Na, Sanghwa on 2023/10/06.
//

import Foundation

struct ComparisonEntry: Identifiable, Hashable {
    let id: String
    var title: String
    let createdAt: Date
}

enum SidebarSelection: Hashable, Identifiable {
    var id: String {
        switch self {
        case .newChat:
            return "newChat"
        case .chat(let chat):
            return chat.chatId
        case .comparison(let comparisonId):
            return "comparison-\(comparisonId)"
        }
    }

    case newChat
    case chat(ChatModel)
    case comparison(String)
}
