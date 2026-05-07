//
//  SceneDelegate.swift
//  TurduckenUIKit
//

import UIKit
import FanMaker

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var rootRegionList: RegionListViewController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        let regionList = RegionListViewController()
        rootRegionList = regionList
        let nav = UINavigationController(rootViewController: regionList)
        window.rootViewController = nav
        self.window = window
        window.makeKeyAndVisible()

        if let url = connectionOptions.urlContexts.first?.url {
            handleIncoming(url: url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleIncoming(url: url)
    }

    private func handleIncoming(url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if components?.scheme == "turducken" && components?.host == "hello" {
            print("Opening Hello World sheet")
            rootRegionList?.presentHelloWorld()
            return
        }

        if AppDelegate.fanmakerSDK1.canHandleUrl(url) {
            if components?.scheme == "turducken" {
                if AppDelegate.fanmakerSDK1.handleUrl(url) {
                    print("FanMaker handled the URL, opening the FanMaker UI")
                    rootRegionList?.presentFanMaker(sdk: AppDelegate.fanmakerSDK1)
                } else {
                    print("FanMaker failed to handle the URL")
                }
            }
            if components?.scheme == "turducken2" {
                if AppDelegate.fanmakerSDK2.handleUrl(url) {
                    print("FanMaker2 handled the URL, opening the FanMaker2 UI")
                    rootRegionList?.presentFanMaker(sdk: AppDelegate.fanmakerSDK2)
                } else {
                    print("FanMaker2 failed to handle the URL")
                }
            }
        } else {
            print("FanMaker cannot handle the URL")
        }
    }
}
