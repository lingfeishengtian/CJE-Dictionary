import SwiftUI

enum SettingsKeys {
    static let kanjiShowIconText = "kanjiSettingsShowIconText"
    static let dictionaryCondensedList = "dictionaryStyleListStyleCondensed"
}

struct Settings: View {
    @StateObject private var coordinator: DefaultDictionaryDownloadCoordinator
    @StateObject private var viewModel: SettingsViewModel

    @MainActor
    init(
        coordinator: DefaultDictionaryDownloadCoordinator? = nil,
        settingsStore: any DictionarySettingsStore = UserDefaultsDictionarySettingsStore()
    ) {
        let resolvedCoordinator = coordinator ?? DefaultDictionaryDownloadCoordinator()
        _coordinator = StateObject(wrappedValue: resolvedCoordinator)
        _viewModel = StateObject(
            wrappedValue: SettingsViewModel(
                coordinator: resolvedCoordinator,
                settingsStore: settingsStore
            )
        )
    }

    var body: some View {
        Form {
            InstalledDictionariesSection(
                viewModel: viewModel,
                installedRecords: coordinator.installedRecords,
                orderedInstalledRecords: orderedInstalledRecords
            )

            AvailableDictionariesSection(
                items: sortedAvailableItems,
                installedIDs: Set(coordinator.installedRecords.keys),
                onInstall: { id in
                    Task { await viewModel.install(id) }
                }
            )

            InstallFromURLSection(
                dictionaryURLInput: $viewModel.dictionaryURLInput
            ) {
                await viewModel.installCustomFromInput()
            }

            JobsSection(snapshots: sortedJobSnapshots) { id in
                Task { await viewModel.retry(id) }
            }

            PreferencesSection(viewModel: viewModel)
        }
        .navigationTitle("settings")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .task {
            await viewModel.refresh()
        }
        .alert(
            "Download Error",
            isPresented: Binding(
                get: { viewModel.userFacingError != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissError()
                    }
                }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    viewModel.dismissError()
                }
            },
            message: {
                Text(viewModel.userFacingError ?? "Unknown error")
            }
        )
    }

    private var sortedJobSnapshots: [DictionaryJobSnapshot] {
        coordinator.jobs.values.sorted { $0.id.rawValue < $1.id.rawValue }
    }

    private var sortedAvailableItems: [DictionaryManifestItem] {
        coordinator.manifestItems
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private var orderedInstalledRecords: [DictionaryInstallRecord] {
        viewModel.orderedInstalledRecords(from: coordinator.installedRecords)
    }
}

#Preview {
    NavigationStack {
        Settings()
    }
}
