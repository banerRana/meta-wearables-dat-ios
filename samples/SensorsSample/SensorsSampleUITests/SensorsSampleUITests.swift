/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

import Foundation
import MWDATCore
import XCTest

final class SensorsSampleUITests: XCTestCase {
  private static let portFilePrefix = "mwdat_test_server_port_"
  private static let portFileSuffix = ".txt"
  private let portFilePath = NSTemporaryDirectory() + "mwdat_test_server_port_\(UUID().uuidString).txt"
  private let app = XCUIApplication()
  // swiftlint:disable implicitly_unwrapped_optional
  private var sensorsClient: SensorsSampleMockDeviceClient!
  private var pairedDeviceId: String!
  // swiftlint:enable implicitly_unwrapped_optional

  override func setUpWithError() throws {
    continueAfterFailure = false
    removeStalePortFiles()
    addTeardownBlock { [portFilePath] in
      try? FileManager.default.removeItem(atPath: portFilePath)
    }

    app.launchArguments = ["--ui-testing"]
    app.launchEnvironment["MWDAT_TEST_SERVER_PORT_FILE"] = portFilePath
    app.launch()

    // Initialize the client *after* launch so the server has time to write the port file.
    sensorsClient = SensorsSampleMockDeviceClient(portFilePath: portFilePath)
    XCTAssertTrue(sensorsClient.waitForServer(timeout: 10), "Test server should be running")
  }

  override func tearDownWithError() throws {
    if pairedDeviceId != nil {
      sensorsClient.unpairDevice(deviceId: pairedDeviceId)
      pairedDeviceId = nil
    }
    app.terminate()
    sensorsClient = nil
  }

  // MARK: - Helpers

  private func removeStalePortFiles() {
    let fileManager = FileManager.default
    let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    guard let fileURLs = try? fileManager.contentsOfDirectory(at: temporaryDirectory, includingPropertiesForKeys: nil) else {
      return
    }
    for fileURL in fileURLs {
      let filename = fileURL.lastPathComponent
      if filename.hasPrefix(Self.portFilePrefix), filename.hasSuffix(Self.portFileSuffix) {
        try? fileManager.removeItem(at: fileURL)
      }
    }
  }

  /// Pairs a mock Ray-Ban Meta (powered on and donned) and stages the spinning IMU feed, so the app's
  /// motion session drives the wireframe to a live orientation once it starts streaming.
  private func pairDeviceWithMotionFeed() {
    let deviceId = sensorsClient.pairDevice()
    XCTAssertNotNil(deviceId, "pairDevice should return a deviceId")
    pairedDeviceId = deviceId
    XCTAssertTrue(
      sensorsClient.setMotionFeed(deviceId: deviceId!, resourceName: "spin", ext: "csv"),
      "Staging the motion feed should succeed"
    )
  }

  /// Waits for the wireframe to report live orientation, which also proves the device session is
  /// started and its capabilities (motion/inputs/speech) are active.
  @discardableResult
  private func waitForOrientationLive(timeout: TimeInterval = 25) -> XCUIElement {
    let status = app.staticTexts["orientation_status"]
    XCTAssertTrue(status.waitForExistence(timeout: timeout), "Orientation status label should render on the playground")
    let live = NSPredicate(
      format: "label == %@ OR label == %@",
      "Orientation: fused",
      "Orientation: from accelerometer"
    )
    let expectation = XCTNSPredicateExpectation(predicate: live, object: status)
    XCTAssertEqual(
      XCTWaiter.wait(for: [expectation], timeout: timeout),
      .completed,
      "Wireframe should report live orientation once IMU samples flow (label was '\(status.label)')"
    )
    return status
  }

  private func attachScreenshot(named name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func assertStillForeground() {
    XCTAssertEqual(app.state, .runningForeground, "App should still be running in the foreground (no crash)")
  }

  // MARK: - Motion

  /// Pairs a mock device and verifies the staged IMU feed drives the wireframe to the
  /// live-orientation state.
  @MainActor
  func testMotionDrivesWireframeOrientation() {
    pairDeviceWithMotionFeed()

    waitForOrientationLive()
    attachScreenshot(named: "ss_dev_ui_motion")
    assertStillForeground()
  }

  // MARK: - Inputs

  /// Injects Nav / Select / Capture inputs through the mock and verifies the input HUD logs the most
  /// recent one.
  @MainActor
  func testInputsAppearInHUD() {
    pairDeviceWithMotionFeed()

    // Orientation-live proves the session (and its inputs capability) is active before injecting.
    waitForOrientationLive()

    let hud = app.staticTexts["input_hud_latest"]
    XCTAssertTrue(hud.waitForExistence(timeout: 15), "Input HUD should render")

    // The input session may admit slightly after motion starts, and events are dropped until it is
    // streaming, so inject repeatedly until the HUD reflects one.
    var showsInjected = false
    for _ in 0..<15 {
      sensorsClient.navUp(deviceId: pairedDeviceId)
      sensorsClient.select(deviceId: pairedDeviceId)
      sensorsClient.capture(deviceId: pairedDeviceId)
      let label = hud.label
      if label.localizedCaseInsensitiveContains("Capture")
        || label.localizedCaseInsensitiveContains("Select")
        || label.localizedCaseInsensitiveContains("Nav")
      {
        showsInjected = true
        break
      }
      Thread.sleep(forTimeInterval: 1)
    }
    XCTAssertTrue(showsInjected, "Input HUD should reflect an injected input (label was '\(hud.label)')")

    attachScreenshot(named: "ss_dev_ui_inputs")
    assertStillForeground()
  }

  // MARK: - Speech

  /// Delivers a transcription through the mock speech service and verifies the caption view shows it.
  /// The mock grants the microphone permission on enable, so speech starts listening without a system
  /// prompt.
  @MainActor
  func testSpeechTranscriptionAppearsInCaption() {
    pairDeviceWithMotionFeed()

    waitForOrientationLive()

    let expected = "Hey Meta, what am I looking at?"
    let caption = app.staticTexts["caption_text"]
    XCTAssertTrue(caption.waitForExistence(timeout: 15), "Caption view should render once speech is listening")

    // Speech starts listening shortly after the session activates, and transcriptions are dropped
    // until then, so send repeatedly until the caption reflects it.
    var showsCaption = false
    for _ in 0..<15 {
      sensorsClient.sendTranscription(deviceId: pairedDeviceId, text: expected)
      if caption.label == expected {
        showsCaption = true
        break
      }
      Thread.sleep(forTimeInterval: 1)
    }
    XCTAssertTrue(showsCaption, "Caption should show the simulated transcription (label was '\(caption.label)')")

    attachScreenshot(named: "ss_dev_ui_speech")
    assertStillForeground()
  }
}

private final class SensorsSampleMockDeviceClient {
  private let baseURL: String

  init(portFilePath: String) {
    let port = Self.readPort(from: portFilePath)
    self.baseURL = "http://127.0.0.1:\(port)"
  }

  @discardableResult
  func pairDevice() -> String? {
    let body = try? JSONEncoder().encode(["deviceType": DeviceType.rayBanMeta.rawValue])
    guard let data = body,
      let json = postJSON("/device/pair", body: data),
      let deviceId = json["deviceId"] as? String
    else {
      return nil
    }
    return deviceId
  }

  @discardableResult
  func unpairDevice(deviceId: String) -> Bool {
    return postDeviceCommand("/device/unpair", deviceId: deviceId)
  }

  func waitForServer(timeout: TimeInterval = 10) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if getJSON("/health") != nil {
        return true
      }
      Thread.sleep(forTimeInterval: 0.25)
    }
    return false
  }

  @discardableResult
  func setMotionFeed(deviceId: String, resourceName: String, ext: String) -> Bool {
    let body = ["deviceId": deviceId, "resourceName": resourceName, "ext": ext]
    guard let data = try? JSONEncoder().encode(body) else { return false }
    return post("/motion/set-feed", body: data)
  }

  @discardableResult
  func navUp(deviceId: String) -> Bool {
    return postDeviceCommand("/input/nav-up", deviceId: deviceId)
  }

  @discardableResult
  func select(deviceId: String) -> Bool {
    return postDeviceCommand("/input/select", deviceId: deviceId)
  }

  @discardableResult
  func capture(deviceId: String) -> Bool {
    return postDeviceCommand("/input/capture", deviceId: deviceId)
  }

  @discardableResult
  func sendTranscription(deviceId: String, text: String) -> Bool {
    let body = ["deviceId": deviceId, "text": text]
    guard let data = try? JSONEncoder().encode(body) else { return false }
    return post("/speech/transcribe", body: data)
  }

  private func postDeviceCommand(_ path: String, deviceId: String) -> Bool {
    guard let body = try? JSONEncoder().encode(["deviceId": deviceId]) else { return false }
    return post(path, body: body)
  }

  private func postJSON(_ path: String, body: Data? = nil) -> [String: Any]? {
    guard let url = URL(string: baseURL + path) else { return nil }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 10

    if let body {
      request.httpBody = body
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    let (data, response) = synchronousDataTask(with: request)
    guard let httpResponse = response as? HTTPURLResponse,
      httpResponse.statusCode == 200,
      let data,
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return nil
    }
    return json
  }

  private func post(_ path: String, body: Data? = nil) -> Bool {
    guard let url = URL(string: baseURL + path) else { return false }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 10

    if let body {
      request.httpBody = body
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    let (data, response) = synchronousDataTask(with: request)
    guard let httpResponse = response as? HTTPURLResponse else { return false }
    _ = data
    return httpResponse.statusCode == 200
  }

  private func getJSON(_ path: String) -> [String: Any]? {
    guard let url = URL(string: baseURL + path) else { return nil }
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = 10

    let (data, response) = synchronousDataTask(with: request)
    guard let httpResponse = response as? HTTPURLResponse,
      httpResponse.statusCode == 200,
      let data,
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return nil
    }
    return json
  }

  private func synchronousDataTask(with request: URLRequest) -> (Data?, URLResponse?) {
    let semaphore = DispatchSemaphore(value: 0)
    let box = ResultBox()

    let task = URLSession.shared.dataTask(with: request) { data, response, _ in
      box.data = data
      box.response = response
      semaphore.signal()
    }
    task.resume()
    semaphore.wait()

    return (box.data, box.response)
  }

  private static func readPort(from path: String) -> UInt16 {
    for _ in 0..<40 {
      if let contents = try? String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
        let port = UInt16(contents), port > 0
      {
        return port
      }
      Thread.sleep(forTimeInterval: 0.25)
    }
    return 0
  }
}

private final class ResultBox: @unchecked Sendable {
  var data: Data?
  var response: URLResponse?
}
