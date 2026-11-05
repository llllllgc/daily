import Flutter
import UIKit
import UserNotifications
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Notification actions run in a separate engine and need SQLite/timezone
    // plugins even when the app's main engine is not running.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DailyDataPlugin") { DailyDataPlugin.register(with: registrar) }
  }
}

// Local file exchange and the app-group snapshot used by WidgetKit.
import UniformTypeIdentifiers
import WidgetKit

final class DailyDataPlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
  private var pending: FlutterResult?
  private var exporting = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = DailyDataPlugin()
    registrar.addMethodCallDelegate(instance, channel: FlutterMethodChannel(name: "daily/data", binaryMessenger: registrar.messenger()))
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    if call.method == "updateWidget" {
      guard let content = args["content"] as? String,
            let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.daily") else {
        result(FlutterError(code: "widget", message: "无法访问小组件共享空间", details: nil)); return
      }
      do {
        try content.write(to: directory.appendingPathComponent("daily-widget.json"), atomically: true, encoding: .utf8)
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      } catch { result(FlutterError(code: "widget", message: error.localizedDescription, details: nil)) }
      return
    }
    guard call.method == "exportBackup" || call.method == "importBackup" else { result(FlutterMethodNotImplemented); return }
    guard pending == nil else { result(FlutterError(code: "busy", message: "文件选择器正在使用", details: nil)); return }
    guard let root = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows }).first(where: { $0.isKeyWindow })?.rootViewController else {
      result(FlutterError(code: "window", message: "没有可用的窗口", details: nil)); return
    }
    var presenter = root
    while let presented = presenter.presentedViewController { presenter = presented }
    let picker: UIDocumentPickerViewController
    exporting = call.method == "exportBackup"
    if exporting {
      guard let content = args["content"] as? String else { result(FlutterError(code: "data", message: "缺少备份", details: nil)); return }
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(args["name"] as? String ?? "Daily.json")
      do { try content.write(to: url, atomically: true, encoding: .utf8) }
      catch { result(FlutterError(code: "file", message: error.localizedDescription, details: nil)); return }
      picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    } else { picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json, .data], asCopy: true) }
    pending = result
    picker.delegate = self
    picker.allowsMultipleSelection = false
    presenter.present(picker, animated: true)
  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let callback = pending; pending = nil; callback?(exporting ? false : nil)
  }
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    let callback = pending; pending = nil
    if exporting { callback?(true); return }
    guard let url = urls.first else { callback?(nil); return }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do {
      let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard size <= 50 * 1024 * 1024 else { throw NSError(domain: "Daily", code: 1, userInfo: [NSLocalizedDescriptionKey: "备份文件过大"]) }
      callback?(try String(contentsOf: url, encoding: .utf8))
    } catch { callback?(FlutterError(code: "file", message: error.localizedDescription, details: nil)) }
  }
}
