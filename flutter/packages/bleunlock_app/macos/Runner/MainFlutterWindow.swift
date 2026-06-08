import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let closeToBackgroundDelegate = CloseToBackgroundWindowDelegate()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setContentSize(NSSize(width: 1440, height: 900))
    self.center()
    self.setFrameAutosaveName("BLEUnlockMainWindow")
    self.delegate = closeToBackgroundDelegate

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}

private final class CloseToBackgroundWindowDelegate: NSObject, NSWindowDelegate {
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    sender.orderOut(nil)
    return false
  }
}
