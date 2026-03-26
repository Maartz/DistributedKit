import DistributedCluster

public protocol ServerBehavior: DistributedActor where ActorSystem == ClusterSystem {
    associatedtype CallMessage: Sendable & Codable
    associatedtype CastMessage: Sendable & Codable
    associatedtype State: Sendable

    func handleCall(
        _ message: CallMessage,
        state: inout State
    ) async throws -> CallReply<State>

    func handleCast(
        _ message: CastMessage,
        state: inout State
    ) async throws -> CastReply<State>

    func onInit() async throws
    func onTerminate(reason: TerminationReason) async
}
