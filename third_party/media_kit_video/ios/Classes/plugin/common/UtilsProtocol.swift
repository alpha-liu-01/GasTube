public protocol UtilsProtocol: NSObject {
  func enterNativeFullscreen()
  func exitNativeFullscreen()
  func setAppFullscreen(_ enabled: Bool)
}
