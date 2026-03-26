extension ServerBehavior {
    public func onInit() async throws {}

    public func onTerminate(reason: TerminationReason) async {}

    public func handleCall(
        _ message: CallMessage,
        state: inout State
    ) async throws -> CallReply<State> {
        throw DistributedKitError.unhandledCall(String(describing: message))
    }

    public func handleCast(
        _ message: CastMessage,
        state: inout State
    ) async throws -> CastReply<State> {
        .noreply(state)
    }
}
