/// Errors raised by the DistributedKit runtime.
public enum DistributedKitError: Error, Sendable {
    /// A synchronous call was not handled by the target actor (analogous to an unmatched `handle_call` in OTP GenServer).
    case unhandledCall(String)
    /// An asynchronous cast was not handled by the target actor (analogous to an unmatched `handle_cast` in OTP GenServer).
    case unhandledCast(String)
    /// No actor registered under the given service name was found in the cluster.
    case serviceNotFound(String)
    /// The supervisor exceeded its maximum restart intensity (equivalent to OTP's `max_restarts` / `max_seconds` breach).
    case supervisionMaxRestartsExceeded(name: String, count: Int)
    /// The child factory closure threw while starting or restarting a child process.
    case factoryFailed(name: String, underlying: any Error & Sendable)
    /// A `ClusterSystem` was required but has not been bound to the supervision tree.
    case missingClusterSystem
}
