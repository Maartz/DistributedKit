import Testing
@testable import DistributedKit
import DistributedCluster

// A stub distributed actor for use in ChildSpec factories.
distributed actor StubChild {
    typealias ActorSystem = ClusterSystem
}

@Suite("SupervisionTreeBuilder and Supervisor DSL")
struct SupervisionTreeBuilderTests {

    @Test("Supervisor() creates a SupervisorSpec with correct strategy and children")
    func supervisorCreatesSpec() {
        let spec = Supervisor("root", strategy: .oneForAll, maxRestarts: 5, withinSeconds: 10) {
            ChildSpec<StubChild>(name: "child1") { system in
                StubChild(actorSystem: system)
            }
        }

        #expect(spec.name == "root")
        #expect(spec.strategy == .oneForAll)
        #expect(spec.maxRestarts == 5)
        #expect(spec.withinSeconds == 10)
        #expect(spec.children.count == 1)
    }

    @Test("Supervisor() uses default parameter values")
    func supervisorDefaults() {
        let spec = Supervisor {
            ChildSpec<StubChild>(name: "a") { system in
                StubChild(actorSystem: system)
            }
        }

        #expect(spec.name == "supervisor")
        #expect(spec.strategy == .oneForOne)
        #expect(spec.maxRestarts == 3)
        #expect(spec.withinSeconds == 5)
    }

    @Test("Nested supervisors compile and are represented correctly")
    func nestedSupervisors() {
        let spec = Supervisor("outer", strategy: .restForOne) {
            Supervisor("inner", strategy: .oneForAll) {
                ChildSpec<StubChild>(name: "leaf") { system in
                    StubChild(actorSystem: system)
                }
            }
            ChildSpec<StubChild>(name: "sibling") { system in
                StubChild(actorSystem: system)
            }
        }

        #expect(spec.children.count == 2)

        // First child should be a nested supervisor.
        switch spec.children[0] {
        case .supervisor(let inner):
            #expect(inner.name == "inner")
            #expect(inner.strategy == .oneForAll)
            #expect(inner.children.count == 1)
        case .leaf:
            Issue.record("Expected .supervisor but got .leaf")
        }

        // Second child should be a leaf.
        switch spec.children[1] {
        case .leaf(let childSpec):
            #expect(childSpec.name == "sibling")
        case .supervisor:
            Issue.record("Expected .leaf but got .supervisor")
        }
    }

    @Test("SupervisorTree DSL syntax compiles and builds correctly")
    func supervisorTreeDSL() {
        let tree = SupervisorTree("app") {
            Supervisor("workers", strategy: .oneForOne) {
                ChildSpec<StubChild>(name: "w1") { system in
                    StubChild(actorSystem: system)
                }
                ChildSpec<StubChild>(name: "w2") { system in
                    StubChild(actorSystem: system)
                }
            }
        }

        #expect(tree.name == "app")
        #expect(tree.children.count == 1)

        switch tree.children[0] {
        case .supervisor(let sup):
            #expect(sup.name == "workers")
            #expect(sup.children.count == 2)
        case .leaf:
            Issue.record("Expected .supervisor but got .leaf")
        }
    }

    @Test("Multiple children at the same level")
    func multipleChildrenSameLevel() {
        let spec = Supervisor("multi") {
            ChildSpec<StubChild>(name: "a") { system in StubChild(actorSystem: system) }
            ChildSpec<StubChild>(name: "b") { system in StubChild(actorSystem: system) }
            ChildSpec<StubChild>(name: "c") { system in StubChild(actorSystem: system) }
        }

        #expect(spec.children.count == 3)
    }
}
