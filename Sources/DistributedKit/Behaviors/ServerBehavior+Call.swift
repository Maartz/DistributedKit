extension ServerBehavior {
    /// Process a call message, returning the reply and the updated state.
    /// Use from within a `distributed func`:
    /// ```swift
    /// let (reply, newState) = try await processCall(.get, state: _state)
    /// _state = newState
    /// ```
    public func processCall(
        _ message: CallMessage,
        state currentState: State
    ) async throws -> (reply: CallReply<State>, newState: State) {
        var state = currentState
        let reply = try await handleCall(message, state: &state)
        return (reply, state)
    }
}
