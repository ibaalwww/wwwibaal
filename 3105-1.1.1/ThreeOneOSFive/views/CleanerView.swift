private func scanSystemCache() {
    guard !systemCacheBusy else { return }
    isScanningSystemCache = true

    DispatchQueue.global(qos: .userInitiated).async {
        let usage = SystemCacheCleanerService.scan()

        DispatchQueue.main.async {
            systemCache = usage
            isScanningSystemCache = false
            log(
                "cleaner: global cache scan accessible=\(usage.accessible) " +
                    "bytes=\(usage.bytes) items=\(usage.itemCount)"
            )
        }
    }
}

private func cleanSystemCache() {
    guard !isCleaningSystemCache else { return }
    isCleaningSystemCache = true

    DispatchQueue.global(qos: .userInitiated).async {
        let result = SystemCacheCleanerService.clean()

        DispatchQueue.main.async {
            systemCache = result.after
            isCleaningSystemCache = false

            let message =
                "Global cache: \(sizeText(result.before.bytes)) → " +
                "\(sizeText(result.after.bytes))\n" +
                "Freed: \(sizeText(result.freedBytes))\n" +
                "Removed: \(result.removedItemCount) items\n" +
                "Skipped/failed: \(result.failedItemCount)"

            activeAlert = .result(message: message)
            log(
                "cleaner: global cache cleaned freed=\(result.freedBytes) " +
                    "removed=\(result.removedItemCount) failed=\(result.failedItemCount)"
            )
        }
    }
}
