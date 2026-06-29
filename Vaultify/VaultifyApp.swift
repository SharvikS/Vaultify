//
//  VaultifyApp.swift
//  Vaultify
//
//  Created by Sharvik Sutar on 27/06/26.
//

import SwiftUI
import SwiftData

@main
struct VaultifyApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Appliance.self,
            WarrantyRecord.self,
            ServiceLog.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // Launch-argument controls used for demos and deterministic screenshot capture.
    // e.g. `-VaultDemoSeed YES -VaultSkipBoot YES -VaultInitialTab forecast`
    private var wantsDemoSeed: Bool { UserDefaults.standard.bool(forKey: "VaultDemoSeed") }
    private var skipBoot: Bool { UserDefaults.standard.bool(forKey: "VaultSkipBoot") }

    @State private var booted = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()

                if !booted {
                    VaultBootView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                if wantsDemoSeed {
                    DemoVault.seedIfEmpty(sharedModelContainer.mainContext)
                }
                if skipBoot {
                    booted = true
                } else {
                    try? await Task.sleep(for: .seconds(3.4))
                    withAnimation(.easeOut(duration: 0.6)) { booted = true }
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
