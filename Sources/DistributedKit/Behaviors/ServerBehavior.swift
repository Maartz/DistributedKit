import DistributedCluster

/// A protocol for distributed actors that process messages using OTP-style call/cast semantics.
///
/// `ServerBehavior` is the DistributedKit equivalent of Elixir's `GenServer`. Conform to it
/// to get structured request-reply (`handleCall`) and fire-and-forget (`handleCast`)
/// message handling with explicit state management.
///
/// Use ``processCall(_:state:)`` and ``processCast(_:state:)`` helpers from within
/// your `distributed func` methods to dispatch messages through the behavior.
///
/// OTP equivalent: `use GenServer`. See <doc:OTPMapping> for the full mapping.
public protocol ServerBehavior: DistributedActor where ActorSystem == ClusterSystem {
    /// The message type for request-reply interactions (GenServer.call equivalent).
    associatedtype CallMessage: Sendable & Codable
    /// The message type for fire-and-forget interactions (GenServer.cast equivalent).
    associatedtype CastMessage: Sendable & Codable
    /// The actor's internal state type.
    associatedtype State: Sendable

    /// Handle a call message. Default throws ``DistributedKitError/unhandledCall(_:)``.
    func handleCall(
        _ message: CallMessage,
        state: inout State
    ) async throws -> CallReply<State>

    /// Handle a cast message. Default returns `.noreply(state)`.
    func handleCast(
        _ message: CastMessage,
        state: inout State
    ) async throws -> CastReply<State>

    /// Called on actor initialization. Default is a no-op.
    func onInit() async throws
    /// Called on actor termination. Default is a no-op.
    func onTerminate(reason: TerminationReason) async
}
