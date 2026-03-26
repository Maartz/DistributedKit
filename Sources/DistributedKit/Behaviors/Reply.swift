public enum CallReply<S: Sendable>: Sendable {
    case reply(S)
    case noReply(S)
    case stop(TerminationReason, S)
}

public enum CastReply<S: Sendable>: Sendable {
    case noreply(S)
    case stop(TerminationReason, S)
}

public enum TerminationReason: Sendable {
    case normal
    case shutdown
    case error(any Error & Sendable)
}
