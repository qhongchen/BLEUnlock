import AppKit
import ApplicationServices
import CoreBluetooth
import CoreGraphics
import FlutterMacOS
import Security
import SQLite3

@_silgen_name("SACLockScreenImmediate")
private func SACLockScreenImmediate() -> Int32

public class BleunlockMacosPlugin: NSObject, FlutterPlugin {
  private let scanner: BleunlockBleScanner
  private let sessionController: BleunlockSessionController
  private let secureStore: BleunlockSecureStore
  private let trayController: BleunlockTrayController
  private let startupController: BleunlockStartupController
  private let unlockController: BleunlockUnlockController

  init(
    scanner: BleunlockBleScanner,
    sessionController: BleunlockSessionController,
    secureStore: BleunlockSecureStore,
    trayController: BleunlockTrayController,
    startupController: BleunlockStartupController,
    unlockController: BleunlockUnlockController
  ) {
    self.scanner = scanner
    self.sessionController = sessionController
    self.secureStore = secureStore
    self.trayController = trayController
    self.startupController = startupController
    self.unlockController = unlockController
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let scanner = BleunlockBleScanner()
    let sessionController = BleunlockSessionController()
    let secureStore = BleunlockSecureStore()
    let trayController = BleunlockTrayController()
    let startupController = BleunlockStartupController()
    let unlockController = BleunlockUnlockController(
      secureStore: secureStore,
      sessionController: sessionController
    )
    let instance = BleunlockMacosPlugin(
      scanner: scanner,
      sessionController: sessionController,
      secureStore: secureStore,
      trayController: trayController,
      startupController: startupController,
      unlockController: unlockController
    )

    let scannerMethodChannel = FlutterMethodChannel(
      name: "bleunlock_macos/ble_scanner_methods",
      binaryMessenger: registrar.messenger
    )
    registrar.addMethodCallDelegate(instance, channel: scannerMethodChannel)

    let scannerEventChannel = FlutterEventChannel(
      name: "bleunlock_macos/ble_scanner_events",
      binaryMessenger: registrar.messenger
    )
    scannerEventChannel.setStreamHandler(scanner)

    let sessionMethodChannel = FlutterMethodChannel(
      name: "bleunlock_macos/session_methods",
      binaryMessenger: registrar.messenger
    )
    registrar.addMethodCallDelegate(instance, channel: sessionMethodChannel)

    let sessionEventChannel = FlutterEventChannel(
      name: "bleunlock_macos/session_events",
      binaryMessenger: registrar.messenger
    )
    sessionEventChannel.setStreamHandler(sessionController)

    let secureStoreMethodChannel = FlutterMethodChannel(
      name: "bleunlock_macos/secure_store_methods",
      binaryMessenger: registrar.messenger
    )
    registrar.addMethodCallDelegate(instance, channel: secureStoreMethodChannel)

    let trayMethodChannel = FlutterMethodChannel(
      name: "bleunlock_macos/tray_methods",
      binaryMessenger: registrar.messenger
    )
    registrar.addMethodCallDelegate(instance, channel: trayMethodChannel)

    let trayEventChannel = FlutterEventChannel(
      name: "bleunlock_macos/tray_events",
      binaryMessenger: registrar.messenger
    )
    trayEventChannel.setStreamHandler(trayController)

    let startupMethodChannel = FlutterMethodChannel(
      name: "bleunlock_macos/startup_methods",
      binaryMessenger: registrar.messenger
    )
    registrar.addMethodCallDelegate(instance, channel: startupMethodChannel)

    let unlockMethodChannel = FlutterMethodChannel(
      name: "bleunlock_macos/unlock_methods",
      binaryMessenger: registrar.messenger
    )
    registrar.addMethodCallDelegate(instance, channel: unlockMethodChannel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getScannerCapability":
      result(scanner.capability())
    case "startScan":
      scanner.startScan()
      result(nil)
    case "stopScan":
      scanner.stopScan()
      result(nil)
    case "lock":
      do {
        try sessionController.lock()
        result(nil)
      } catch {
        result(FlutterError(code: "lock-failed", message: "\(error)", details: nil))
      }
    case "wakeDisplay":
      sessionController.wakeDisplay()
      result(nil)
    case "isLocked":
      result(sessionController.isLocked())
    case "writeSecret":
      handleWriteSecret(call, result: result)
    case "readSecret":
      handleReadSecret(call, result: result)
    case "deleteSecret":
      handleDeleteSecret(call, result: result)
    case "setStatus":
      handleSetTrayStatus(call, result: result)
    case "showQuickMenu":
      trayController.showQuickMenu()
      result(nil)
    case "isEnabled":
      result(startupController.isEnabled())
    case "setEnabled":
      handleSetStartupEnabled(call, result: result)
    case "getCapability":
      result(unlockController.capability())
    case "openPermissionSettings":
      unlockController.openPermissionSettings()
      result(nil)
    case "unlock":
      result(unlockController.unlock())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleWriteSecret(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard
      let arguments = call.arguments as? [String: Any],
      let key = arguments["key"] as? String,
      let value = arguments["value"] as? String
    else {
      result(FlutterError(code: "bad-arguments", message: "Expected key and value", details: nil))
      return
    }

    do {
      try secureStore.writeSecret(key: key, value: value)
      result(nil)
    } catch {
      result(FlutterError(code: "keychain-write-failed", message: "\(error)", details: nil))
    }
  }

  private func handleReadSecret(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard
      let arguments = call.arguments as? [String: Any],
      let key = arguments["key"] as? String
    else {
      result(FlutterError(code: "bad-arguments", message: "Expected key", details: nil))
      return
    }

    do {
      result(try secureStore.readSecret(key: key))
    } catch {
      result(FlutterError(code: "keychain-read-failed", message: "\(error)", details: nil))
    }
  }

  private func handleDeleteSecret(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard
      let arguments = call.arguments as? [String: Any],
      let key = arguments["key"] as? String
    else {
      result(FlutterError(code: "bad-arguments", message: "Expected key", details: nil))
      return
    }

    do {
      try secureStore.deleteSecret(key: key)
      result(nil)
    } catch {
      result(FlutterError(code: "keychain-delete-failed", message: "\(error)", details: nil))
    }
  }

  private func handleSetTrayStatus(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard
      let arguments = call.arguments as? [String: Any],
      let status = arguments["status"] as? String
    else {
      result(FlutterError(code: "bad-arguments", message: "Expected status", details: nil))
      return
    }

    trayController.setStatus(
      status,
      recentDeviceSummary: arguments["recentDeviceSummary"] as? String,
      isMonitoring: arguments["isMonitoring"] as? Bool ?? false
    )
    result(nil)
  }

  private func handleSetStartupEnabled(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard
      let arguments = call.arguments as? [String: Any],
      let enabled = arguments["enabled"] as? Bool
    else {
      result(FlutterError(code: "bad-arguments", message: "Expected enabled", details: nil))
      return
    }

    do {
      try startupController.setEnabled(enabled)
      result(nil)
    } catch {
      result(FlutterError(code: "startup-update-failed", message: "\(error)", details: nil))
    }
  }
}

final class BleunlockBleScanner: NSObject, FlutterStreamHandler, CBCentralManagerDelegate {
  private static let exposureNotificationService = CBUUID(string: "FD6F")
  private static let legacyDiscoveryRssiThreshold = -70
  private static let legacySignalTimeout: TimeInterval = 60

  private var centralManager: CBCentralManager?
  private var eventSink: FlutterEventSink?
  private var shouldScan = false
  private let nameResolver = BleunlockDeviceNameResolver()
  private var cachedDevices: [String: BleunlockCachedDeviceInfo] = [:]

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    if shouldScan {
      ensureCentralManager()
      startScanIfPoweredOn()
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopScan()
    eventSink = nil
    centralManager = nil
    return nil
  }

  func startScan() {
    shouldScan = true
    ensureCentralManager()
    startScanIfPoweredOn()
  }

  func stopScan() {
    shouldScan = false
    centralManager?.stopScan()
  }

  func capability() -> [String: Any] {
    guard let state = centralManager?.state else {
      return [
        "kind": "supported",
        "description": "Bluetooth status will be checked when scanning starts"
      ]
    }
    return capability(for: state)
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    guard shouldScan else {
      return
    }
    startScanIfPoweredOn()
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    if containsExposureNotification(advertisementData) {
      return
    }

    let deviceId = peripheral.identifier.uuidString
    let now = Date()
    let rssi = RSSI.intValue > 0 ? 0 : RSSI.intValue
    let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
    let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
    let cached = validCachedDevice(deviceId: deviceId, now: now)
    if cached == nil && rssi < Self.legacyDiscoveryRssiThreshold {
      return
    }

    let resolved = nameResolver.resolvedDeviceInfo(
      uuid: peripheral.identifier,
      localName: localName,
      peripheralName: peripheral.name,
      manufacturerData: manufacturerData,
      rssi: rssi
    )
    let displayName = resolved.displayName ?? cached?.displayName
    let addressHint = resolved.addressHint ?? cached?.addressHint ?? deviceId
    let resolvedNameSource = resolved.displayNameSource ?? cached?.displayNameSource ?? "uuid"

    cachedDevices[deviceId] = BleunlockCachedDeviceInfo(
      displayName: displayName,
      addressHint: addressHint,
      displayNameSource: resolvedNameSource,
      lastSeenAt: now
    )

    var event: [String: Any] = [
      "deviceId": deviceId,
      "addressHint": addressHint,
      "rssi": rssi,
      "seenAtMillis": Int(now.timeIntervalSince1970 * 1000),
      "resolvedNameSource": resolvedNameSource,
    ]
    if let displayName {
      event["displayName"] = displayName
    }
    if let rawLocalName = BleunlockDeviceNameResolver.normalized(localName) {
      event["rawLocalName"] = rawLocalName
    }
    if let peripheralName = BleunlockDeviceNameResolver.normalized(peripheral.name) {
      event["peripheralName"] = peripheralName
    }
    if let manufacturerData {
      event["manufacturerData"] = Array(manufacturerData)
    }

    eventSink?(event)
  }

  private func validCachedDevice(
    deviceId: String,
    now: Date
  ) -> BleunlockCachedDeviceInfo? {
    guard let cached = cachedDevices[deviceId] else {
      return nil
    }
    guard now.timeIntervalSince(cached.lastSeenAt) < Self.legacySignalTimeout else {
      cachedDevices.removeValue(forKey: deviceId)
      return nil
    }
    return cached
  }

  private func containsExposureNotification(_ advertisementData: [String: Any]) -> Bool {
    guard let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] else {
      return false
    }
    return serviceUUIDs.contains(Self.exposureNotificationService)
  }

  private func startScanIfPoweredOn() {
    guard centralManager?.state == .poweredOn else {
      return
    }
    centralManager?.scanForPeripherals(
      withServices: nil,
      options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
    )
  }

  private func ensureCentralManager() {
    if centralManager == nil {
      centralManager = CBCentralManager(delegate: self, queue: nil)
    }
  }

  private func capability(for state: CBManagerState) -> [String: Any] {
    switch state {
    case .poweredOn:
      return ["kind": "supported"]
    case .poweredOff:
      return ["kind": "poweredOff", "description": "Bluetooth is powered off"]
    case .unauthorized:
      return ["kind": "permissionDenied", "description": "Bluetooth permission is denied"]
    case .unsupported:
      return ["kind": "unsupported", "description": "Bluetooth LE is unsupported"]
    case .resetting:
      return ["kind": "temporarilyUnavailable", "description": "Bluetooth is resetting"]
    case .unknown:
      return ["kind": "unknown", "description": "Bluetooth state is unknown"]
    @unknown default:
      return ["kind": "unknown", "description": "Bluetooth state is unknown"]
    }
  }
}

private struct BleunlockCachedDeviceInfo {
  let displayName: String?
  let addressHint: String?
  let displayNameSource: String
  let lastSeenAt: Date
}

private struct BleunlockResolvedDeviceInfo {
  let displayName: String?
  let addressHint: String?
  let displayNameSource: String?
}

final class BleunlockDeviceNameResolver {
  private var sqliteInitialized = false
  private var pairedDatabase: OpaquePointer?
  private var otherDatabase: OpaquePointer?
  private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

  static func normalized(_ value: String?) -> String? {
    guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !text.isEmpty
    else {
      return nil
    }
    return text
  }

  fileprivate func resolvedDeviceInfo(
    uuid: UUID,
    localName: String?,
    peripheralName: String?,
    manufacturerData: Data?,
    rssi: Int
  ) -> BleunlockResolvedDeviceInfo {
    let normalizedLocalName = Self.normalized(localName)
    let normalizedPeripheralName = Self.normalized(peripheralName)

    if let name = normalizedLocalName {
      if Self.looksLikeTemporaryBroadcastName(name),
         let stableName = normalizedPeripheralName,
         stableName != name {
        return BleunlockResolvedDeviceInfo(
          displayName: stableName,
          addressHint: cachedAddress(for: uuid) ?? uuid.uuidString,
          displayNameSource: "CBPeripheral.name"
        )
      }
      return BleunlockResolvedDeviceInfo(
        displayName: name,
        addressHint: cachedAddress(for: uuid) ?? uuid.uuidString,
        displayNameSource: "advertisementData.localName"
      )
    }

    if let name = normalizedPeripheralName {
      return BleunlockResolvedDeviceInfo(
        displayName: name,
        addressHint: cachedAddress(for: uuid) ?? uuid.uuidString,
        displayNameSource: "CBPeripheral.name"
      )
    }

    if let info = leDeviceInfo(uuid: uuid.uuidString) {
      return BleunlockResolvedDeviceInfo(
        displayName: Self.normalized(info.name),
        addressHint: info.macAddress ?? cachedAddress(for: uuid) ?? uuid.uuidString,
        displayNameSource: Self.normalized(info.name) == nil ? nil : "Bluetooth database"
      )
    }

    let plistAddress = macFromBluetoothPlist(uuid: uuid)
    let plistName = plistAddress.flatMap(nameFromBluetoothPlist)
    if plistName != nil || plistAddress != nil {
      return BleunlockResolvedDeviceInfo(
        displayName: plistName,
        addressHint: plistAddress ?? uuid.uuidString,
        displayNameSource: plistName == nil ? nil : "Bluetooth plist cache"
      )
    }

    if let iBeaconName = iBeaconName(from: manufacturerData, rssi: rssi) {
      return BleunlockResolvedDeviceInfo(
        displayName: iBeaconName,
        addressHint: uuid.uuidString,
        displayNameSource: "iBeacon manufacturer data"
      )
    }

    return BleunlockResolvedDeviceInfo(
      displayName: nil,
      addressHint: uuid.uuidString,
      displayNameSource: nil
    )
  }

  private static func looksLikeTemporaryBroadcastName(_ value: String) -> Bool {
    if value == "N/A" {
      return true
    }
    if value.count >= 12 && value.contains("/") && !value.contains(" ") {
      return true
    }
    if value.count < 16 {
      return false
    }

    let scalars = value.unicodeScalars
    let hasUpper = scalars.contains { CharacterSet.uppercaseLetters.contains($0) }
    let hasLower = scalars.contains { CharacterSet.lowercaseLetters.contains($0) }
    let hasDigit = scalars.contains { CharacterSet.decimalDigits.contains($0) }
    let allowedCharacters = CharacterSet.alphanumerics.union(
      CharacterSet(charactersIn: "-_/")
    )
    let onlySimpleCharacters = scalars.allSatisfy {
      allowedCharacters.contains($0)
    }

    return onlySimpleCharacters &&
      ((hasUpper && hasLower) || (hasUpper && hasDigit) || (hasLower && hasDigit))
  }

  private func cachedAddress(for uuid: UUID) -> String? {
    if let info = leDeviceInfo(uuid: uuid.uuidString), info.macAddress != nil {
      return info.macAddress
    }
    return macFromBluetoothPlist(uuid: uuid)
  }

  private func leDeviceInfo(uuid: String) -> BleunlockLEDeviceInfo? {
    ensureSQLiteDatabases()
    return leDeviceInfo(
      database: pairedDatabase,
      sql: "SELECT Name, Address, ResolvedAddress FROM PairedDevices WHERE Uuid = ?",
      uuid: uuid,
      resolvedAddressColumn: 2
    ) ?? leDeviceInfo(
      database: otherDatabase,
      sql: "SELECT Name, Address FROM OtherDevices WHERE Uuid = ?",
      uuid: uuid,
      resolvedAddressColumn: nil
    )
  }

  private func ensureSQLiteDatabases() {
    guard !sqliteInitialized else {
      return
    }
    sqliteInitialized = true
    pairedDatabase = openSQLiteDatabase(
      path: "/Library/Bluetooth/com.apple.MobileBluetooth.ledevices.paired.db"
    )
    otherDatabase = openSQLiteDatabase(
      path: "/Library/Bluetooth/com.apple.MobileBluetooth.ledevices.other.db"
    )
  }

  private func openSQLiteDatabase(path: String) -> OpaquePointer? {
    guard FileManager.default.isReadableFile(atPath: path) else {
      return nil
    }
    var database: OpaquePointer?
    guard sqlite3_open_v2(path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
      sqlite3_close(database)
      return nil
    }
    return database
  }

  private func leDeviceInfo(
    database: OpaquePointer?,
    sql: String,
    uuid: String,
    resolvedAddressColumn: Int32?
  ) -> BleunlockLEDeviceInfo? {
    guard let database else {
      return nil
    }
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      return nil
    }
    defer {
      sqlite3_finalize(statement)
    }
    guard sqlite3_bind_text(statement, 1, uuid, -1, sqliteTransient) == SQLITE_OK,
          sqlite3_step(statement) == SQLITE_ROW
    else {
      return nil
    }

    let name = stringColumn(statement, 0)
    let address = stringColumn(statement, 1)
    let resolvedAddress = resolvedAddressColumn.flatMap { stringColumn(statement, $0) }
    return BleunlockLEDeviceInfo(
      name: name,
      macAddress: parsedBluetoothAddress(resolvedAddress ?? address)
    )
  }

  private func stringColumn(_ statement: OpaquePointer?, _ index: Int32) -> String? {
    guard sqlite3_column_type(statement, index) == SQLITE_TEXT,
          let value = sqlite3_column_text(statement, index)
    else {
      return nil
    }
    return Self.normalized(String(cString: value))
  }

  private func parsedBluetoothAddress(_ value: String?) -> String? {
    guard let value = Self.normalized(value) else {
      return nil
    }
    let parts = value.split(separator: " ")
    if parts.count > 1 {
      return String(parts[1])
    }
    return value
  }

  private func macFromBluetoothPlist(uuid: UUID) -> String? {
    guard let plist = NSDictionary(
      contentsOfFile: "/Library/Preferences/com.apple.Bluetooth.plist"
    ),
      let cache = plist["CoreBluetoothCache"] as? NSDictionary,
      let device = cache[uuid.uuidString] as? NSDictionary
    else {
      return nil
    }
    return Self.normalized(device["DeviceAddress"] as? String)
  }

  private func nameFromBluetoothPlist(macAddress: String) -> String? {
    guard let plist = NSDictionary(
      contentsOfFile: "/Library/Preferences/com.apple.Bluetooth.plist"
    ),
      let cache = plist["DeviceCache"] as? NSDictionary,
      let device = cache[macAddress] as? NSDictionary
    else {
      return nil
    }
    return Self.normalized(device["Name"] as? String)
  }

  private func iBeaconName(from manufacturerData: Data?, rssi: Int) -> String? {
    guard let data = manufacturerData, data.count >= 25 else {
      return nil
    }
    var prefix: [UInt8] = [0x4c, 0x00, 0x02, 0x15]
    guard data[0..<4] == Data(bytes: &prefix, count: 4) else {
      return nil
    }
    let major = UInt16(data[20]) << 8 | UInt16(data[21])
    let minor = UInt16(data[22]) << 8 | UInt16(data[23])
    let tx = Int(Int8(bitPattern: data[24]))
    let distance = pow(10, Double(tx - rssi) / 20.0)
    return String(format: "iBeacon [%d, %d] %.1fm", major, minor, distance)
  }
}

private struct BleunlockLEDeviceInfo {
  let name: String?
  let macAddress: String?
}

final class BleunlockSessionController: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var workspaceObservers: [NSObjectProtocol] = []
  private var distributedObservers: [NSObjectProtocol] = []
  private var lastEmittedLockState: Bool?

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    subscribeSessionEvents()
    emitCurrentLockState(reason: "sessionStreamAttached")
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    removeSessionObservers()
    lastEmittedLockState = nil
    eventSink = nil
    return nil
  }

  func lock() throws {
    let status = SACLockScreenImmediate()
    guard status == 0 else {
      throw BleunlockSessionError.lockFailed("SACLockScreenImmediate returned \(status)")
    }

    guard waitUntilLocked(timeout: 1.5) else {
      throw BleunlockSessionError.lockFailed(
        "macOS did not report a locked session after SACLockScreenImmediate"
      )
    }
  }

  func wakeDisplay() {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
    process.arguments = ["-u", "-t", "1"]
    try? process.run()
  }

  func isLocked() -> Bool {
    guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else {
      return false
    }

    if let locked = session["CGSSessionScreenIsLocked"] as? Int {
      return locked == 1
    }
    if let locked = session["CGSSessionScreenIsLocked"] as? Bool {
      return locked
    }
    return false
  }

  private func waitUntilLocked(timeout: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
      if isLocked() {
        return true
      }
      RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
    } while Date() < deadline

    return isLocked()
  }

  private func subscribeSessionEvents() {
    removeSessionObservers()

    let workspaceCenter = NSWorkspace.shared.notificationCenter
    workspaceObservers = [
      workspaceCenter.addObserver(
        forName: NSWorkspace.sessionDidResignActiveNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.emitLockState(locked: true, reason: "NSWorkspace.sessionDidResignActiveNotification")
      },
      workspaceCenter.addObserver(
        forName: NSWorkspace.sessionDidBecomeActiveNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.emitLockState(locked: false, reason: "NSWorkspace.sessionDidBecomeActiveNotification")
      },
      workspaceCenter.addObserver(
        forName: NSWorkspace.screensDidSleepNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.emit(kind: "displaySleep", reason: "NSWorkspace.screensDidSleepNotification")
      },
      workspaceCenter.addObserver(
        forName: NSWorkspace.screensDidWakeNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.emit(kind: "displayWake", reason: "NSWorkspace.screensDidWakeNotification")
      },
      workspaceCenter.addObserver(
        forName: NSWorkspace.willSleepNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.emit(kind: "systemSleep", reason: "NSWorkspace.willSleepNotification")
      },
      workspaceCenter.addObserver(
        forName: NSWorkspace.didWakeNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.emit(kind: "systemWake", reason: "NSWorkspace.didWakeNotification")
      },
    ]

    let distributedCenter = DistributedNotificationCenter.default()
    distributedObservers = [
      distributedCenter.addObserver(
        forName: Notification.Name("com.apple.screenIsLocked"),
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.emitLockState(
          locked: true,
          reason: "DistributedNotificationCenter.com.apple.screenIsLocked"
        )
      },
      distributedCenter.addObserver(
        forName: Notification.Name("com.apple.screenIsUnlocked"),
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.emitLockState(
          locked: false,
          reason: "DistributedNotificationCenter.com.apple.screenIsUnlocked"
        )
      },
    ]
  }

  private func removeSessionObservers() {
    let workspaceCenter = NSWorkspace.shared.notificationCenter
    for observer in workspaceObservers {
      workspaceCenter.removeObserver(observer)
    }
    workspaceObservers.removeAll()

    let distributedCenter = DistributedNotificationCenter.default()
    for observer in distributedObservers {
      distributedCenter.removeObserver(observer)
    }
    distributedObservers.removeAll()
  }

  private func emit(kind: String, reason: String) {
    let event: [String: Any] = [
      "kind": kind,
      "timestampMillis": Int(Date().timeIntervalSince1970 * 1000),
      "reason": reason,
    ]
    eventSink?(event)
  }

  private func emitCurrentLockState(reason: String) {
    emitLockState(locked: isLocked(), reason: reason)
  }

  private func emitLockState(locked: Bool, reason: String) {
    if lastEmittedLockState == locked {
      return
    }
    lastEmittedLockState = locked
    emit(kind: locked ? "locked" : "unlocked", reason: reason)
  }
}

private enum BleunlockSessionError: Error, CustomStringConvertible {
  case lockFailed(String)

  var description: String {
    switch self {
    case .lockFailed(let message):
      return message
    }
  }
}

final class BleunlockTrayController: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var statusItem: NSStatusItem?
  private var status = "normal"
  private var recentDeviceSummary: String?
  private var isMonitoring = false

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    ensureStatusItem()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func setStatus(_ status: String, recentDeviceSummary: String?, isMonitoring value: Bool) {
    self.status = status
    self.recentDeviceSummary = normalizedSummary(recentDeviceSummary)
    isMonitoring = value
    DispatchQueue.main.async { [weak self] in
      self?.ensureStatusItem()
      self?.statusItem?.menu = self?.buildMenu()
      self?.updateStatusTitle()
    }
  }

  func showQuickMenu() {
    DispatchQueue.main.async { [weak self] in
      self?.ensureStatusItem()
      self?.statusItem?.button?.performClick(nil)
    }
  }

  private func ensureStatusItem() {
    if statusItem != nil {
      updateStatusTitle()
      return
    }

    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    item.button?.toolTip = "BLEUnlock"
    item.menu = buildMenu()
    statusItem = item
    updateStatusTitle()
  }

  private func buildMenu() -> NSMenu {
    let menu = NSMenu()
    menu.addItem(disabledMenuItem(title: "BLEUnlock 控制中心"))
    menu.addItem(disabledMenuItem(title: "当前状态：\(statusDescription(for: status))"))
    menu.addItem(disabledMenuItem(title: "监听状态：\(isMonitoring ? "运行中" : "已暂停")"))
    if let recentDeviceSummary {
      menu.addItem(disabledMenuItem(title: "最近设备：\(recentDeviceSummary)"))
    } else {
      menu.addItem(disabledMenuItem(title: "最近设备：等待扫描"))
    }
    menu.addItem(NSMenuItem.separator())
    menu.addItem(
      menuItem(
        title: "打开设置...",
        action: #selector(openSettings),
        keyEquivalent: ",",
        modifierMask: [.command]
      )
    )
    if isMonitoring {
      menu.addItem(menuItem(title: "暂停监听", action: #selector(pauseMonitoring)))
    } else {
      menu.addItem(menuItem(title: "开始监听", action: #selector(startMonitoring)))
    }
    menu.addItem(
      menuItem(
        title: "立即锁屏",
        action: #selector(lockNow),
        keyEquivalent: "l",
        modifierMask: [.command, .option]
      )
    )
    menu.addItem(NSMenuItem.separator())
    menu.addItem(
      menuItem(
        title: "退出 BLEUnlock",
        action: #selector(quit),
        keyEquivalent: "q",
        modifierMask: [.command]
      )
    )
    return menu
  }

  private func menuItem(
    title: String,
    action: Selector,
    keyEquivalent: String = "",
    modifierMask: NSEvent.ModifierFlags = []
  ) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
    item.keyEquivalentModifierMask = modifierMask
    item.target = self
    return item
  }

  private func disabledMenuItem(title: String) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.isEnabled = false
    return item
  }

  private func updateStatusTitle() {
    guard let button = statusItem?.button else {
      return
    }
    button.title = ""
    button.image = statusImage(for: status)
    button.imagePosition = .imageOnly
    var toolTipLines = [
      "BLEUnlock",
      "当前状态：\(statusDescription(for: status))",
      "监听状态：\(isMonitoring ? "运行中" : "已暂停")",
    ]
    if let recentDeviceSummary {
      toolTipLines.append("最近设备：\(recentDeviceSummary)")
    } else {
      toolTipLines.append("最近设备：等待扫描")
    }
    button.toolTip = toolTipLines.joined(separator: "\n")
  }

  private func normalizedSummary(_ value: String?) -> String? {
    guard let summary = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !summary.isEmpty
    else {
      return nil
    }
    return summary
  }

  private func statusDescription(for status: String) -> String {
    switch status {
    case "monitoring":
      return "监听中"
    case "locked":
      return "已锁定"
    case "warning":
      return "需要处理"
    default:
      return "就绪"
    }
  }

  private func statusImage(for status: String) -> NSImage? {
    let imageName: String
    switch status {
    case "monitoring", "locked":
      imageName = "StatusBarConnected"
    default:
      imageName = "StatusBarDisconnected"
    }
    guard let image = NSImage(named: imageName) else {
      return nil
    }
    image.isTemplate = true
    return image
  }

  @objc private func openSettings() {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    NSApp.windows.forEach { window in
      if window.isMiniaturized {
        window.deminiaturize(nil)
      }
      window.makeKeyAndOrderFront(nil)
    }
    emit(kind: "openSettings")
  }

  @objc private func startMonitoring() {
    emit(kind: "startMonitoring")
  }

  @objc private func pauseMonitoring() {
    emit(kind: "pauseMonitoring")
  }

  @objc private func lockNow() {
    emit(kind: "lockNow")
  }

  @objc private func quit() {
    emit(kind: "quit")
  }

  private func emit(kind: String) {
    let event: [String: Any] = [
      "kind": kind,
      "timestampMillis": Int(Date().timeIntervalSince1970 * 1000),
    ]
    eventSink?(event)
  }
}

enum BleunlockStartupError: Error {
  case missingExecutablePath
  case invalidPlist
}

final class BleunlockStartupController {
  private let label = "com.github.skyearn.bleunlock.flutter.startup"

  func isEnabled() -> Bool {
    FileManager.default.fileExists(atPath: launchAgentURL.path)
  }

  func setEnabled(_ enabled: Bool) throws {
    if enabled {
      try writeLaunchAgent()
    } else {
      try removeLaunchAgent()
    }
  }

  private var launchAgentURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library")
      .appendingPathComponent("LaunchAgents")
      .appendingPathComponent("\(label).plist")
  }

  private func writeLaunchAgent() throws {
    guard let executablePath = Bundle.main.executablePath else {
      throw BleunlockStartupError.missingExecutablePath
    }

    let directory = launchAgentURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )

    let plist: [String: Any] = [
      "Label": label,
      "ProgramArguments": [executablePath],
      "RunAtLoad": true,
      "KeepAlive": false,
    ]

    let data = try PropertyListSerialization.data(
      fromPropertyList: plist,
      format: .xml,
      options: 0
    )
    try data.write(to: launchAgentURL, options: .atomic)
  }

  private func removeLaunchAgent() throws {
    if FileManager.default.fileExists(atPath: launchAgentURL.path) {
      try FileManager.default.removeItem(at: launchAgentURL)
    }
  }
}

final class BleunlockUnlockController {
  private let unlockPasswordKey = "macosAutomaticUnlockPassword"
  private let secureStore: BleunlockSecureStore
  private let sessionController: BleunlockSessionController

  init(
    secureStore: BleunlockSecureStore,
    sessionController: BleunlockSessionController
  ) {
    self.secureStore = secureStore
    self.sessionController = sessionController
  }

  func unlock() -> [String: Any] {
    guard AXIsProcessTrusted() else {
      return ["success": false, "reason": "permissionDenied"]
    }

    guard sessionController.isLocked() else {
      return ["success": false, "reason": "notLocked"]
    }

    do {
      guard let password = try secureStore.readSecret(key: unlockPasswordKey),
            !password.isEmpty
      else {
        return ["success": false, "reason": "missingSecret"]
      }

      submitPassword(password)
      if waitUntilUnlocked(timeout: 0.7) {
        return ["success": true, "reason": "unlocked"]
      }
      return ["success": false, "reason": "stillLocked"]
    } catch {
      return ["success": false, "reason": "keychainReadFailed"]
    }
  }

  func capability() -> [String: Any] {
    guard AXIsProcessTrusted() else {
      return [
        "kind": "permissionDenied",
        "description": "Accessibility permission is required",
      ]
    }

    return ["kind": "supported"]
  }

  func openPermissionSettings() {
    guard let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    ) else {
      return
    }
    NSWorkspace.shared.open(url)
  }

  private func submitPassword(_ password: String) {
    let source = CGEventSource(stateID: .hidSystemState)
    let units = Array(password.utf16)
    let chunkSize = 20
    var index = 0

    while index < units.count {
      let length = min(chunkSize, units.count - index)
      let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 49, keyDown: true)
      units.withUnsafeBufferPointer { buffer in
        guard let baseAddress = buffer.baseAddress else {
          return
        }
        keyDown?.keyboardSetUnicodeString(
          stringLength: length,
          unicodeString: baseAddress.advanced(by: index)
        )
      }
      keyDown?.post(tap: .cghidEventTap)
      CGEvent(keyboardEventSource: source, virtualKey: 49, keyDown: false)?
        .post(tap: .cghidEventTap)
      index += length
    }

    postReturnKey(source: source)
  }

  private func postReturnKey(source: CGEventSource?) {
    CGEvent(keyboardEventSource: source, virtualKey: 52, keyDown: true)?
      .post(tap: .cghidEventTap)
    CGEvent(keyboardEventSource: source, virtualKey: 52, keyDown: false)?
      .post(tap: .cghidEventTap)
  }

  private func waitUntilUnlocked(timeout: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
      if !sessionController.isLocked() {
        return true
      }
      RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
    } while Date() < deadline

    return !sessionController.isLocked()
  }
}

enum BleunlockKeychainError: Error {
  case invalidValueEncoding
  case invalidValueData
  case unexpectedStatus(OSStatus)
}

final class BleunlockSecureStore {
  private let service = "com.github.skyearn.bleunlock.flutter"

  func writeSecret(key: String, value: String) throws {
    guard let data = value.data(using: .utf8) else {
      throw BleunlockKeychainError.invalidValueEncoding
    }

    var query = keychainQuery(key: key)
    SecItemDelete(query as CFDictionary)

    query[String(kSecAttrLabel)] = "BLEUnlock"
    query[String(kSecAttrAccessible)] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    query[String(kSecValueData)] = data

    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw BleunlockKeychainError.unexpectedStatus(status)
    }
  }

  func readSecret(key: String) throws -> String? {
    var query = keychainQuery(key: key)
    query[String(kSecReturnData)] = kCFBooleanTrue
    query[String(kSecMatchLimit)] = kSecMatchLimitOne

    var item: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess else {
      throw BleunlockKeychainError.unexpectedStatus(status)
    }
    guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
      throw BleunlockKeychainError.invalidValueData
    }
    return value
  }

  func deleteSecret(key: String) throws {
    let status = SecItemDelete(keychainQuery(key: key) as CFDictionary)
    if status == errSecItemNotFound {
      return
    }
    guard status == errSecSuccess else {
      throw BleunlockKeychainError.unexpectedStatus(status)
    }
  }

  private func keychainQuery(key: String) -> [String: Any] {
    [
      String(kSecClass): kSecClassGenericPassword,
      String(kSecAttrAccount): key,
      String(kSecAttrService): service,
    ]
  }
}
