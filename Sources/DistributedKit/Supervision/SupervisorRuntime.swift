import DistributedCluster
import Foundation
import Logging

distributed actor SupervisorRuntime: LifecycleWatch {
    typealias ActorSystem = ClusterSystem

    private let name: String
    private let strategy: SupervisionStrategy?
    private let maxRestarts: Int
    private let withinSeconds: TimeInterval
    private let logger: Logger
    private let children: [SupervisionChild]

    struct ManagedChild: Sendable {
        let spec: any ChildSpecProtocol
        var actor: (any DistributedActor)?
        var actorID: ActorID?
        let index: Int
    }

    private var managedChildren: [ManagedChild] = []
    private var restartCounts: [String: (count: Int, windowStart: ContinuousClock.Instant)] = [:]
    private var supervisorTasks: [String: SupervisorRuntime] = [:]
    private var shutdownContinuation: AsyncStream<Void>.Continuation?
    private var isStopping: Bool = false

    init(
        actorSystem: ClusterSystem,
        name: String,
        children: [SupervisionChild] = [],
        strategy: SupervisionStrategy? = nil,
        maxRestarts: Int = 3,
        withinSeconds: TimeInterval = 5
    ) {
        self.actorSystem = actorSystem
        self.name = name
        self.children = children
        self.strategy = strategy
        self.maxRestarts = maxRestarts
        self.withinSeconds = withinSeconds
        self.logger = Logger(label: "distributedkit.supervisor.\(name)")
    }

    // MARK: - Tree startup

    distributed func start() async throws {
        try await startTree(children)
    }

    private func startTree(_ children: [SupervisionChild]) async throws {
        for (index, child) in children.enumerated() {
            switch child {
            case .leaf(let spec):
                let (actor, actorID) = try await startChild(spec: spec, index: index)
                managedChildren.append(ManagedChild(spec: spec, actor: actor, actorID: actorID, index: index))
                logger.info("Started child '\(spec.name)' [\(index)]")

            case .supervisor(let supervisorSpec):
                let childRuntime = SupervisorRuntime(
                    actorSystem: actorSystem,
                    name: supervisorSpec.name,
                    children: supervisorSpec.children,
                    strategy: supervisorSpec.strategy,
                    maxRestarts: supervisorSpec.maxRestarts,
                    withinSeconds: supervisorSpec.withinSeconds
                )
                try await childRuntime.start()
                supervisorTasks[supervisorSpec.name] = childRuntime
                logger.info("Started supervisor '\(supervisorSpec.name)'")
            }
        }
    }

    private func startChild(spec: any ChildSpecProtocol, index: Int) async throws -> (any DistributedActor, ActorID) {
        do {
            if let watchable = spec as? any _WatchableSpec {
                return try await watchable._watchedStart(actorSystem, self)
            } else {
                let actor = try await spec.start(on: actorSystem)
                let actorID = actor.id as! ActorID
                return (actor, actorID)
            }
        } catch let error as DistributedKitError {
            throw error
        } catch {
            throw DistributedKitError.factoryFailed(name: spec.name, underlying: error)
        }
    }

    // MARK: - LifecycleWatch

    /// Simulate termination for testing. In production, called by LifecycleWatch.
    distributed func simulateTermination(of id: ActorID) async {
        await _handleTermination(of: id)
    }

    func terminated(actor id: ActorID) async {
        await _handleTermination(of: id)
    }

    private func _handleTermination(of id: ActorID) async {
        guard !isStopping else { return }

        guard let childIndex = managedChildren.firstIndex(where: { $0.actorID == id }) else {
            return
        }
        let child = managedChildren[childIndex]

        guard child.spec.restart != .temporary else {
            logger.info("[\(name)] '\(child.spec.name)' terminated (temporary, not restarting)")
            managedChildren[childIndex].actor = nil
            managedChildren[childIndex].actorID = nil
            return
        }

        guard let strategy else {
            logger.warning("[\(name)] '\(child.spec.name)' terminated but no strategy configured")
            managedChildren[childIndex].actor = nil
            managedChildren[childIndex].actorID = nil
            return
        }

        do {
            try await restartChild(at: childIndex, strategy: strategy)
        } catch {
            logger.error("[\(name)] Restart of '\(child.spec.name)' failed: \(error)")
            initiateShutdown()
        }
    }

    // MARK: - Restart

    private func restartChild(at childIndex: Int, strategy: SupervisionStrategy) async throws {
        let child = managedChildren[childIndex]

        // Rate limiting
        let now = ContinuousClock.now
        var record = restartCounts[child.spec.name] ?? (count: 0, windowStart: now)
        let elapsed = now - record.windowStart
        if elapsed > .seconds(withinSeconds) {
            record = (count: 0, windowStart: now)
        }
        record.count += 1
        restartCounts[child.spec.name] = record

        if record.count > maxRestarts {
            throw DistributedKitError.supervisionMaxRestartsExceeded(name: child.spec.name, count: record.count)
        }

        switch strategy {
        case .oneForOne:
            let (newActor, newID) = try await startChild(spec: child.spec, index: child.index)
            managedChildren[childIndex].actor = newActor
            managedChildren[childIndex].actorID = newID
            logger.info("Restarted '\(child.spec.name)' (oneForOne)")

        case .oneForAll:
            for i in managedChildren.indices {
                managedChildren[i].actor = nil
                managedChildren[i].actorID = nil
            }
            for i in managedChildren.indices {
                let (newActor, newID) = try await startChild(spec: managedChildren[i].spec, index: i)
                managedChildren[i].actor = newActor
                managedChildren[i].actorID = newID
            }
            logger.info("Restarted all children (oneForAll)")

        case .restForOne:
            for i in childIndex..<managedChildren.count {
                managedChildren[i].actor = nil
                managedChildren[i].actorID = nil
            }
            for i in childIndex..<managedChildren.count {
                let (newActor, newID) = try await startChild(spec: managedChildren[i].spec, index: i)
                managedChildren[i].actor = newActor
                managedChildren[i].actorID = newID
            }
            logger.info("Restarted from '\(child.spec.name)' onward (restForOne)")
        }
    }

    // MARK: - Shutdown

    distributed func waitUntilStopped() async {
        if isStopping { return }
        let (stream, continuation) = AsyncStream.makeStream(of: Void.self)
        shutdownContinuation = continuation
        for await _ in stream { break }
    }

    distributed func initiateShutdown() {
        guard !isStopping else { return }
        isStopping = true
        shutdownContinuation?.finish()
        shutdownContinuation = nil
    }
}
