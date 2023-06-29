//
//  igaApp.swift
//  iga
//
//  Created by Leonce Nshuti on 6/29/23.
//

import SwiftUI

@main
struct igaApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
