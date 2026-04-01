import Foundation

struct TranscriptionLanguage: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String {
        code
    }

    var menuLabel: String {
        "\(name) (\(code))"
    }
}
