//
//  RegionListViewController.swift
//  TurduckenUIKit
//

import UIKit
import SwiftUI
import FanMaker

final class RegionListViewController: UIViewController {

    private let viewModel = FanMakerViewModel()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyContainer = UIStackView()
    private let emptyLabel = UILabel()
    private let fetchButton = UIButton(type: .system)
    private let footerStack = UIStackView()

    private var sdk1CloseObserver: NSObjectProtocol?
    private var sdk2CloseObserver: NSObjectProtocol?
    private var customActionObserver: NSObjectProtocol?
    private var sessionExpiredObserver: NSObjectProtocol?

    private enum Section: Int, CaseIterable {
        case regions1
        case regions2
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Monitored Regions"
        view.backgroundColor = .systemBackground

        viewModel.delegate = self
        setupTableView()
        setupEmptyState()
        setupFooter()
        setupNavBar()
        installSdkObservers()

        updateUIForData()
    }

    deinit {
        for token in [sdk1CloseObserver, sdk2CloseObserver, customActionObserver, sessionExpiredObserver] {
            if let token = token { NotificationCenter.default.removeObserver(token) }
        }
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(RegionCell.self, forCellReuseIdentifier: RegionCell.reuseID)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func setupEmptyState() {
        emptyLabel.text = "No regions are being monitored"
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0

        fetchButton.setTitle("Fetch Regions", for: .normal)
        fetchButton.addTarget(self, action: #selector(fetchTapped), for: .touchUpInside)

        emptyContainer.translatesAutoresizingMaskIntoConstraints = false
        emptyContainer.axis = .vertical
        emptyContainer.spacing = 12
        emptyContainer.alignment = .center
        emptyContainer.addArrangedSubview(emptyLabel)
        emptyContainer.addArrangedSubview(fetchButton)
        view.addSubview(emptyContainer)

        NSLayoutConstraint.activate([
            emptyContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            emptyContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func setupFooter() {
        let showUI1 = UIButton(type: .system)
        showUI1.setTitle("Show FanMaker UI", for: .normal)
        showUI1.addTarget(self, action: #selector(showFanMakerUITapped), for: .touchUpInside)

        let showUI2 = UIButton(type: .system)
        showUI2.setTitle("Show FanMaker UI2", for: .normal)
        showUI2.addTarget(self, action: #selector(showFanMakerUI2Tapped), for: .touchUpInside)

        footerStack.axis = .vertical
        footerStack.alignment = .center
        footerStack.spacing = 12
        footerStack.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        footerStack.isLayoutMarginsRelativeArrangement = true
        footerStack.addArrangedSubview(showUI1)
        footerStack.addArrangedSubview(showUI2)

        let footerSize = footerStack.systemLayoutSizeFitting(
            CGSize(width: view.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        )
        footerStack.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: footerSize.height)
        tableView.tableFooterView = footerStack
    }

    private func setupNavBar() {
        // Three ways in, for comparison.
        //   Sheet — sdk.present(style: .sheet), the SDK's default
        //   Full  — sdk.present(style: .fullScreen), the opt-in
        //   Host  — what this app did before: wrap the representable in a
        //           UIHostingController, walk the hierarchy for a presenter,
        //           register close observers, dismiss by hand
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Sheet", style: .done, target: self,
                            action: #selector(presentSheetTapped)),
            UIBarButtonItem(title: "Full", style: .plain, target: self,
                            action: #selector(presentFullScreenTapped)),
            UIBarButtonItem(title: "Host", style: .plain, target: self,
                            action: #selector(presentFanMakerTapped))
        ]
    }

    @objc private func presentSheetTapped() {
        let began = Date()
        let ok = AppDelegate.fanmakerSDK1.present(style: .sheet)
        NSLog("SAMPLE sheet: present -> \(ok), blocked the main thread for %.3f s",
              Date().timeIntervalSince(began))
    }

    @objc private func presentFullScreenTapped() {
        let began = Date()
        let ok = AppDelegate.fanmakerSDK1.present(style: .fullScreen)
        NSLog("SAMPLE fullScreen: present -> \(ok), blocked the main thread for %.3f s",
              Date().timeIntervalSince(began))
    }

    @objc private func presentFanMakerTapped() {
        presentFanMaker(sdk: AppDelegate.fanmakerSDK1)
    }

    private func installSdkObservers() {
        sdk1CloseObserver = NotificationCenter.default.addObserver(
            forName: FanMakerSDK.closeSdk, object: AppDelegate.fanmakerSDK1, queue: .main
        ) { [weak self] notification in
            if let params = notification.userInfo?["params"] as? [String: Any] {
                print("SDK closed with params: \(params)")
            }
            self?.dismissPresentedFanMakerIfNeeded()
        }

        sdk2CloseObserver = NotificationCenter.default.addObserver(
            forName: FanMakerSDK.closeSdk, object: AppDelegate.fanmakerSDK2, queue: .main
        ) { [weak self] notification in
            if let params = notification.userInfo?["params"] as? [String: Any] {
                print("SDK2 closed with params: \(params)")
            }
            self?.dismissPresentedFanMakerIfNeeded()
        }

        customActionObserver = NotificationCenter.default.addObserver(
            forName: FanMakerSDK.actionNotificationName("customAction"),
            object: AppDelegate.fanmakerSDK1, queue: .main
        ) { notification in
            if let action = notification.userInfo?["action"] as? String {
                print("Action triggered: \(action)")
            }
            if let params = notification.userInfo?["params"] as? [String: Any] {
                print("Parameters: \(params)")
                if let success = params["success"] as? Bool {
                    print("Success: \(success)")
                }
            }
        }

        sessionExpiredObserver = NotificationCenter.default.addObserver(
            forName: FanMakerSDK.actionNotificationName("session_expired"),
            object: AppDelegate.fanmakerSDK1, queue: .main
        ) { notification in
            if let action = notification.userInfo?["action"] as? String {
                print("Action triggered: \(action)")
            }
            if let params = notification.userInfo?["params"] as? [String: Any] {
                print("Parameters: \(params)")
                if let message = params["message"] as? String {
                    print("Session expired message: \(message)")
                }
            }
        }
    }

    private func dismissPresentedFanMakerIfNeeded() {
        if presentedViewController is FanMakerSDKWebViewController {
            dismiss(animated: true)
        }
    }

    private var hasAnyRegions: Bool {
        return !(viewModel.beaconRegions1.isEmpty && viewModel.beaconRegions2.isEmpty)
    }

    private func updateUIForData() {
        emptyContainer.isHidden = hasAnyRegions
        tableView.isHidden = !hasAnyRegions
        if hasAnyRegions { tableView.reloadData() }
    }

    @objc private func fetchTapped() {
        viewModel.updateRegions()
    }

    @objc private func showFanMakerUITapped() {
        var images: [UIImage] = []
        for index in 0...89 {
            if let image = UIImage(named: "loilty-loading00\(index)") {
                images.append(image)
            }
        }
        let nonNilImages = images.compactMap { $0 }
        if !nonNilImages.isEmpty,
           let gif = UIImage.animatedImage(with: nonNilImages, duration: 1.0) {
            AppDelegate.fanmakerSDK1.setLoadingForegroundImage(gif)
        }

        AppDelegate.fanmakerSDK1.setPushNotificationToken("Do you see the token?")
        let url = URL(string: "https://FanMaker/fanmakerdebug")!
        if AppDelegate.fanmakerSDK1.handleUrl(url) {
            presentFanMaker(sdk: AppDelegate.fanmakerSDK1)
        }
    }

    @objc private func showFanMakerUI2Tapped() {
        AppDelegate.fanmakerSDK2.setMemberID("Custom MemberID 2")
        presentFanMaker(sdk: AppDelegate.fanmakerSDK2)
    }

    func presentFanMaker(sdk: FanMakerSDK) {
        let host = UIHostingController(rootView: FanMakerSDKWebViewControllerRepresentable(sdk: sdk))
        topPresenter().present(host, animated: true)
    }

    func presentHelloWorld() {
        let helloVC = HelloWorldViewController()
        topPresenter().present(helloVC, animated: true)
    }

    private func topPresenter() -> UIViewController {
        var top: UIViewController = self
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

extension RegionListViewController: FanMakerViewModelDelegate {
    func fanMakerViewModelDidUpdate(_ model: FanMakerViewModel) {
        updateUIForData()
    }
}

extension RegionListViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .regions1: return viewModel.beaconRegions1.count
        case .regions2: return viewModel.beaconRegions2.count
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .regions1: return "Monitored Regions 1"
        case .regions2: return "Monitored Regions 2"
        }
    }

    private func region(at indexPath: IndexPath) -> Region {
        switch Section(rawValue: indexPath.section)! {
        case .regions1: return viewModel.beaconRegions1[indexPath.row]
        case .regions2: return viewModel.beaconRegions2[indexPath.row]
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RegionCell.reuseID, for: indexPath) as! RegionCell
        cell.configure(with: region(at: indexPath))
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let r = region(at: indexPath)
        let beaconList = BeaconListViewController(beacons: r.beacons(), region: r)
        navigationController?.pushViewController(beaconList, animated: true)
    }
}

final class RegionCell: UITableViewCell {
    static let reuseID = "RegionCell"

    private let titleLabel = UILabel()
    private let majorLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.5
        titleLabel.numberOfLines = 1

        majorLabel.font = .preferredFont(forTextStyle: .subheadline)
        majorLabel.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [titleLabel, majorLabel])
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

    func configure(with region: Region) {
        titleLabel.text = region.uuid
        majorLabel.text = "Major: \(region.major)"
    }
}
