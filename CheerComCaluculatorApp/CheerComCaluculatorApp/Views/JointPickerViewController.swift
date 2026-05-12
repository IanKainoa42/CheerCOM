import UIKit


final class JointPickerViewController: UIViewController {
    struct Section {
        let title: String
        let joints: [Joint]
    }

    var joints: [Joint] = []
    var selectedJointName: String?
    var onSelectJoint: ((String) -> Void)?

    private let searchController = UISearchController(searchResultsController: nil)
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let sections: [Section] = [
        Section(title: "Core", joints: [.hips, .spine, .spine1, .spine2, .neck, .head]),
        Section(title: "Left Arm", joints: [.leftShoulder, .leftArm, .leftForeArm, .leftHand]),
        Section(title: "Right Arm", joints: [.rightShoulder, .rightArm, .rightForeArm, .rightHand]),
        Section(title: "Left Leg", joints: [.leftUpLeg, .leftLeg, .leftFoot]),
        Section(title: "Right Leg", joints: [.rightUpLeg, .rightLeg, .rightFoot])
    ]

    private var filteredSections: [Section] {
        let availableJointNames = Set(joints.map(\.rawValue))
        let baseSections: [Section] = sections.compactMap { section in
            let matchingJoints = section.joints.filter { availableJointNames.contains($0.rawValue) }
            guard !matchingJoints.isEmpty else { return nil }
            return Section(title: section.title, joints: matchingJoints)
        }

        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !query.isEmpty else { return baseSections }

        return baseSections.compactMap { section in
            let matches = section.joints.filter {
                Self.displayName(for: $0.rawValue).localizedCaseInsensitiveContains(query)
            }
            guard !matches.isEmpty else { return nil }
            return Section(title: section.title, joints: matches)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Choose Joint"
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )

        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = "Search joints"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 56
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "JointCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private static func displayName(for jointName: String) -> String {
        let clean = jointName.replacingOccurrences(of: "mixamorig_", with: "")
        var result = ""
        for (index, char) in clean.enumerated() {
            if index > 0 && char.isUppercase {
                result += " "
            }
            result.append(char)
        }
        return result
    }
}

extension JointPickerViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        filteredSections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredSections[section].joints.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        filteredSections[section].title
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "JointCell", for: indexPath)
        var configuration = cell.defaultContentConfiguration()
        let joint = filteredSections[indexPath.section].joints[indexPath.row]
        let jointName = joint.rawValue
        configuration.text = Self.displayName(for: jointName)
        configuration.secondaryText = jointName
        configuration.secondaryTextProperties.color = .secondaryLabel
        configuration.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        cell.contentConfiguration = configuration
        cell.accessoryType = jointName == selectedJointName ? .checkmark : .none
        return cell
    }
}

extension JointPickerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let jointName = filteredSections[indexPath.section].joints[indexPath.row].rawValue
        onSelectJoint?(jointName)
        dismiss(animated: true)
    }
}

extension JointPickerViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        tableView.reloadData()
    }
}
