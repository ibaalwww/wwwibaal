import Foundation

struct SystemCacheUsage: Equatable {
    let accessible: Bool
    let bytes: Int64
    let itemCount: Int

    static let unavailable = SystemCacheUsage(
        accessible: false,
        bytes: 0,
        itemCount: 0
    )
}

struct SystemCacheCleanResult: Equatable {
    let before: SystemCacheUsage
    let after: SystemCacheUsage
    let freedBytes: Int64
    let removedItemCount: Int
    let failedItemCount: Int
}

enum SystemCacheCleanerService {

    private static let fileManager = FileManager.default

    // MARK: - Public API

    static func scan() -> SystemCacheUsage {
        let roots = accessibleCacheRoots()

        guard !roots.isEmpty else {
            return .unavailable
        }

        var totalBytes: Int64 = 0
        var itemCount = 0

        for root in roots {
            scanDirectory(
                root,
                totalBytes: &totalBytes,
                itemCount: &itemCount
            )
        }

        return SystemCacheUsage(
            accessible: true,
            bytes: totalBytes,
            itemCount: itemCount
        )
    }

    static func clean() -> SystemCacheCleanResult {
        let before = scan()

        guard before.accessible else {
            return SystemCacheCleanResult(
                before: before,
                after: before,
                freedBytes: 0,
                removedItemCount: 0,
                failedItemCount: 0
            )
        }

        var freedBytes: Int64 = 0
        var removedItemCount = 0
        var failedItemCount = 0

        for root in accessibleCacheRoots() {
            cleanDirectory(
                root,
                freedBytes: &freedBytes,
                removedItemCount: &removedItemCount,
                failedItemCount: &failedItemCount
            )
        }

        let after = scan()

        return SystemCacheCleanResult(
            before: before,
            after: after,
            freedBytes: min(
                max(0, freedBytes),
                max(0, before.bytes)
            ),
            removedItemCount: removedItemCount,
            failedItemCount: failedItemCount
        )
    }

    // MARK: - Cache Roots

    private static func accessibleCacheRoots() -> [URL] {
        var roots: [URL] = []

        // App's own Caches directory.
        if let cachesURL = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first {
            if isUsableDirectory(cachesURL) {
                roots.append(cachesURL)
            }
        }

        // App's temporary directory.
        let temporaryURL = fileManager.temporaryDirectory

        if isUsableDirectory(temporaryURL) {
            if !roots.contains(where: {
                $0.standardizedFileURL.path ==
                temporaryURL.standardizedFileURL.path
            }) {
                roots.append(temporaryURL)
            }
        }

        return roots
    }

    // MARK: - Scan

    private static func scanDirectory(
        _ directory: URL,
        totalBytes: inout Int64,
        itemCount: inout Int
    ) {
        guard isUsableDirectory(directory) else {
            return
        }

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isDirectoryKey,
                .isSymbolicLinkKey,
                .fileSizeKey
            ],
            options: [],
            errorHandler: { _, _ in
                true
            }
        ) else {
            return
        }

        for case let url as URL in enumerator {
            guard !isSymbolicLink(url) else {
                enumerator.skipDescendants()
                continue
            }

            guard let values = try? url.resourceValues(
                forKeys: [
                    .isRegularFileKey,
                    .fileSizeKey
                ]
            ) else {
                continue
            }

            guard values.isRegularFile == true else {
                continue
            }

            totalBytes += Int64(
                max(0, values.fileSize ?? 0)
            )

            itemCount += 1
        }
    }

    // MARK: - Clean

    private static func cleanDirectory(
        _ directory: URL,
        freedBytes: inout Int64,
        removedItemCount: inout Int,
        failedItemCount: inout Int
    ) {
        guard isUsableDirectory(directory) else {
            return
        }

        guard let children = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isDirectoryKey,
                .isSymbolicLinkKey,
                .fileSizeKey
            ],
            options: []
        ) else {
            return
        }

        for child in children {
            guard isSafeChild(
                child,
                of: directory
            ) else {
                failedItemCount += 1
                continue
            }

            guard !isSymbolicLink(child) else {
                continue
            }

            do {
                let values = try child.resourceValues(
                    forKeys: [
                        .isRegularFileKey,
                        .isDirectoryKey,
                        .isSymbolicLinkKey,
                        .fileSizeKey
                    ]
                )

                guard values.isSymbolicLink != true else {
                    continue
                }

                let size = Int64(
                    max(0, values.fileSize ?? 0)
                )

                try fileManager.removeItem(at: child)

                freedBytes += size
                removedItemCount += 1
            } catch {
                failedItemCount += 1
            }
        }
    }

    // MARK: - Safety

    private static func isUsableDirectory(
        _ url: URL
    ) -> Bool {
        let path = url.standardizedFileURL.path

        guard fileManager.fileExists(atPath: path) else {
            return false
        }

        guard
            let values = try? url.resourceValues(
                forKeys: [.isDirectoryKey]
            ),
            values.isDirectory == true
        else {
            return false
        }

        return fileManager.isReadableFile(atPath: path)
    }

    private static func isSymbolicLink(
        _ url: URL
    ) -> Bool {
        guard
            let values = try? url.resourceValues(
                forKeys: [.isSymbolicLinkKey]
            )
        else {
            return false
        }

        return values.isSymbolicLink == true
    }

    private static func isSafeChild(
        _ child: URL,
        of directory: URL
    ) -> Bool {
        let parentPath = directory
            .standardizedFileURL
            .path

        let childPath = child
            .standardizedFileURL
            .path

        return childPath.hasPrefix(parentPath + "/")
    }
}
