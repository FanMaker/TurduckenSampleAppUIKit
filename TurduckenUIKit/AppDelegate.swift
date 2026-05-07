//
//  AppDelegate.swift
//  TurduckenUIKit
//

import UIKit
import FanMaker
import CoreLocation

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    static var fanmakerSDK1: FanMakerSDK!
    static var fanmakerSDK2: FanMakerSDK!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let sdk1 = FanMakerSDK()
        sdk1.initialize(apiKey: "<fanmaker_api_key>")
        AppDelegate.fanmakerSDK1 = sdk1
        AppDelegate.fanmakerSDK1.enableLocationTracking()

        let sdk2 = FanMakerSDK()
        sdk2.initialize(apiKey: "<fanmaker_api_key>")
        AppDelegate.fanmakerSDK2 = sdk2
        AppDelegate.fanmakerSDK2.disableLocationTracking()

        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
