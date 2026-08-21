import Foundation

struct LimitedCleanerUsage: Equatable {
    let totalBytes: Int64
    let fileCount: Int

    let cacheBytes: Int64
    let temporaryBytes: Int64
    let removableItemCount: Int

    init(
        totalBytes: Int64,
        fileCount: Int,
        cacheBytes: Int64 = 0,
        temporaryBytes: Int64 = 0,
        removableItemCount: Int = 0
    ) {
        self.totalBytes = totalBytes
        self.fileCount = fileCount
        self.cacheBytes = cacheBytes
        self.temporaryBytes = temporaryBytes
        self.removableItemCount = removableItemCount
    }

    static let empty = LimitedCleanerUsage(
        totalBytes: 0,
        fileCount: 0,
        cacheBytes: 0,
        temporaryBytes: 0,
        removableItemCount: 0
    )
}

struct LimitedCleanerItem: Identifiable, Equatable {
    let id: String
    let url: URL
    let size: Int64

    var name: String {
        url.lastPathComponent
    }
}

struct LimitedCleanerCleanResult: Equatable {
    let before: LimitedCleanerUsage
    let after: LimitedCleanerUsage
    let freedBytes: Int64
    let removedItemCount: Int
    let failedItemCount: Int
}

enum LimitedCleanerService {

    private static let fileManager = FileManager.default

    // MARK: - Public Scan

    static func scan(
        containerURL: URL,
        rootValidator: (URL) -> Bool
    ) throws -> LimitedCleanerUsage {
        guard rootValidator(containerURL) else {
            throw CleanerError.invalidContainer
        }

        let cacheURL = containerURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)

        let tmpURL = containerURL
            .appendingPathComponent("tmp", isDirectory: true)

        var cacheBytes: Int64 = 0
        var temporaryBytes: Int64 = 0
        var cacheCount = 0
        var temporaryCount = 0

        scanDirectory(
            cacheURL,
            rootURL: containerURL,
            rootValidator: rootValidator,
            totalBytes: &cacheBytes,
            fileCount: &cacheCount
        )

        scanDirectory(
            tmpURL,
            rootURL: containerURL,
            rootValidator: rootValidator,
            totalBytes: &temporaryBytes,
            fileCount: &temporaryCount
        )

        return LimitedCleanerUsage(
            totalBytes: cacheBytes + temporaryBytes,
            fileCount: cacheCount + temporaryCount,
            cacheBytes: cacheBytes,
            temporaryBytes: temporaryBytes,
            removableItemCount: cacheCount + temporaryCount
        )
    }

    // MARK: - Public Clean

    static func clean(
        containerURL: URL,
        rootValidator: (URL) -> Bool
    ) throws -> LimitedCleanerCleanResult {
        guard rootValidator(containerURL) else {
            throw CleanerError.invalidContainer
        }

        let before = try scan(
            containerURL: containerURL,
            rootValidator: rootValidator
        )

        let cacheURL = containerURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)

        let tmpURL = containerURL
            .appendingPathComponent("tmp", isDirectory: true)

        var freedBytes: Int64 = 0
        var removedItemCount = 0
        var failedItemCount = 0

        cleanDirectory(
            cacheURL,
            rootURL: containerURL,
            rootValidator: rootValidator,
            freedBytes: &freedBytes,
            removedItemCount: &removedItemCount,
            failedItemCount: &failedItemCount
        )

        cleanDirectory(
            tmpURL,
            rootURL: containerURL,
            rootValidator: rootValidator,
            freedBytes: &freedBytes,
            removedItemCount: &removedItemCount,
            failedItemCount: &failedItemCount
        )

        let after = try scan(
            containerURL: containerURL,
            rootValidator: rootValidator
        )

        return LimitedCleanerCleanResult(
            before: before,
            after: after,
            freedBytes: max(
                0,
                min(
                    freedBytes,
                    before.totalBytes
                )
            ),
            removedItemCount: removedItemCount,
            failedItemCount: failedItemCount
        )
    }

    // MARK: - Legacy Convenience API

    static func scan() -> LimitedCleanerUsage {
        let cacheURL = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first

        let tmpURL = fileManager.temporaryDirectory

        var cacheBytes: Int64 = 0
        var temporaryBytes: Int64 = 0
        var cacheCount = 0
        var temporaryCount = 0

        if let cacheURL {
            scanDirectory(
                cacheURL,
                rootURL: cacheURL,
                rootValidator: { _ in true },
                totalBytes: &cacheBytes,
                fileCount: &cacheCount
            )
        }

        scanDirectory(
            tmpURL,
            rootURL: tmpURL,
            rootValidator: { _ in true },
            totalBytes: &temporaryBytes,
            fileCount: &temporaryCount
        )

        return LimitedCleanerUsage(
            totalBytes: cacheBytes + temporaryBytes,
            fileCount: cacheCount + temporaryCount,
            cacheBytes: cacheBytes,
            temporaryBytes: temporaryBytes,
            removableItemCount: cacheCount + temporaryCount
        )
    }

    @discardableResult
    static func clean() -> LimitedCleanerUsage {
        let cacheURL = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first

        if let cacheURL {
            removeChildren(
                from: cacheURL,
                rootURL: cacheURL,
                rootValidator: { _ in true }
            )
        }

        removeChildren(
            from: fileManager.temporaryDirectory,
            rootURL: fileManager.temporaryDirectory,
            rootValidator: { _ in true }
        )

        return scan()
    }

    // MARK: - Private Scan

    private static func scanDirectory(
        _ directory: URL,
        rootURL: URL,
        rootValidator: (URL) -> Bool,
        totalBytes: inout Int64,
        fileCount: inout Int
    ) {
        guard
            fileManager.fileExists(atPath: directory.path),
            isSafePath(directory, rootURL: rootURL),
            rootValidator(directory)
        else {
            return
        }

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey,
                .isDirectoryKey
            ],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in
                true
            }
        ) else {
            return
        }

        for case let url as URL in enumerator {
            guard
                isSafePath(url, rootURL: rootURL),
                rootValidator(url),
                let values = try? url.resourceValues(
                    forKeys: [
                        .isRegularFileKey,
                        .isSymbolicLinkKey,
                        .fileSizeKey
                    ]
                ),
                values.isSymbolicLink != true,
                values.isRegularFile == true
            else {
                continue
            }

            totalBytes += Int64(
                max(0, values.fileSize ?? 0)
            )

            fileCount += 1
        }
    }

    // MARK: - Private Clean

    private static func cleanDirectory(
        _ directory: URL,
        rootURL: URL,
        rootValidator: (URL) -> Bool,
        freedBytes: inout Int64,
        removedItemCount: inout Int,
        failedItemCount: inout Int
    ) {
        guard
            fileManager.fileExists(atPath: directory.path),
            isSafePath(directory, rootURL: rootURL),
            rootValidator(directory)
        else {
            return
        }

        removeChildren(
            from: directory,
            rootURL: rootURL,
            rootValidator: rootValidator,
            freedBytes: &freedBytes,
            removedItemCount: &removedItemCount,
            failedItemCount: &failedItemCount
        )
    }

    private static func removeChildren(
        from directory: URL,
        rootURL: URL,
        rootValidator: (URL) -> Bool,
        freedBytes: inout Int64,
        removedItemCount: inout Int,
        failedItemCount: inout Int
    ) {
        guard let children = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey
            ],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for child in children {
            guard
                isSafePath(child, rootURL: rootURL),
                rootValidator(child)
            else {
                failedItemCount += 1
                continue
            }

            do {
                let values = try child.resourceValues(
                    forKeys: [
                        .isDirectoryKey,
                        .isRegularFileKey,
                        .isSymbolicLinkKey,
                        .fileSizeKey
                    ]
                )

                // Never follow or delete symbolic links.
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

    private static func isSafePath(
        _ url: URL,
        rootURL: URL
    ) -> Bool {
        let root = rootURL.standardizedFileURL.resolvingSymlinksInPath()
        let candidate = url.standardizedFileURL.resolvingSymlinksInPath()

        let rootPath = root.path
        let candidatePath = candidate.path

        guard candidatePath == rootPath ||
              candidatePath.hasPrefix(rootPath + "/")
        else {
            return false
        }

        return true
    }

    // MARK: - Errors

    enum CleanerError: LocalizedError {
        case invalidContainer

        var errorDescription: String? {
            switch self {
            case .invalidContainer:
                return "The application container is not valid or accessible."
            }
        }
    }
}
