import Testing
@testable import DistributedKit
import DistributedCluster

// A concrete DistributedKitService for testing Singleton.resolve.
distributed actor TestService: DistributedKitService {
    typealias ActorSystem = ClusterSystem

    static let serviceName: String = "test-service"
    static let restartStrategy: RestartStrategy = .permanent
}

@Suite("Singleton")
struct SingletonTests {

    @Test("Singleton.resolve throws serviceNotFound when nothing is registered")
    func resolveThrowsWhenNotRegistered() async throws {
        try await withTestCluster("SingletonTests-resolve") { system in
            await #expect(throws: DistributedKitError.self) {
                _ = try await Singleton<TestService>.resolve(on: system)
            }
        }
    }

    @Test("Singleton.resolve throws DistributedKitError.serviceNotFound with correct service name")
    func resolveErrorContainsServiceName() async throws {
        try await withTestCluster("SingletonTests-name") { system in
            do {
                _ = try await Singleton<TestService>.resolve(on: system)
                Issue.record("Expected DistributedKitError.serviceNotFound to be thrown")
            } catch let error as DistributedKitError {
                switch error {
                case .serviceNotFound(let name):
                    #expect(name == "test-service")
                default:
                    Issue.record("Expected .serviceNotFound but got \(error)")
                }
            }
        }
    }
}
