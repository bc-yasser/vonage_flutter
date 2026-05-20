import Flutter
import UIKit

final class VonageVideoPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
  private let controller: VonageVideoController

  init(controller: VonageVideoController) {
    self.controller = controller
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return VonageVideoPlatformView(frame: frame, controller: controller)
  }
}

final class VonageVideoPlatformView: NSObject, FlutterPlatformView {
  private let root: UIView
  private let controller: VonageVideoController

  init(frame: CGRect, controller: VonageVideoController) {
    self.root = UIView(frame: frame)
    self.controller = controller
    super.init()
    controller.attach(root)
  }

  func view() -> UIView {
    return root
  }

  deinit {
    controller.detach(root)
  }
}
