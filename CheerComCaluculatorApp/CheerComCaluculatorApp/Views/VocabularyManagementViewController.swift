import UIKit

final class VocabularyManagementViewController: UITableViewController {

    private enum Section: Int, CaseIterable {
        case atoms = 0
        case bodylines = 1
    }

    private var manifest: VocabularyManifest = VocabularyManifest()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Vocabulary"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(addTapped)
        )
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(doneTapped)
        )
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    private func reload() {
        manifest = VocabularyManager.shared.load()
        tableView.reloadData()
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tv: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .atoms: return "Atoms (\(manifest.atoms.count))"
        case .bodylines: return "Bodylines (\(manifest.bodylines.count))"
        default: return nil
        }
    }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .atoms: return manifest.atoms.count
        case .bodylines: return manifest.bodylines.count
        default: return 0
        }
    }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        switch Section(rawValue: indexPath.section) {
        case .atoms:
            let atom = manifest.atoms[indexPath.row]
            cell.textLabel?.text = atom.displayName
            let tagList = atom.tags.sorted().joined(separator: ", ")
            cell.detailTextLabel?.text = tagList.isEmpty ? atom.id : "\(atom.id) · [\(tagList)]"
        case .bodylines:
            let bl = manifest.bodylines[indexPath.row]
            cell.textLabel?.text = bl.displayName
            cell.detailTextLabel?.text = bl.id
        default: break
        }
        return cell
    }

    override func tableView(_ tv: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { true }

    override func tableView(_ tv: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        do {
            switch Section(rawValue: indexPath.section) {
            case .atoms:
                try VocabularyManager.shared.removeAtom(id: manifest.atoms[indexPath.row].id)
            case .bodylines:
                try VocabularyManager.shared.removeBodyline(id: manifest.bodylines[indexPath.row].id)
            default: break
            }
            reload()
        } catch {
            showAlert("Delete failed: \(error)")
        }
    }

    @objc private func addTapped() {
        let sheet = UIAlertController(title: "Add", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "New Atom", style: .default) { _ in
            self.promptAddAtom()
        })
        sheet.addAction(UIAlertAction(title: "New Bodyline", style: .default) { _ in
            self.promptAddBodyline()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(sheet, animated: true)
    }

    private func promptAddAtom() {
        let alert = UIAlertController(
            title: "New Atom",
            message: "Enter a display name (e.g. Back Handspring). Id is auto-generated.",
            preferredStyle: .alert
        )
        alert.addTextField { $0.placeholder = "Display name" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self = self, let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            let id = Self.slugify(name)
            do {
                try VocabularyManager.shared.addAtom(id: id, displayName: name)
                self.reload()
            } catch {
                self.showAlert("Add atom failed: \(error)")
            }
        })
        present(alert, animated: true)
    }

    private func promptAddBodyline() {
        let alert = UIAlertController(
            title: "New Bodyline",
            message: "Enter a display name (e.g. Tuck Peak). Id is auto-generated.",
            preferredStyle: .alert
        )
        alert.addTextField { $0.placeholder = "Display name" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self = self, let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            let id = Self.slugify(name)
            do {
                try VocabularyManager.shared.addBodyline(id: id, displayName: name)
                self.reload()
            } catch {
                self.showAlert("Add bodyline failed: \(error)")
            }
        })
        present(alert, animated: true)
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private static func slugify(_ name: String) -> String {
        return name
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
