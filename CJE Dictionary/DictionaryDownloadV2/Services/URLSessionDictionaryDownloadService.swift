import Foundation

actor URLSessionDictionaryDownloadService: DictionaryDownloadService {
    private let session: URLSession
    private var continuation: AsyncStream<DictionaryJobSnapshot>.Continuation?
    private var tasks: [DictionaryID: Task<Void, Never>] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    nonisolated func snapshots() -> AsyncStream<DictionaryJobSnapshot> {
        AsyncStream { continuation in
            Task { await self.setContinuation(continuation) }
        }
    }

    func enqueue(_ item: DictionaryManifestItem) async {
        tasks[item.id]?.cancel()

        let task = Task {
            await emit(id: item.id, state: .queued)

            do {
                let request = URLRequest(url: item.downloadURL)
                let (bytes, response) = try await session.bytes(for: request)

                let expectedLength = response.expectedContentLength > 0 ? response.expectedContentLength : nil
                var downloadedBytes: Int64 = 0
                var nextProgressEmitAt: Int64 = 0

                let tempFileURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("dict-download-\(item.id.rawValue)-\(UUID().uuidString).tmp")

                FileManager.default.createFile(atPath: tempFileURL.path, contents: nil)
                let fileHandle = try FileHandle(forWritingTo: tempFileURL)
                defer {
                    try? fileHandle.close()
                }

                var buffer = Data()
                buffer.reserveCapacity(64 * 1024)

                await emit(
                    id: item.id,
                    state: .downloading(progress: DictionaryJobProgress(completedBytes: 0, totalBytes: expectedLength))
                )

                for try await byte in bytes {
                    if Task.isCancelled {
                        throw CancellationError()
                    }

                    buffer.append(byte)
                    downloadedBytes += 1

                    if buffer.count >= 64 * 1024 {
                        try fileHandle.write(contentsOf: buffer)
                        buffer.removeAll(keepingCapacity: true)
                    }

                    if downloadedBytes >= nextProgressEmitAt {
                        await emit(
                            id: item.id,
                            state: .downloading(
                                progress: DictionaryJobProgress(
                                    completedBytes: downloadedBytes,
                                    totalBytes: expectedLength
                                )
                            )
                        )
                        nextProgressEmitAt = downloadedBytes + 256 * 1024
                    }
                }

                if !buffer.isEmpty {
                    try fileHandle.write(contentsOf: buffer)
                }

                if Task.isCancelled {
                    await emit(id: item.id, state: .cancelled)
                    try? FileManager.default.removeItem(at: tempFileURL)
                    return
                }

                await emit(
                    id: item.id,
                    state: .downloading(
                        progress: DictionaryJobProgress(
                            completedBytes: downloadedBytes,
                            totalBytes: expectedLength ?? downloadedBytes
                        )
                    )
                )
                await emit(id: item.id, state: .downloaded(tempFile: tempFileURL))
            } catch is CancellationError {
                await emit(id: item.id, state: .cancelled)
            } catch {
                await emit(id: item.id, state: .failed(message: error.localizedDescription))
            }

            tasks[item.id] = nil
        }

        tasks[item.id] = task
    }

    func cancel(id: DictionaryID) async {
        tasks[id]?.cancel()
        tasks[id] = nil
        await emit(id: id, state: .cancelled)
    }

    func cancelAll() async {
        for (id, task) in tasks {
            task.cancel()
            await emit(id: id, state: .cancelled)
        }
        tasks.removeAll()
    }

    private func setContinuation(_ newValue: AsyncStream<DictionaryJobSnapshot>.Continuation) {
        continuation = newValue
    }

    private func emit(id: DictionaryID, state: DictionaryJobState) {
        continuation?.yield(
            DictionaryJobSnapshot(
                id: id,
                state: state,
                updatedAt: Date()
            )
        )
    }
}
