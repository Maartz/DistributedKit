import DistributedCluster
import DistributedKit

// MARK: - Messages

enum CounterCall: Sendable, Codable {
    case get
}

enum CounterCast: Sendable, Codable {
    case increment
    case decrement
    case add(Int)
}

// MARK: - Actor

@Service(name: "counter")
distributed actor CounterWorker: ServerBehavior {
    typealias CallMessage = CounterCall
    typealias CastMessage = CounterCast
    typealias State = Int

    var _state: Int = 0

    init(actorSystem: ClusterSystem) {
        self.actorSystem = actorSystem
    }

    func handleCall(
        _ message: CounterCall,
        state: inout Int
    ) async throws -> CallReply<Int> {
        switch message {
        case .get:
            return .reply(state)
        }
    }

    func handleCast(
        _ message: CounterCast,
        state: inout Int
    ) async throws -> CastReply<Int> {
        switch message {
        case .increment:
            state += 1
        case .decrement:
            state -= 1
        case .add(let n):
            state += n
        }
        return .noreply(state)
    }

    // MARK: - Distributed API (using processCall / processCast helpers)

    distributed func getCount() async throws -> Int {
        let (reply, newState) = try await processCall(.get, state: _state)
        _state = newState
        switch reply {
        case .reply(let value): return value
        case .noReply(let value): return value
        case .stop(_, let value): return value
        }
    }

    distributed func increment() async throws {
        let (_, newState) = try await processCast(.increment, state: _state)
        _state = newState
    }

    distributed func decrement() async throws {
        let (_, newState) = try await processCast(.decrement, state: _state)
        _state = newState
    }

    distributed func add(_ n: Int) async throws {
        let (_, newState) = try await processCast(.add(n), state: _state)
        _state = newState
    }
}
