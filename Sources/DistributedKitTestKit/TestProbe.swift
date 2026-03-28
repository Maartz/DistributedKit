import DistributedCluster

public distributed actor TestProbe<Message: Sendable & Codable> {
    public typealias ActorSystem = ClusterSystem

    private var messages: [Message] = []
    private var waiters: [(id: UInt64, continuation: AsyncStream<Message>.Continuation)] = []
    private var nextWaiterId: UInt64 = 0

    public distributed func send(_ message: Message) {
        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.continuation.yield(message)
            waiter.continuation.finish()
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

        let (stream, continuation) = AsyncStream.makeStream(of: Message.self)
        waiters.append((id: waiterId, continuation: continuation))

        Task { [weak self] in
            try? await Task.sleep(for: timeout)
            try? await self?.timeoutWaiter(id: waiterId)
        }

        for await message in stream {
            return message
        }

        throw TestProbeError.timeout
    }

    public func expectNoMessage(for duration: Duration = .seconds(1)) async throws {
        let deadline = ContinuousClock.now.advanced(by: duration)
        while ContinuousClock.now < deadline {
            guard messages.isEmpty else {
                throw TestProbeError.unexpectedMessage
            }
            try await Task.sleep(for: .milliseconds(50))
        }
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
            waiter.continuation.finish()
        }
    }
}

public enum TestProbeError: Error, Sendable {
    case timeout
    case unexpectedMessage
}
