import Foundation

struct LimitedCleanerUsage: Equatable {
    let totalBytes: Int64
    let fileCount: Int

    static let empty = LimitedCleanerUsage(
        totalBytes: 0,
        fileCount: 0
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

enum LimitedCleanerService {

    private static let fileManager = FileManager.default

    // Only directories belonging to NIGHTSHIFT's own sandbox.
    private static var cacheDirectory: URL {
        fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
    }

    private static var temporaryDirectory: URL {
        fileManager.temporaryDirectory
    }

    private static var allowedDirectories: [URL] {
        [
            cacheDirectory,
            temporaryDirectory
        ]
    }

    // MARK: - Scan

    static func scan() -> LimitedCleanerUsage {
        var totalBytes: Int64 = 0
        var fileCount = 0

        for directory in allowedDirectories {
            scanDirectory(
                directory,
                totalBytes: &totalBytes,
                fileCount: &fileCount
            )
        }

        return LimitedCleanerUsage(
            totalBytes: totalBytes,
            fileCount: fileCount
        )
    }

    // MARK: - Items

    static func items() -> [LimitedCleanerItem] {
        var result: [LimitedCleanerItem] = []

        for directory in allowedDirectories {
            collectItems(
                from: directory,
                into: &result
            )
        }

        return result.sorted {
            if $0.size != $1.size {
                return $0.size > $1.size
            }

            return $0.name.localizedCaseInsensitiveCompare(
                $1.name
            ) == .orderedAscending
        }
    }

    // MARK: - Clean

    @discardableResult
    static func clean() -> LimitedCleanerUsage {
        for directory in allowedDirectories {
            guard
                let children = try? fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [
                        .isDirectoryKey,
                        .isSymbolicLinkKey
                    ],
                    options: []
                )
            else {
                continue
            }

            for child in children {
                do {
                    let values = try child.resourceValues(
                        forKeys: [
                            .isDirectoryKey,
                            .isSymbolicLinkKey
                        ]
                    )

                    // Never follow symbolic links.
                    guard values.isSymbolicLink != true else {
                        continue
                    }

                    try fileManager.removeItem(
                        at: child
                    )
                } catch {
                    // Some files can legitimately be in use.
                    // Continue cleaning the remaining accessible files.
                    continue
                }
            }
        }

        return scan()
    }

    // MARK: - Private scan helpers

    private static func scanDirectory(
        _ directory: URL,
        totalBytes: inout Int64,
        fileCount: inout Int
    ) {
        guard
            fileManager.fileExists(
                atPath: directory.path
            )
        else {
            return
        }

        guard
            let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                    .fileSizeKey
                ],
                options: [],
                errorHandler: { _, _ in
                    true
                }
            )
        else {
            return
        }

        for case let url as URL in enumerator {
            guard
                let values = try? url.resourceValues(
                    forKeys: [
                        .isRegularFileKey,
                        .isSymbolicLinkKey,
                        .fileSizeKey
                    ]
                ),
                values.isSymbolicLink != true
            else {
                continue
            }

            guard values.isRegularFile == true else {
                continue
            }

            totalBytes += Int64(
                max(
                    0,
                    values.fileSize ?? 0
                )
            )

            fileCount += 1
        }
    }

    private static func collectItems(
        from directory: URL,
        into result: inout [LimitedCleanerItem]
    ) {
        guard
            fileManager.fileExists(
                atPath: directory.path
            )
        else {
            return
        }

        guard
            let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .isSymbolicLinkKey,
                    .fileSizeKey
                ],
                options: [],
                errorHandler: { _, _ in
                    true
                }
            )
        else {
            return
        }

        for case let url as URL in enumerator {
            guard
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

            let size = Int64(
                max(
                    0,
                    values.fileSize ?? 0
                )
            )

            result.append(
                LimitedCleanerItem(
                    id: url.path,
                    url: url,
                    size: size
                )
            )
        }
    }
}
