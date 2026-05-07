//
//  FanMakerViewModel.swift
//  TurduckenUIKit
//

import Foundation
import FanMaker

struct BeaconAction {
    var id: Int
    var major: Int
    var minor: Int
    var seenAt: Date
    var posted: Bool
}

extension BeaconAction {
    init(from fmAction: FanMakerSDKBeaconRangeAction, id: Int) {
        self.id = id
        self.major = fmAction.major
        self.minor = fmAction.minor
        self.seenAt = fmAction.seenAt
        self.posted = true
    }
}

struct Region {
    var id: Int
    var uuid: String
    var major: Int
    var within: Bool = false
    var actions: [BeaconAction] = []

    func beacons() -> [Beacon] {
        var minors: Set<Int> = []
        for action in actions where major == action.major {
            minors.insert(action.minor)
        }
        return minors.map { Beacon(id: $0, region: self) }
    }
}

struct Beacon {
    var id: Int
    var region: Region
}

protocol FanMakerViewModelDelegate: AnyObject {
    func fanMakerViewModelDidUpdate(_ model: FanMakerViewModel)
}

final class FanMakerViewModel: NSObject, FanMakerSDKBeaconsManagerDelegate {
    weak var delegate: FanMakerViewModelDelegate?

    private(set) var beaconRegions1: [Region] = []
    private(set) var beaconRegions2: [Region] = []

    private let beaconsManager1: FanMakerSDKBeaconsManager
    private let beaconsManager2: FanMakerSDKBeaconsManager

    override init() {
        beaconsManager1 = FanMakerSDKBeaconsManager(sdk: AppDelegate.fanmakerSDK1)
        beaconsManager2 = FanMakerSDKBeaconsManager(sdk: AppDelegate.fanmakerSDK2)
        super.init()
        beaconsManager1.delegate = self
        beaconsManager2.delegate = self
    }

    func updateRegions() {
        beaconsManager1.requestAuthorization()
        beaconsManager2.requestAuthorization()
    }

    private func notifyUpdate() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.fanMakerViewModelDidUpdate(self)
        }
    }

    private func selectedRegions(for manager: FanMakerSDKBeaconsManager) -> [Region] {
        return manager == beaconsManager1 ? beaconRegions1 : beaconRegions2
    }

    private func setRegions(_ regions: [Region], for manager: FanMakerSDKBeaconsManager) {
        if manager == beaconsManager1 {
            beaconRegions1 = regions
        } else {
            beaconRegions2 = regions
        }
    }

    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didChangeAuthorization status: FanMakerSDKBeaconsAuthorizationStatus) {
        switch status {
        case .notDetermined: NSLog("FANMAKER ERROR: Authorization Not determined")
        case .restricted:    NSLog("FANMAKER ERROR: Authorization Restricted")
        case .denied:        NSLog("FANMAKER ERROR: Authorization Denied")
        case .authorizedAlways:
            NSLog("FANMAKER SUCCESS: Authorization Always")
            manager.fetchBeaconRegions()
        case .authorizedWhenInUse:
            NSLog("FANMAKER SUCCESS: Authorization When in use")
            manager.fetchBeaconRegions()
        }
    }

    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didReceiveBeaconRegions regions: [FanMakerSDKBeaconRegion]) {
        manager.startScanning(regions)
        let mapped = regions.map { Region(id: $0.id, uuid: $0.uuid, major: Int($0.major) ?? 0) }
        setRegions(mapped, for: manager)
        notifyUpdate()
    }

    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didEnterRegion region: FanMakerSDKBeaconRegion) {
        NSLog("Enter FM region: \(region.uuid)")
        let updated = selectedRegions(for: manager).map { r -> Region in
            var copy = r
            if copy.id == region.id { copy.within = true }
            return copy
        }
        setRegions(updated, for: manager)
        notifyUpdate()
    }

    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didExitRegion region: FanMakerSDKBeaconRegion) {
        NSLog("Exit FM region: \(region.uuid)")
        let updated = selectedRegions(for: manager).map { r -> Region in
            var copy = r
            if copy.id == region.id { copy.within = false }
            return copy
        }
        setRegions(updated, for: manager)
        notifyUpdate()
    }

    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didUpdateBeaconRangeActionsHistory queue: [FanMakerSDKBeaconRangeAction]) {
        NSLog("the queue was updated to \(queue.count) items")
        let updated = selectedRegions(for: manager).map { region -> Region in
            let actions: [BeaconAction] = queue
                .filter { $0.uuid.uppercased() == region.uuid.uppercased() }
                .enumerated()
                .map { BeaconAction(from: $0.element, id: $0.offset) }
            var copy = region
            copy.actions = actions
            return copy
        }
        setRegions(updated, for: manager)
        notifyUpdate()
    }

    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didUpdateBeaconRangeActionsSendList queue: [FanMakerSDKBeaconRangeAction]) {}

    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didFailWithError error: FanMakerSDKBeaconsError) {
        switch error {
        case .userSessionNotFound: NSLog("FANMAKER ERROR: User session not found")
        case .serverError:         NSLog("FANMAKER ERROR: Server error")
        case .unknown:             NSLog("FANMAKER ERROR: Unknown")
        }
    }
}
