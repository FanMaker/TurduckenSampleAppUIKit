//
//  BeaconActionsViewController.swift
//  TurduckenUIKit
//

import UIKit

final class BeaconActionsViewController: UIViewController, UITableViewDataSource {

    private let actions: [BeaconAction]
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    init(actions: [BeaconAction]) {
        self.actions = actions.reversed()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Beacon Actions"
        view.backgroundColor = .systemBackground

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.allowsSelection = false
        tableView.register(BeaconActionCell.self, forCellReuseIdentifier: BeaconActionCell.reuseID)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { actions.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: BeaconActionCell.reuseID, for: indexPath) as! BeaconActionCell
        cell.configure(with: actions[indexPath.row])
        return cell
    }
}

final class BeaconActionCell: UITableViewCell {
    static let reuseID = "BeaconActionCell"

    private let majorMinorLabel = UILabel()
    private let seenLabel = UILabel()
    private let statusLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        majorMinorLabel.font = .preferredFont(forTextStyle: .body)
        seenLabel.font = .preferredFont(forTextStyle: .footnote)
        seenLabel.textColor = .secondaryLabel
        statusLabel.font = .preferredFont(forTextStyle: .footnote)

        let stack = UIStackView(arrangedSubviews: [majorMinorLabel, seenLabel, statusLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with action: BeaconAction) {
        majorMinorLabel.text = "Major: \(action.major)   Minor: \(action.minor)"
        let elapsed = Int(Date().timeIntervalSince(action.seenAt))
        seenLabel.text = "Seen: \(elapsed) seconds ago"

        let statusText = action.posted ? "Posted" : "Pending"
        let statusColor: UIColor = action.posted ? .systemGreen : .systemRed
        let attributed = NSMutableAttributedString(string: "Status: ")
        attributed.append(NSAttributedString(
            string: statusText,
            attributes: [
                .foregroundColor: statusColor,
                .font: UIFont.preferredFont(forTextStyle: .footnote).withTraits(.traitBold)
            ]
        ))
        statusLabel.attributedText = attributed
    }
}

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
