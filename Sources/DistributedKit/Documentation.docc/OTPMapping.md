# Elixir/OTP Equivalence

A comprehensive mapping between Elixir/OTP concepts and their DistributedKit equivalents.

## Overview

DistributedKit maps Erlang/OTP patterns to Swift's type system. If you're familiar with OTP, this guide shows you where each concept lives in DistributedKit.

## Quick Reference

| Elixir/OTP | DistributedKit | Notes |
|---|---|---|
| `use GenServer` | `@Service` + `ServerBehavior` | Macro + protocol |
| `GenServer.call/2` | `processCall` | Helper on `ServerBehavior` |
| `GenServer.cast/2` | `processCast` | Helper on `ServerBehavior` |
| `GenServer.init/1` | `onInit()` | Default no-op |
| `GenServer.terminate/2` | `onTerminate(reason:)` | Default no-op |
| `{:reply, val, state}` | `CallReply.reply(state)` | |
| `{:noreply, state}` | `CastReply.noreply(state)` | |
| `{:stop, reason, state}` | `.stop(reason, state)` | |
| `Supervisor.start_link/2` | `SupervisorTree { Supervisor { } }` | Result builder |
| `child_spec/1` | `@Service` generates `childSpec()` | Macro |
| `:one_for_one` | `.oneForOne` | `SupervisionStrategy` |
| `:one_for_all` | `.oneForAll` | `SupervisionStrategy` |
| `:rest_for_one` | `.restForOne` | `SupervisionStrategy` |
| `:permanent` | `.permanent` | `RestartStrategy` |
| `:transient` | `.transient` | `RestartStrategy` |
| `:temporary` | `.temporary` | `RestartStrategy` |
| `Registry` / `:global` | `Registry` + `ServiceKey` | |
| `GenServer.start_link(name: ...)` | `Singleton<T>.resolve(on:)` | |
| `:application` callback | `DistributedKitApplication` | |
| SIGTERM shutdown | `ServiceGroup` + signals | Via `swift-service-lifecycle` |
| `LifecycleWatch` | `LifecycleWatch` | DistributedCluster native |
| `max_restarts` | `maxRestarts:` on `Supervisor()` | |
| ExUnit + Mox | `DistributedKitTestKit` | `TestProbe`, `withCluster` |

## Side-by-Side Examples

### Defining a Server

**Elixir:**

```elixir
defmodule Counter do
  use GenServer

  def init(initial) do
    {:ok, initial}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:add, n}, _from, state) do
    {:reply, state + n, state + n}
  end
end
```

**DistributedKit:**

```swift
@Service(name: "counter", restart: .permanent)
distributed actor Counter: ServerBehavior {
    typealias ActorSystem = ClusterSystem
    typealias CallMessage = CounterCall
    typealias CastMessage = Never
    typealias State = Int

    private var _state: Int = 0

    enum CounterCall: Sendable, Codable {
        case get
        case add(Int)
    }

    func handleCall(_ msg: CounterCall, state: inout Int) async throws -> CallReply<Int> {
        switch msg {
        case .get:
            return .reply(state)
        case .add(let n):
            state += n
            return .reply(state)
        }
    }
}
```

### Building a Supervision Tree

**Elixir:**

```elixir
children = [
  {Counter, 0},
  {Logger, []},
  %{
    id: :db_supervisor,
    start: {Supervisor, :start_link, [[
      {DBPool, []},
      {Cache, []}
    ], [strategy: :one_for_all]]}
  }
]

Supervisor.start_link(children, strategy: :one_for_one)
```

**DistributedKit:**

```swift
SupervisorTree("App") {
    Supervisor("workers", strategy: .oneForOne) {
        Counter.childSpec()
        Logger.childSpec()
    }
    Supervisor("db", strategy: .oneForAll) {
        DBPool.childSpec()
        Cache.childSpec()
    }
}
```

### Starting the Application

**Elixir:**

```elixir
# application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Counter, 0}
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
end
```

**DistributedKit:**

```swift
// main.swift
try await DistributedKitApplication(name: "MyApp") {
    Supervisor(strategy: .oneForOne) {
        Counter.childSpec()
    }
}.run()
```

## Key Differences from OTP

### Actors vs Processes

In Elixir/OTP, processes are lightweight and untyped — any process can receive any message. In DistributedKit, actors are strongly typed. Messages are defined as `Codable` enums, and the compiler enforces type safety.

### Distributed by Default

DistributedKit actors are `distributed actor` types backed by `ClusterSystem`. They can transparently run across nodes. In OTP, distribution is opt-in via `:net_kernel`.

### No `receive` Loop

OTP GenServers use a `receive` loop that dispatches messages. DistributedKit uses `distributed func` methods — each remote call is a direct method invocation. The `ServerBehavior` protocol provides `handleCall`/`handleCast` for OTP-style message processing, but direct `distributed func` calls are equally valid and often simpler.

### Macro-Generated ChildSpec

OTP derives `child_spec` from `use GenServer` callbacks. DistributedKit uses the `@Service` macro to generate `childSpec()` at compile time, producing a fully typed `ChildSpec<A>` value.

### Result Builder Syntax

OTP supervision trees are lists of tuples/maps. DistributedKit uses Swift's result builder syntax for compile-time validated tree construction with support for conditionals and loops:

```swift
SupervisorTree("App") {
    for config in workerConfigs {
        ChildSpec<Worker>(name: config.name) { sys in
            Worker(actorSystem: sys, config: config)
        }
    }

    if enableMonitoring {
        Monitor.childSpec()
    }
}
```
