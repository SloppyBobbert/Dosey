import AuthenticationServices
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var appleSignInHandler: AppleSignInHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let timezoneChannel = FlutterMethodChannel(
      name: "com.sloppybobbert.dosey_app/timezone",
      binaryMessenger: engineBridge.pluginRegistry.registrar(forPlugin: "DoseyTimezone")!.messenger()
    )
    timezoneChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getLocalTimezone":
        result(TimeZone.current.identifier)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let appleAuthChannel = FlutterMethodChannel(
      name: "com.sloppybobbert.dosey_app/apple_auth",
      binaryMessenger: engineBridge.pluginRegistry.registrar(forPlugin: "DoseyAppleAuth")!.messenger()
    )
    appleAuthChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "signIn" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard self?.appleSignInHandler == nil else {
        result(FlutterError(
          code: "APPLE_SIGN_IN_IN_PROGRESS",
          message: "Apple sign-in is already in progress.",
          details: nil
        ))
        return
      }

      guard let anchor = self?.currentPresentationAnchor() else {
        result(FlutterError(
          code: "APPLE_SIGN_IN_NO_PRESENTATION_ANCHOR",
          message: "No active window available for Apple sign-in.",
          details: nil
        ))
        return
      }

      let handler = AppleSignInHandler(
        result: result,
        presentationAnchor: { anchor },
        onFinish: { [weak self] in
          self?.appleSignInHandler = nil
        }
      )
      self?.appleSignInHandler = handler
      handler.start()
    }
  }

  private func currentPresentationAnchor() -> ASPresentationAnchor? {
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }
}

private final class AppleSignInHandler: NSObject, ASAuthorizationControllerDelegate,
  ASAuthorizationControllerPresentationContextProviding
{
  init(
    result: @escaping FlutterResult,
    presentationAnchor: @escaping () -> ASPresentationAnchor,
    onFinish: @escaping () -> Void
  ) {
    self.result = result
    self.presentationAnchorProvider = presentationAnchor
    self.onFinish = onFinish
  }

  private let result: FlutterResult
  private let presentationAnchorProvider: () -> ASPresentationAnchor
  private let onFinish: () -> Void

  func start() {
    let provider = ASAuthorizationAppleIDProvider()
    let request = provider.createRequest()
    request.requestedScopes = [.email, .fullName]

    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = self
    controller.presentationContextProvider = self
    controller.performRequests()
  }

  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    defer { onFinish() }
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
      result(FlutterError(
        code: "APPLE_SIGN_IN_INVALID_CREDENTIAL",
        message: "Apple sign-in returned an unsupported credential.",
        details: nil
      ))
      return
    }

    var account: [String: Any] = ["id": credential.user]
    if let email = credential.email {
      account["email"] = email
    }
    if let displayName = displayName(from: credential.fullName) {
      account["displayName"] = displayName
    }
    result(account)
  }

  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithError error: Error
  ) {
    defer { onFinish() }
    result(FlutterError(
      code: "APPLE_SIGN_IN_FAILED",
      message: error.localizedDescription,
      details: nil
    ))
  }

  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    return presentationAnchorProvider()
  }

  private func displayName(from components: PersonNameComponents?) -> String? {
    guard let components else {
      return nil
    }

    let formatter = PersonNameComponentsFormatter()
    let name = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? nil : name
  }
}
