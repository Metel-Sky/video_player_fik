import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var pendingFiles: [String] = []
  private var openFilesChannel: FlutterMethodChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    deliver(paths: urls.map { $0.path })
  }

  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    deliver(paths: [filename])
    return true
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    deliver(paths: filenames)
  }

  func registerOpenFilesChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "fik_player/open_files",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      if call.method == "getPendingFiles" {
        let files = self.pendingFiles
        self.pendingFiles.removeAll()
        result(files)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    openFilesChannel = channel
  }

  func registerFinderIconChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "fik_player/finder_icons",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "setFileIcon" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String,
            let jpeg = args["jpeg"] as? FlutterStandardTypedData,
            let image = NSImage(data: jpeg.data)
      else {
        result(false)
        return
      }
      let ok = NSWorkspace.shared.setIcon(image, forFile: path, options: [])
      result(ok)
    }
  }

  private func deliver(paths: [String]) {
    guard !paths.isEmpty else { return }
    // Always queue; Dart drains via getPendingFiles so nothing is lost
    // if the Flutter handler is not ready yet.
    pendingFiles.append(contentsOf: paths)
    openFilesChannel?.invokeMethod("openFilesAvailable", arguments: nil)
  }
}
