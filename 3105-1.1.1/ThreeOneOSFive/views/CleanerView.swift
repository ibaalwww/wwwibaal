private func scanSystemCache() {
    guard !systemCacheBusy else { return }

    isScanningSystemCache = true

    DispatchQueue.global(qos: .userInitiated).async {
        let fileManager = FileManager.default

        let cacheURL = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first

        let temporaryURL = fileManager.temporaryDirectory

        var totalBytes: Int64 = 0
        var itemCount = 0

        func scanDirectory(_ url: URL) {
            guard
                let enumerator = fileManager.enumerator(
                    at: url,
                    includingPropertiesForKeys: [
                        .isRegularFileKey,
                        .fileSizeKey,
                        .isDirectoryKey
                    ],
                    options: [
                        .skipsHiddenFiles
                    ]
                )
            else {
                return
            }

            for case let fileURL as URL in enumerator {
                do {
                    let values = try fileURL.resourceValues(
                        forKeys: [
                            .isRegularFileKey,
                            .fileSizeKey,
                            .isDirectoryKey
                        ]
                    )

                    if values.isRegularFile == true {
                        totalBytes += Int64(values.fileSize ?? 0)
                        itemCount += 1
                    }
                } catch {
                    continue
                }
            }
        }

        if let cacheURL {
            scanDirectory(cacheURL)
        }

        scanDirectory(temporaryURL)

        let usage = SystemCacheUsage(
            bytes: totalBytes,
            itemCount: itemCount,
            accessible: cacheURL != nil
        )

        DispatchQueue.main.async {
            systemCache = usage
            isScanningSystemCache = false

            log(
                "cleaner: local cache scan " +
                "accessible=\(usage.accessible) " +
                "bytes=\(usage.bytes) " +
                "items=\(usage.itemCount)"
            )
        }
    }
}

private func cleanSystemCache() {
    guard !isCleaningSystemCache else { return }

    isCleaningSystemCache = true

    DispatchQueue.global(qos: .userInitiated).async {
        let fileManager = FileManager.default

        let cacheURL = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first

        let temporaryURL = fileManager.temporaryDirectory

        var removedItems = 0
        var failedItems = 0

        func cleanDirectory(_ url: URL) {
            guard
                let contents = try? fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
            else {
                return
            }

            for item in contents {
                do {
                    try fileManager.removeItem(at: item)
                    removedItems += 1
                } catch {
                    failedItems += 1
                }
            }
        }

        let before = scanLocalCacheUsage()

        if let cacheURL {
            cleanDirectory(cacheURL)
        }

        cleanDirectory(temporaryURL)

        let after = scanLocalCacheUsage()

        let freedBytes = max(
            0,
            before.bytes - after.bytes
        )

        let resultMessage =
            "Local cache: \(sizeText(before.bytes)) → " +
            "\(sizeText(after.bytes))\n" +
            "Freed: \(sizeText(freedBytes))\n" +
            "Removed: \(removedItems) items\n" +
            "Skipped/failed: \(failedItems)"

        DispatchQueue.main.async {
            systemCache = after
            isCleaningSystemCache = false

            activeAlert = .result(
                message: resultMessage
            )

            log(
                "cleaner: local cache cleaned " +
                "freed=\(freedBytes) " +
                "removed=\(removedItems) " +
                "failed=\(failedItems)"
            )
        }
    }
}

private func scanLocalCacheUsage() -> SystemCacheUsage {
    let fileManager = FileManager.default

    let cacheURL = fileManager.urls(
        for: .cachesDirectory,
        in: .userDomainMask
    ).first

    let temporaryURL = fileManager.temporaryDirectory

    var totalBytes: Int64 = 0
    var itemCount = 0

    func scan(_ url: URL) {
        guard
            let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .fileSizeKey
                ],
                options: [.skipsHiddenFiles]
            )
        else {
            return
        }

        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(
                    forKeys: [
                        .isRegularFileKey,
                        .fileSizeKey
                    ]
                )

                if values.isRegularFile == true {
                    totalBytes += Int64(values.fileSize ?? 0)
                    itemCount += 1
                }
            } catch {
                continue
            }
        }
    }

    if let cacheURL {
        scan(cacheURL)
    }

    scan(temporaryURL)

    return SystemCacheUsage(
        bytes: totalBytes,
        itemCount: itemCount,
        accessible: cacheURL != nil
    )
}

private struct SystemCacheUsage {
    let bytes: Int64
    let itemCount: Int
    let accessible: Bool

    static let unavailable = SystemCacheUsage(
        bytes: 0,
        itemCount: 0,
        accessible: false
    )
}
