import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private var tapQueue: [[String: Any]] = []
  private var tapSeq: Int = 0
  private var previousCenterDelegate: UNUserNotificationCenterDelegate?
  private var pushTapsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    let center = UNUserNotificationCenter.current()
    if center.delegate !== self {
      previousCenterDelegate = center.delegate
      center.delegate = self
    }

    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PushTapsChannel") {
      let channel = FlutterMethodChannel(
        name: "com.yourapp/push_taps",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result([])
          return
        }
        switch call.method {
        case "takeNotificationTaps":
          let taps = self.tapQueue
          self.tapQueue.removeAll()
          result(taps)
        case "reclaimNotificationDelegate":
          let center = UNUserNotificationCenter.current()
          if center.delegate !== self {
            self.previousCenterDelegate = center.delegate
            center.delegate = self
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      pushTapsChannel = channel
    }
  }

  private func recordTap(_ userInfo: [AnyHashable: Any]) {
    tapSeq += 1

    let url = userInfo["url"] as? String
    let messageId = (userInfo["gcm.message_id"] as? String)
      ?? (userInfo["google.message_id"] as? String)
      ?? ""
    // The backend's own id for the push (`message_id` in its data), which the
    // notification-open callback reports. Not the same as Firebase's id above.
    let dataMessageId = userInfo["message_id"] as? String ?? ""

    tapQueue.append([
      "seq": tapSeq,
      "url": url ?? "",
      "messageId": messageId,
      "dataMessageId": dataMessageId,
      "timestamp": Int(Date().timeIntervalSince1970 * 1000)
    ])
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
      recordTap(response.notification.request.content.userInfo)
    }

    if let previous = previousCenterDelegate,
       previous !== self,
       previous.responds(to: #selector(UNUserNotificationCenterDelegate
         .userNotificationCenter(_:didReceive:withCompletionHandler:))) {
      previous.userNotificationCenter?(
        center, didReceive: response, withCompletionHandler: completionHandler
      )
    } else {
      super.userNotificationCenter(
        center, didReceive: response, withCompletionHandler: completionHandler
      )
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if let previous = previousCenterDelegate,
       previous !== self,
       previous.responds(to: #selector(UNUserNotificationCenterDelegate
         .userNotificationCenter(_:willPresent:withCompletionHandler:))) {
      previous.userNotificationCenter?(
        center, willPresent: notification, withCompletionHandler: completionHandler
      )
    } else {
      super.userNotificationCenter(
        center, willPresent: notification, withCompletionHandler: completionHandler
      )
    }
  }
}