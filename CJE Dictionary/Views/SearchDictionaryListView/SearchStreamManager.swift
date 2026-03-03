import Foundation

/// Manages a DictionaryStreamProtocol, stores fetched SearchResultKey results and supports pagination via loadMore().
final class SearchStreamManager: ObservableObject {
    @Published private(set) var results: [SearchResultKey] = []
    private var stream: DictionaryStreamProtocol? = nil
    private var isLoading = false
    // Keep a weak reference for navigation destination previews; optional
    var dictionaryForPreview: DictionaryProtocol? = nil

    func reset(with stream: DictionaryStreamProtocol?) {
        self.stream = stream
        self.results = []
        self.isLoading = false
        // automatically load the first page
        if stream != nil {
            loadMore()
        }
    }

    func loadMore() {
        guard !isLoading, var s = stream else { return }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            var added: [SearchResultKey] = []
            // pull up to 20 more items
            for _ in 0..<20 {
                if let next = s.next() {
                    added.append(next)
                } else {
                    break
                }
            }
            DispatchQueue.main.async {
                self.results.append(contentsOf: added)
                self.isLoading = false
                // store back the iterator if it supports continuing
                self.stream = s
            }
        }
    }
}
