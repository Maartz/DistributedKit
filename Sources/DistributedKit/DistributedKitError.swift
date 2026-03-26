public enum DistributedKitError: Error, Sendable {
    case unhandledCall(String)
    case unhandledCast(String)
    case serviceNotFound(String)
    case supervisionMaxRestartsExceeded(name: String, count: Int)
    case factoryFailed(name: String, underlying: any Error & Sendable)
}
