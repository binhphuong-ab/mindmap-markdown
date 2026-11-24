import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

struct Theme: Identifiable, Equatable {
    let id: String
    let name: String
    let background: [Color]
    let root: [Color]
    let rootText: Color
    let branches: [Color]
    let branchText: Color     // text on level-1 pills
    let text: Color           // text of deeper topics
    let accent: Color         // selection ring
    let isDark: Bool

    func branch(_ i: Int) -> Color { branches[((i % branches.count) + branches.count) % branches.count] }

    static let all: [Theme] = [aurora, midnight, paper, ocean, blossom]
    static func named(_ id: String) -> Theme { all.first { $0.id == id } ?? aurora }

    static let aurora = Theme(
        id: "aurora", name: "Aurora",
        background: [Color(hex: 0xF8F9FE), Color(hex: 0xECEFFA)],
        root: [Color(hex: 0x6D5DFC), Color(hex: 0xB04BF2)], rootText: .white,
        branches: [0xF25F5C, 0xF79F1F, 0x2EC4B6, 0x3A86FF, 0x8338EC, 0xFF4D8D, 0x06A77D].map(Color.init(hex:)),
        branchText: .white, text: Color(hex: 0x2B2D42), accent: Color(hex: 0x6D5DFC), isDark: false)

    static let midnight = Theme(
        id: "midnight", name: "Midnight",
        background: [Color(hex: 0x111827), Color(hex: 0x0B1020)],
        root: [Color(hex: 0x22D3EE), Color(hex: 0x6366F1)], rootText: .white,
        branches: [0xF472B6, 0xFBBF24, 0x34D399, 0x60A5FA, 0xA78BFA, 0xFB7185, 0x2DD4BF].map(Color.init(hex:)),
        branchText: Color(hex: 0x0F172A), text: Color(hex: 0xE5E7EB), accent: Color(hex: 0x22D3EE), isDark: true)

    static let paper = Theme(
        id: "paper", name: "Paper",
        background: [Color(hex: 0xFBF7F0), Color(hex: 0xF2EBDD)],
        root: [Color(hex: 0x3D405B), Color(hex: 0x5C6185)], rootText: Color(hex: 0xFBF7F0),
        branches: [0xE07A5F, 0x81B29A, 0x6D9DC5, 0xB5838D, 0xD4A373, 0x8E7DBE].map(Color.init(hex:)),
        branchText: .white, text: Color(hex: 0x3D405B), accent: Color(hex: 0xE07A5F), isDark: false)

    static let ocean = Theme(
        id: "ocean", name: "Ocean",
        background: [Color(hex: 0xF0F8FB), Color(hex: 0xDDEFF5)],
        root: [Color(hex: 0x0077B6), Color(hex: 0x00B4D8)], rootText: .white,
        branches: [0x0B6E99, 0x1B998B, 0x2D6A4F, 0x5E60CE, 0x3A86FF, 0x00838F].map(Color.init(hex:)),
        branchText: .white, text: Color(hex: 0x14324A), accent: Color(hex: 0x00B4D8), isDark: false)

    static let blossom = Theme(
        id: "blossom", name: "Blossom",
        background: [Color(hex: 0xFFF7F9), Color(hex: 0xFBE9EF)],
        root: [Color(hex: 0xFF6F91), Color(hex: 0xFF9671)], rootText: .white,
        branches: [0xD65DB1, 0xFF6F91, 0xFF9671, 0x845EC2, 0x00A3A3, 0xC34A36].map(Color.init(hex:)),
        branchText: .white, text: Color(hex: 0x4A2C3A), accent: Color(hex: 0xFF6F91), isDark: false)
}

enum LayoutStyle: String, CaseIterable, Identifiable {
    case balanced, right
    var id: String { rawValue }
    var label: String { self == .balanced ? "Balanced" : "Right" }
    var icon: String { self == .balanced ? "arrow.left.and.right" : "arrow.right" }
}
