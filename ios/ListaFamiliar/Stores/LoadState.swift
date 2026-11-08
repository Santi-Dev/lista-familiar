import Foundation

/// Estado de una carga remota.
enum LoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(String)

    var isLoading: Bool { self == .loading }

    var errorMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}
