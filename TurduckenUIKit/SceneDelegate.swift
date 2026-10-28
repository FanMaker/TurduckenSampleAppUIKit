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

        // Scripted check of the SDK-owned presentation path, so it can be
        // driven without taps:
        //   xcrun simctl launch <sim> fanmaker.TurduckenUIKit --fanmaker-present-test
        if ProcessInfo.processInfo.arguments.contains("--fanmaker-present-test") {
            runPresentationCheck()
        }
    }

    private func runPresentationCheck() {
        guard let sdk = AppDelegate.fanmakerSDK1 else {
            NSLog("CHECK ABORT: no sdk instance")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NSLog("CHECK 1 present: isPresenting before = \(sdk.isPresenting)")
            let began = Date()
            let first = sdk.present()
            NSLog("CHECK 1 present: blocked the main thread for %.3f s", Date().timeIntervalSince(began))
            NSLog("CHECK 1 present: returned \(first), isPresenting after = \(sdk.isPresenting)")
            NSLog("CHECK 1 present: on screen = \(String(describing: type(of: self.topPresented())))")

            NSLog("CHECK 2 one-screen rule: second present returned \(sdk.present()) (want false)")

            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                NSLog("CHECK 3 dismiss: isPresenting before = \(sdk.isPresenting)")
                sdk.dismiss()

                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    NSLog("CHECK 3 dismiss: isPresenting after = \(sdk.isPresenting)")
                    NSLog("CHECK 3 dismiss: on screen = \(String(describing: type(of: self.topPresented())))")

                    NSLog("CHECK 4 reopen: present returned \(sdk.present()) (want true)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        NSLog("CHECK 4 reopen: isPresenting = \(sdk.isPresenting)")

                        // CHECK 5: what NUX actually received. The SDK's request
                        // headers reach the page only through server.mjs baking
                        // them into window.FanmakerSDK.headers, so this reads the
                        // same object NUX's device registration reads. Anything
                        // credential-shaped is redacted before it is logged.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                            let js = """
                            (() => {
                              const h = (window.FanmakerSDK && window.FanmakerSDK.headers) || null;
                              if (!h) return 'window.FanmakerSDK.headers is UNDEFINED at ' + location.href;
                              const out = {};
                              for (const k of Object.keys(h).sort()) {
                                const v = h[k];
                                out[k] = /token|identifiers|authorization/i.test(k) ? '<redacted>' : v;
                              }
                              return JSON.stringify({ url: location.href, headers: out });
                            })()
                            """
                            sdk.currentWebView?.evaluateJavaScript(js) { value, error in
                                NSLog("CHECK 5 headers: \(value ?? "nil") error=\(String(describing: error))")

                                // CHECK 6: deep link into the webview that is already
                                // open, then read the same object again. That reload
                                // must carry the headers just like the first load.
                                let handled = sdk.handleUrl(URL(string: "turducken://fanmaker/prizes?fm_check=6")!)
                                NSLog("CHECK 6 live deep link: handleUrl returned \(handled)")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                                    sdk.currentWebView?.evaluateJavaScript(js) { value, _ in
                                        NSLog("CHECK 6 headers after live deep link: \(value ?? "nil")")
                                        self.runLinkPolicyCheck(sdk)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// CHECK 7: which taps leave for the browser. Each step clicks an injected
    /// link and logs where the webview ended up; the SDK itself logs "handing
    /// ... to the system browser" when it ejects one. The step that should eject
    /// runs last, because Safari then takes the foreground and timers stop.
    private func runLinkPolicyCheck(_ sdk: FanMakerSDK) {
        func click(_ href: String) {
            sdk.currentWebView?.evaluateJavaScript(
                "(() => { const a = document.createElement('a'); a.href = '\(href)'; document.body.appendChild(a); a.click(); })()")
        }
        func report(_ step: String) {
            NSLog("CHECK 7\(step): webview now at \(sdk.currentWebView?.url?.absoluteString ?? "nil")")
        }
        let ourPage = (sdk.baseURL ?? "") + "/home"

        // 7a: the SSO sign-in tap - our page to our broker. Must stay.
        click("https://tmauth.fanmaker.com/fm-eject-check")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            report("a SSO broker tap, want tmauth.fanmaker.com")
            // 7c: a tap on a third-party page, as mid-SSO. Must stay.
            sdk.currentWebView?.evaluateJavaScript("location.assign('https://example.org/')")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                click("https://www.iana.org/")
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    report("c tap on a third-party page, want www.iana.org")
                    // 7b: a partner link tapped on our page. Must leave for Safari.
                    sdk.currentWebView?.evaluateJavaScript("location.assign('\(ourPage)')")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                        NSLog("CHECK 7b tapping a partner link on \(sdk.currentWebView?.url?.absoluteString ?? "nil"), want Safari")
                        click("https://example.com/")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            report("b after the partner tap, unchanged if ejected")
                            NSLog("CHECK DONE")
                        }
                    }
                }
            }
        }
    }

    private func topPresented() -> UIViewController? {
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
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

        // Scriptable equivalents of the two nav bar buttons, so the SDK-owned
        // presentation can be driven from `xcrun simctl openurl`.
        if components?.scheme == "turducken" && components?.host == "present" {
            let first = AppDelegate.fanmakerSDK1.present()
            NSLog("SAMPLE: sdk.present() -> \(first), isPresenting=\(AppDelegate.fanmakerSDK1.isPresenting)")
            let second = AppDelegate.fanmakerSDK1.present()
            NSLog("SAMPLE: second sdk.present() -> \(second) (expected false)")
            return
        }

        if components?.scheme == "turducken" && components?.host == "dismiss" {
            NSLog("SAMPLE: before dismiss, isPresenting=\(AppDelegate.fanmakerSDK1.isPresenting)")
            AppDelegate.fanmakerSDK1.dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NSLog("SAMPLE: after dismiss, isPresenting=\(AppDelegate.fanmakerSDK1.isPresenting)")
            }
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
