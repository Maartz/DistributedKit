import DistributedCluster
import DistributedKit

// MARK: - Messages

enum WorkerCall: Sendable, Codable {
    case getStatus
}

enum WorkerCast: Sendable, Codable {
    case doWork(String)
    case setLabel(String)
    case crash
}

struct WorkerState: Sendable {
    var label: String = "worker"
    var jobsProcessed: Int = 0
    var isHealthy: Bool = true
}

// MARK: - Worker Actor (uses @Service macro)

@Service(name: "worker")
distributed actor Worker: ServerBehavior {
    typealias CallMessage = WorkerCall
    typealias CastMessage = WorkerCast
    typealias State = WorkerState

    var _state = WorkerState()

    init(actorSystem: ClusterSystem) {
        self.actorSystem = actorSystem
    }

    func handleCall(
        _ message: WorkerCall,
        state: inout WorkerState
    ) async throws -> CallReply<WorkerState> {
        switch message {
        case .getStatus:
            return .reply(state)
        }
    }

    func handleCast(
        _ message: WorkerCast,
        state: inout WorkerState
    ) async throws -> CastReply<WorkerState> {
        switch message {
        case .doWork:
            state.jobsProcessed += 1
            return .noreply(state)

        case .setLabel(let name):
            state.label = name
            return .noreply(state)

        case .crash:
            state.isHealthy = false
            return .stop(.error(WorkerError.simulatedCrash), state)
        }
    }

    // MARK: - Distributed API (using processCall / processCast helpers)

    distributed func status() async throws -> String {
        let (reply, newState) = try await processCall(.getStatus, state: _state)
        _state = newState
        switch reply {
        case .reply(let s): return "[\(s.label)] jobs=\(s.jobsProcessed) healthy=\(s.isHealthy)"
        case .noReply(let s): return "[\(s.label)] jobs=\(s.jobsProcessed)"
        case .stop(_, let s): return "[\(s.label)] STOPPED"
        }
    }

    distributed func setLabel(_ name: String) async throws {
        let (_, newState) = try await processCast(.setLabel(name), state: _state)
        _state = newState
    }

    distributed func doWork(_ job: String) async throws -> Int {
        let (_, newState) = try await processCast(.doWork(job), state: _state)
        _state = newState
        return newState.jobsProcessed
    }

    distributed func simulateCrash() async throws {
        let (_, newState) = try await processCast(.crash, state: _state)
        _state = newState
    }
}

enum WorkerError: Error, Sendable {
    case simulatedCrash
}
