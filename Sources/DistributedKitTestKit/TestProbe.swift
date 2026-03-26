import DistributedCluster

public distributed actor TestProbe<Message: Sendable & Codable> {
    public typealias ActorSystem = ClusterSystem

    private struct Waiter {
        let id: UInt64
        let continuation: CheckedContinuation<Message, any Error>
    }

    private var messages: [Message] = []
    private var waiters: [Waiter] = []
    private var nextWaiterId: UInt64 = 0

    public distributed func send(_ message: Message) {
        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.continuation.resume(returning: message)
        } else {
            messages.append(message)
        }
    }

    public func expectMessage(timeout: Duration = .seconds(3)) async throws -> Message {
        if !messages.isEmpty {
            return messages.removeFirst()
        }

        let waiterId = nextWaiterId
        nextWaiterId += 1

        return try await withCheckedThrowingContinuation { continuation in
            waiters.append(Waiter(id: waiterId, continuation: continuation))

            Task { [weak self] in
                try? await Task.sleep(for: timeout)
                try? await self?.timeoutWaiter(id: waiterId)
            }
        }
    }

    public func expectNoMessage(for duration: Duration = .seconds(1)) async throws {
        try await Task.sleep(for: duration)
        guard messages.isEmpty else {
            throw TestProbeError.unexpectedMessage
        }
    }

    public var receivedMessages: [Message] {
        messages
    }

    distributed func timeoutWaiter(id: UInt64) {
        if let index = waiters.firstIndex(where: { $0.id == id }) {
            let waiter = waiters.remove(at: index)
            waiter.continuation.resume(throwing: TestProbeError.timeout)
        }
    }
}

public enum TestProbeError: Error, Sendable {
    case timeout
    case unexpectedMessage
}
