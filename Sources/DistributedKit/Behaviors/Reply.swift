/// The return type for ``ServerBehavior/handleCall(_:state:)`` methods.
///
/// OTP equivalent: `{:reply, value, state}`, `{:noreply, state}`, `{:stop, reason, state}`.
public enum CallReply<S: Sendable>: Sendable {
    /// Reply with the updated state. OTP: `{:reply, value, state}`.
    case reply(S)
    /// Don't reply; keep the updated state. OTP: `{:noreply, state}`.
    case noReply(S)
    /// Stop the actor with a reason. OTP: `{:stop, reason, state}`.
    case stop(TerminationReason, S)
}

/// The return type for ``ServerBehavior/handleCast(_:state:)`` methods.
///
/// OTP equivalent: `{:noreply, state}`, `{:stop, reason, state}`.
public enum CastReply<S: Sendable>: Sendable {
    /// Continue with the updated state. OTP: `{:noreply, state}`.
    case noreply(S)
    /// Stop the actor with a reason. OTP: `{:stop, reason, state}`.
    case stop(TerminationReason, S)
}

/// The reason an actor terminated.
///
/// Used by ``ServerBehavior/onTerminate(reason:)`` and the stop variants
/// of ``CallReply`` and ``CastReply``.
public enum TerminationReason: Sendable {
    /// Normal, expected termination.
    case normal
    /// Shutdown requested by the supervisor or system.
    case shutdown
    /// Terminated due to an error.
    case error(any Error & Sendable)
}
