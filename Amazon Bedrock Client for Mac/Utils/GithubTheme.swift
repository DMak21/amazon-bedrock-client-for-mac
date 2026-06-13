//
//  DesignSystem.swift
//  Amazon Bedrock Client for Mac
//

import SwiftUI

// MARK: - Color Initializers

extension Color {
    init(light: Color, dark: Color) {
        self.init(NSColor(name: nil, dynamicProvider: { appearance in
            appearance.name == .darkAqua ? NSColor(dark) : NSColor(light)
        }))
    }

    init(rgba: UInt32) {
        let red = Double((rgba >> 24) & 0xff) / 255.0
        let green = Double((rgba >> 16) & 0xff) / 255.0
        let blue = Double((rgba >> 8) & 0xff) / 255.0
        let alpha = Double(rgba & 0xff) / 255.0
        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
}

// MARK: - Surface Hierarchy

extension Color {
    static let surface0 = Color(
        light: .white, dark: Color(rgba: 0x1414_18ff)
    )
    static let surface1 = Color(
        light: Color(rgba: 0xf8f9_faff), dark: Color(rgba: 0x1e1f_24ff)
    )
    static let surface2 = Color(
        light: Color(rgba: 0xf0f1_f3ff), dark: Color(rgba: 0x2628_2dff)
    )
    static let surface3 = Color(
        light: Color(rgba: 0xe8e9_ecff), dark: Color(rgba: 0x3032_38ff)
    )
}

// MARK: - Accent Colors

extension Color {
    static let accent = Color(
        light: Color(rgba: 0x4f46_e5ff), dark: Color(rgba: 0x818c_f8ff)
    )
    static let accentSubtle = Color(
        light: Color(rgba: 0xeef2_ffff), dark: Color(rgba: 0x2e2b_5eff)
    )
    static let aiGlow = Color(
        light: Color(rgba: 0x7c3a_edff), dark: Color(rgba: 0xa78b_faff)
    )
    static let success = Color(
        light: Color(rgba: 0x0891_b2ff), dark: Color(rgba: 0x22d3_eeff)
    )
    static let warning = Color(
        light: Color(rgba: 0xd976_06ff), dark: Color(rgba: 0xfbbf_24ff)
    )
    static let error = Color(
        light: Color(rgba: 0xdc26_26ff), dark: Color(rgba: 0xf871_71ff)
    )
}

// MARK: - Text Colors

extension Color {
    static let text = Color(
        light: Color(rgba: 0x0f0f_12ff), dark: Color(rgba: 0xfafb_fcff)
    )
    static let secondaryText = Color(
        light: Color(rgba: 0x6b6e_7bff), dark: Color(rgba: 0x9294_a0ff)
    )
    static let tertiaryText = Color(
        light: Color(rgba: 0x9ca3_afff), dark: Color(rgba: 0x8b8e_9aff)
    )
}

// MARK: - Semantic Colors

extension Color {
    static let background = Color.surface0
    static let secondaryBackground = Color.surface1
    static let link = Color.accent
    static let border = Color(
        light: Color(rgba: 0xe4e4_e8ff), dark: Color(rgba: 0x3840_4aff)
    )
    static let divider = Color(
        light: Color(rgba: 0xe5e7_ebff), dark: Color(rgba: 0x2e30_36ff)
    )
    static let checkbox = Color(rgba: 0xb9b9_bbff)
    static let checkboxBackground = Color(rgba: 0xeeee_efff)
}

// MARK: - Animation Constants

extension Animation {
    static let micro = Animation.spring(response: 0.2, dampingFraction: 0.7)
    static let viewTransition = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let expand = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let hover = Animation.easeInOut(duration: 0.15)
}

// MARK: - Spacing Constants

enum DS {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 16
        static let xl: CGFloat = 22
        static let full: CGFloat = 9999
    }

    enum Shadow {
        static let sm = (color: Color.black.opacity(0.05), radius: CGFloat(2), y: CGFloat(1))
        static let md = (color: Color.black.opacity(0.08), radius: CGFloat(8), y: CGFloat(4))
        static let lg = (color: Color.black.opacity(0.12), radius: CGFloat(16), y: CGFloat(8))
    }
}
