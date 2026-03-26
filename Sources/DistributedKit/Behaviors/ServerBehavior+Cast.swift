extension ServerBehavior {
    /// Process a cast message, returning the reply and the updated state.
    /// Use from within a `distributed func`:
    /// ```swift
    /// let (reply, newState) = try await processCast(.increment, state: _state)
    /// _state = newState
    /// ```
    public func processCast(
        _ message: CastMessage,
        state currentState: State
    ) async throws -> (reply: CastReply<State>, newState: State) {
        var state = currentState
        let reply = try await handleCast(message, state: &state)
        return (reply, state)
    }
}
