import Foundation

struct AppMigrationNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

enum V1ToV2MigrationUtility {
    private static let migrationCompletedKey = "appMigration.v1ToV2.completed"

    static func runIfNeeded(
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) -> AppMigrationNotice? {
        guard isCurrentAppVersionAtLeast2() else {
            return nil
        }

        guard !userDefaults.bool(forKey: migrationCompletedKey) else {
            return nil
        }

        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let documentsURL else {
            return nil
        }

        guard hasLegacyDocumentsData(at: documentsURL, fileManager: fileManager) else {
            return nil
        }

        do {
            let removedCount = try clearDocumentsDirectory(at: documentsURL, fileManager: fileManager)
            userDefaults.set(true, forKey: migrationCompletedKey)

            return AppMigrationNotice(
                title: "Migration Complete",
                message: "We detected data from version 1 and migrated to the new storage system.\n\nWhat changed:\n• Old local dictionary files were cleared.\n• Dictionary downloads are now managed in Settings.\n• You can reinstall any dictionaries from the Available list.\n\nRemoved items: \(removedCount)"
            )
        } catch {
            return AppMigrationNotice(
                title: "Migration Required",
                message: "Version 1 data was detected, but migration could not finish.\n\nPlease restart the app and try again.\n\nError: \(error.localizedDescription)"
            )
        }
    }

    private static func isCurrentAppVersionAtLeast2() -> Bool {
        guard let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return false
        }

        let majorVersion = shortVersion
            .split(separator: ".")
            .first
            .flatMap { Int($0) }

        return (majorVersion ?? 0) >= 2
    }

    private static func hasLegacyDocumentsData(
        at documentsURL: URL,
        fileManager: FileManager
    ) -> Bool {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        return !contents.isEmpty
    }

    private static func clearDocumentsDirectory(
        at documentsURL: URL,
        fileManager: FileManager
    ) throws -> Int {
        let contents = try fileManager.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for itemURL in contents {
            try fileManager.removeItem(at: itemURL)
        }

        return contents.count
    }
}
