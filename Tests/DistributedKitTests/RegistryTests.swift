import Testing
@testable import DistributedKit
import DistributedCluster

// A trivial distributed actor to use as the registered type in tests.
distributed actor RegistryTestActor {
    typealias ActorSystem = ClusterSystem
}

@Suite("Registry and ServiceKey")
struct RegistryTests {

    // MARK: - ServiceKey equality

    @Test("ServiceKeys with the same type and id are equal")
    func serviceKeySameTypeAndIdAreEqual() {
        let key1 = ServiceKey<RegistryTestActor>(id: "myService")
        let key2 = ServiceKey<RegistryTestActor>(id: "myService")
        #expect(key1 == key2)
    }

    @Test("ServiceKeys with different ids are not equal")
    func serviceKeyDifferentIdNotEqual() {
        let key1 = ServiceKey<RegistryTestActor>(id: "alpha")
        let key2 = ServiceKey<RegistryTestActor>(id: "beta")
        #expect(key1 != key2)
    }

    @Test("ServiceKey is Hashable and usable in a Set")
    func serviceKeyHashable() {
        let key1 = ServiceKey<RegistryTestActor>(id: "same")
        let key2 = ServiceKey<RegistryTestActor>(id: "same")
        let set: Set<ServiceKey<RegistryTestActor>> = [key1, key2]
        #expect(set.count == 1)
    }

    // MARK: - Register and lookup

    @Test("Register then lookup returns the registered actor")
    func registerThenLookup() async throws {
        try await withTestCluster("RegistryTests-register") { system in
            let registry = Registry(system: system)
            let actor = RegistryTestActor(actorSystem: system)
            let key = ServiceKey<RegistryTestActor>(id: "worker")

            await registry.register(actor, key: key)

            // Give the receptionist a moment to propagate.
            try await Task.sleep(for: .milliseconds(200))

            let found = await registry.lookup(key)
            #expect(found != nil)
            #expect(found?.id == actor.id)
        }
    }

    @Test("Lookup for an unknown key returns nil")
    func lookupUnknownKeyReturnsNil() async throws {
        try await withTestCluster("RegistryTests-lookup-nil") { system in
            let registry = Registry(system: system)
            let key = ServiceKey<RegistryTestActor>(id: "nonexistent")

            let found = await registry.lookup(key)
            #expect(found == nil)
        }
    }
}
