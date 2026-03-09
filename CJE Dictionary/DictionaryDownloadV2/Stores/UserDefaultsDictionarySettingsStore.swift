import Foundation

struct UserDefaultsDictionarySettingsStore: DictionarySettingsStore {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func boolValue(for key: String, default defaultValue: Bool) -> Bool {
        userDefaults.object(forKey: key) as? Bool ?? defaultValue
    }

    func setBoolValue(_ value: Bool, for key: String) {
        userDefaults.set(value, forKey: key)
    }

    func stringArrayValue(for key: String) -> [String] {
        userDefaults.stringArray(forKey: key) ?? []
    }

    func setStringArrayValue(_ value: [String], for key: String) {
        userDefaults.set(value, forKey: key)
    }
}
