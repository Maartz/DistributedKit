import DistributedCluster
import Foundation
import Logging

actor SupervisorRuntime {
    private let system: ClusterSystem
    private let name: String
    private let logger: Logger

    struct ManagedChild: Sendable {
        let spec: any ChildSpecProtocol
        var actor: (any DistributedActor)?
        let index: Int
    }

    private var managedChildren: [ManagedChild] = []
    private var restartCounts: [String: (count: Int, windowStart: ContinuousClock.Instant)] = [:]
    private var supervisorTasks: [String: SupervisorRuntime] = [:]

    init(system: ClusterSystem, name: String) {
        self.system = system
        self.name = name
        self.logger = Logger(label: "distributedkit.supervisor.\(name)")
    }

    func startTree(_ children: [SupervisionChild]) async throws {
        for (index, child) in children.enumerated() {
            switch child {
            case .leaf(let spec):
                let actor = try await startChild(spec: spec, index: index)
                managedChildren.append(ManagedChild(spec: spec, actor: actor, index: index))
                logger.info("Started child '\(spec.name)' [\(index)]")

            case .supervisor(let supervisorSpec):
                let childRuntime = SupervisorRuntime(system: system, name: supervisorSpec.name)
                try await childRuntime.startTree(supervisorSpec.children)
                supervisorTasks[supervisorSpec.name] = childRuntime
                logger.info("Started supervisor '\(supervisorSpec.name)'")
            }
        }
    }

    private func startChild(spec: any ChildSpecProtocol, index: Int) async throws -> any DistributedActor {
        do {
            return try await spec.start(on: system)
        } catch {
            throw DistributedKitError.factoryFailed(name: spec.name, underlying: error)
        }
    }

    func restartChild(
        named childName: String,
        strategy: SupervisionStrategy,
        maxRestarts: Int = 3,
        withinSeconds: TimeInterval = 5
    ) async throws {
        guard let childIndex = managedChildren.firstIndex(where: { $0.spec.name == childName }) else {
            return
        }

        let child = managedChildren[childIndex]

        guard child.spec.restart != .temporary else {
            logger.info("Child '\(childName)' is temporary, not restarting")
            managedChildren[childIndex].actor = nil
            return
        }

        let now = ContinuousClock.now
        var record = restartCounts[childName] ?? (count: 0, windowStart: now)
        let elapsed = now - record.windowStart
        if elapsed > .seconds(withinSeconds) {
            record = (count: 0, windowStart: now)
        }
        record.count += 1
        restartCounts[childName] = record

        if record.count > maxRestarts {
            throw DistributedKitError.supervisionMaxRestartsExceeded(name: childName, count: record.count)
        }

        switch strategy {
        case .oneForOne:
            let newActor = try await startChild(spec: child.spec, index: child.index)
            managedChildren[childIndex].actor = newActor
            logger.info("Restarted child '\(childName)' (oneForOne)")

        case .oneForAll:
            for i in managedChildren.indices {
                managedChildren[i].actor = nil
            }
            for i in managedChildren.indices {
                let newActor = try await startChild(spec: managedChildren[i].spec, index: i)
                managedChildren[i].actor = newActor
            }
            logger.info("Restarted all children (oneForAll)")

        case .restForOne:
            for i in childIndex..<managedChildren.count {
                managedChildren[i].actor = nil
            }
            for i in childIndex..<managedChildren.count {
                let newActor = try await startChild(spec: managedChildren[i].spec, index: i)
                managedChildren[i].actor = newActor
            }
            logger.info("Restarted children from '\(childName)' onward (restForOne)")
        }
    }
}
