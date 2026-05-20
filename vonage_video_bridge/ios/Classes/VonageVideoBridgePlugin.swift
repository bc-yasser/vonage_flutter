import Flutter
import OpenTok
import UIKit

public class VonageVideoBridgePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let controller = VonageVideoController()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = VonageVideoBridgePlugin()
    let methodChannel = FlutterMethodChannel(
      name: "vonage_video_bridge/methods",
      binaryMessenger: registrar.messenger()
    )
    let eventChannel = FlutterEventChannel(
      name: "vonage_video_bridge/events",
      binaryMessenger: registrar.messenger()
    )

    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
    registrar.register(
      VonageVideoPlatformViewFactory(controller: instance.controller),
      withId: "vonage_video_bridge/view"
    )
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "connect":
        guard let args = call.arguments as? [String: Any],
              let applicationId = args["applicationId"] as? String,
              let sessionId = args["sessionId"] as? String,
              let token = args["token"] as? String else {
          result(FlutterError(code: "BAD_ARGS", message: "applicationId, sessionId, and token are required", details: nil))
          return
        }
        let publisherName = args["publisherName"] as? String ?? "Flutter"
        try controller.connect(
          applicationId: applicationId,
          sessionId: sessionId,
          token: token,
          publisherName: publisherName
        )
        result(nil)
      case "publish":
        try controller.publish()
        result(nil)
      case "setAudioEnabled":
        controller.setAudioEnabled(call.arguments as? Bool ?? true)
        result(nil)
      case "setVideoEnabled":
        controller.setVideoEnabled(call.arguments as? Bool ?? true)
        result(nil)
      case "switchCamera":
        controller.switchCamera()
        result(nil)
      case "disconnect":
        controller.disconnect()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      result(FlutterError(code: "VONAGE_VIDEO_ERROR", message: error.localizedDescription, details: nil))
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    controller.eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    controller.eventSink = nil
    return nil
  }
}

final class VonageVideoController: NSObject, OTSessionDelegate, OTPublisherDelegate, OTSubscriberDelegate {
  var eventSink: FlutterEventSink?

  private var session: OTSession?
  private var publisher: OTPublisher?
  private var subscriber: OTSubscriber?
  private weak var container: UIView?

  func attach(_ view: UIView) {
    container = view
    renderViews()
  }

  func detach(_ view: UIView) {
    if container === view {
      container = nil
    }
  }

  func connect(applicationId: String, sessionId: String, token: String, publisherName: String) throws {
    disconnect()
    publisher = OTPublisher(delegate: self, name: publisherName)
    session = OTSession(apiKey: applicationId, sessionId: sessionId, delegate: self)

    var error: OTError?
    session?.connect(withToken: token, error: &error)
    if let error {
      throw error
    }
    sendEvent("connecting")
    renderViews()
  }

  func publish() throws {
    guard let session else {
      throw NSError(domain: "VonageVideoBridge", code: 1, userInfo: [NSLocalizedDescriptionKey: "Session is not connected"])
    }
    guard let publisher else {
      throw NSError(domain: "VonageVideoBridge", code: 2, userInfo: [NSLocalizedDescriptionKey: "Publisher is not ready"])
    }

    var error: OTError?
    session.publish(publisher, error: &error)
    if let error {
      throw error
    }
    renderViews()
  }

  func setAudioEnabled(_ enabled: Bool) {
    publisher?.publishAudio = enabled
  }

  func setVideoEnabled(_ enabled: Bool) {
    publisher?.publishVideo = enabled
  }

  func switchCamera() {
    guard let publisher else { return }
    publisher.cameraPosition = publisher.cameraPosition == .front ? .back : .front
  }

  func disconnect() {
    if let subscriber {
      var error: OTError?
      session?.unsubscribe(subscriber, error: &error)
    }
    if let publisher {
      var error: OTError?
      session?.unpublish(publisher, error: &error)
    }
    var error: OTError?
    session?.disconnect(&error)
    subscriber = nil
    publisher = nil
    session = nil
    container?.subviews.forEach { $0.removeFromSuperview() }
    sendEvent("disconnected")
  }

  func sessionDidConnect(_ session: OTSession) {
    sendEvent("connected")
    try? publish()
  }

  func sessionDidDisconnect(_ session: OTSession) {
    sendEvent("disconnected")
  }

  func session(_ session: OTSession, streamCreated stream: OTStream) {
    sendEvent("streamReceived", streamId: stream.streamId)
    subscriber = OTSubscriber(stream: stream, delegate: self)
    if let subscriber {
      var error: OTError?
      session.subscribe(subscriber, error: &error)
      if let error {
        sendEvent("error", message: error.localizedDescription)
      }
    }
    renderViews()
  }

  func session(_ session: OTSession, streamDestroyed stream: OTStream) {
    sendEvent("streamDropped", streamId: stream.streamId)
    subscriber = nil
    renderViews()
  }

  func session(_ session: OTSession, didFailWithError error: OTError) {
    sendEvent("error", message: error.localizedDescription)
  }

  func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
    sendEvent("publisherStreamCreated", streamId: stream.streamId)
  }

  func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
    sendEvent("publisherStreamDestroyed", streamId: stream.streamId)
  }

  func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
    sendEvent("error", message: error.localizedDescription)
  }

  func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
    renderViews()
  }

  func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
    sendEvent("error", message: error.localizedDescription)
  }

  private func renderViews() {
    guard let container else { return }
    container.subviews.forEach { $0.removeFromSuperview() }

    if let remoteView = subscriber?.view {
      remoteView.frame = container.bounds
      remoteView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      container.addSubview(remoteView)
    }

    if let localView = publisher?.view {
      let side: CGFloat = 120
      localView.frame = CGRect(
        x: container.bounds.width - side - 24,
        y: 24,
        width: side,
        height: side
      )
      localView.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
      container.addSubview(localView)
    }
  }

  private func sendEvent(_ type: String, message: String? = nil, streamId: String? = nil) {
    var payload: [String: Any] = ["type": type]
    if let message {
      payload["message"] = message
    }
    if let streamId {
      payload["streamId"] = streamId
    }
    eventSink?(payload)
  }
}
