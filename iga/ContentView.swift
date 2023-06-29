//
//  ContentView.swift
//  iga
//
//  Created by Leonce Nshuti on 6/29/23.
//

import UIKit

// Define a custom data structure for the items
struct Item {
    let name: String
}

// Create a ViewController to display the list of items
class ViewController: UIViewController {
    var items: [Item] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up the UI
        let tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(tableView)
        
        // Add a button to add new items
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addButtonTapped))
        navigationItem.rightBarButtonItem = addButton
    }

    @objc func addButtonTapped() {
        // Show an alert to get the user's input
        let alertController = UIAlertController(title: "Add Item", message: nil, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "Item Name"
        }
        let addAction = UIAlertAction(title: "Add", style: .default) { _ in
            // Create a new item and add it to the list
            if let itemName = alertController.textFields?.first?.text {
                let newItem = Item(name: itemName)
                self.items.append(newItem)
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        }
        alertController.addAction(addAction)
        present(alertController, animated: true, completion: nil)
    }
}

// Implement UITableViewDataSource to populate the table view
extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let item = items[indexPath.row]
        cell.textLabel?.text = item.name
        return cell
    }
}

// Create an instance of ViewController and set it as the root view controller
let viewController = ViewController()
let navigationViewController = UINavigationController(rootViewController: viewController)

// Create and configure a UIWindow to hold the view controller's view
let window = UIWindow(frame: UIScreen.main.bounds)
window.rootViewController = navigationViewController
window.makeKeyAndVisible()

// Run the app on a simulator
let simulatorType = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "iPhone 11"
let device = SimDeviceType.fromIdentifier(simulatorType)
let runtime = SimRuntime.OSVersion.iOS.withBuildNumber("13.0")
let simDevice = try SimDevice.bootedDevice(deviceName: device, runtime: runtime)
let app = try simDevice!.installApp(atPath: "/path/to/your/app") // Replace "/path/to/your/app" with the path to your app's .app file
try app.launchApp(with: nil)
RunLoop.current.run()
