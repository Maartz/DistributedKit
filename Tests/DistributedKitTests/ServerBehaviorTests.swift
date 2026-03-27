import Testing
@testable import DistributedKit
import DistributedCluster

@Suite("ServerBehavior default implementations")
struct ServerBehaviorTests {

    @Test("Minimal conforming distributed actor compiles and can be created")
    func minimalConformingActor() async throws {
        try await withTestCluster("ServerBehaviorTests-minimal") { system in
            let server = MinimalServer(actorSystem: system)
            // If we got here, the actor compiled and was created successfully.
            _ = server
        }
    }

    @Test("Default handleCall throws DistributedKitError.unhandledCall")
    func defaultHandleCallThrows() async throws {
        try await withTestCluster("ServerBehaviorTests-call") { system in
            let server = MinimalServer(actorSystem: system)
            do {
                _ = try await server.testHandleCall("hello", initialState: 0)
                Issue.record("Expected handleCall to throw DistributedKitError.unhandledCall")
            } catch let error as DistributedKitError {
                switch error {
                case .unhandledCall(let desc):
                    #expect(desc.contains("hello"))
                default:
                    Issue.record("Expected .unhandledCall but got \(error)")
                }
            }
        }
    }

    @Test("Default handleCast returns .noreply with unchanged state")
    func defaultHandleCastReturnsNoreply() async throws {
        try await withTestCluster("ServerBehaviorTests-cast") { system in
            let server = MinimalServer(actorSystem: system)
            let resultState = try await server.testHandleCast("hello", initialState: 42)
            #expect(resultState == 42)
        }
    }

    @Test("Default onInit is a no-op and does not throw")
    func defaultOnInit() async throws {
        try await withTestCluster("ServerBehaviorTests-init") { system in
            let server = MinimalServer(actorSystem: system)
            try await server.testOnInit()
        }
    }

    @Test("Default onTerminate is a no-op")
    func defaultOnTerminate() async throws {
        try await withTestCluster("ServerBehaviorTests-terminate") { system in
            let server = MinimalServer(actorSystem: system)
            try await server.testOnTerminateNormal()
            try await server.testOnTerminateShutdown()
        }
    }
}
