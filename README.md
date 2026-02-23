# Consim

A container placement simulator. Model a cluster of instances, define
services with CPU and memory requirements, and test how different
placement strategies affect resource utilization.

Useful for capacity planning, evaluating placement strategies, and
understanding where resource exhaustion happens before it happens in
production.

## Usage

```sh
ruby -Ilib example.rb
ruby -Ilib simulate.rb
```

Consim is pure Ruby with no dependencies.

## Quick Start

```ruby
require "consim"

# A cluster of 100 instances, each with 4 vCPUs and ~8GB RAM.
instances = 100.times.map {
  Consim::Instance.new(cpu: 4 * Consim::VCPU, mem: 7602)
}
cluster = Consim::Cluster.new(instances)

# One consul agent per instance.
# A "distinct task" runs at most once per instance.
consul = Consim::Service.new(100,
  Consim::DistinctTask.new("consul", cpu: Consim::VCPU / 4, mem: 128))

# 213 web tasks, spread evenly across instances.
web = Consim::Service.new(213,
  Consim::Task.new("web", cpu: Consim::VCPU, mem: 1024),
  strategy: Consim::LeastTaskStrategy)

# 213 tiny tasks, placed randomly.
tiny = Consim::Service.new(213,
  Consim::Task.new("tiny", cpu: Consim::VCPU / 8, mem: 64),
  strategy: Consim::RandomStrategy)

[consul, web, tiny].each { |s| cluster.deploy(s) }
cluster.summary
```

Output:

```text
Using 100 instances

 13 (13.0%) -> 3      # 13 instances have 3 tasks each
 23 (23.0%) -> 4
 23 (23.0%) -> 5
 20 (20.0%) -> 6
 13 (13.0%) -> 7
  3 ( 3.0%) -> 8
  5 ( 5.0%) -> 9

Cluster Stats
  Using 66.2% of cpu (264.62 vCPU of 400.00)
  Using 32.2% of mem (244GB of 760GB)

  Instance avg cpu usage 2.65 vCPU
  Instance avg cpu spec  4.00 vCPU

  Instance avg mem usage 2445MB
  Instance avg mem spec  7602MB
```

## Concepts

### Tasks

A task is a single unit of work with CPU and memory requirements.

```ruby
# A task needing 1 vCPU and 512MB RAM.
task = Consim::Task.new("api", cpu: Consim::VCPU, mem: 512)

# A task needing a quarter vCPU and 128MB RAM.
task = Consim::Task.new("sidecar", cpu: Consim::VCPU / 4, mem: 128)
```

CPU is measured in cgroup slices. `Consim::VCPU` (1024) represents one
full CPU core.

A `DistinctTask` is a task that will only run once per instance -- useful
for daemon-style services like Consul or log collectors:

```ruby
consul = Consim::DistinctTask.new("consul", cpu: Consim::VCPU / 4, mem: 128)
```

### Services

A service is a collection of identical tasks to be deployed together.

```ruby
# 50 copies of a web task.
service = Consim::Service.new(50, task)

# With an explicit placement strategy.
service = Consim::Service.new(50, task, strategy: Consim::BinpackMem)
```

### Instances

An instance is a single machine with fixed CPU and memory capacity. Tasks
are deployed onto instances, consuming resources.

```ruby
instance = Consim::Instance.new(cpu: 4 * Consim::VCPU, mem: 7602)

instance.accept?(task)  # Can this task fit?
instance.deploy(task)   # Place the task.
instance.free_cpu       # Remaining CPU.
instance.free_mem       # Remaining memory.
```

### Clusters

A cluster holds a set of instances and handles deploying services across
them using each service's placement strategy.

```ruby
cluster = Consim::Cluster.new(instances)
cluster.deploy(service)
cluster.summary          # Print resource utilization stats.
cluster.reset            # Clear all deployments.
```

If a task cannot be placed, `deploy` raises
`Consim::ResourceExhaustionError` with a breakdown of which resources
(CPU, memory, or both) are exhausted and on how many instances.

### Strategies

Placement strategies decide which instance receives the next task. Pass
them as the `strategy:` option when creating a service.

| Strategy | Behavior |
|---|---|
| `LeastTaskStrategy` | Picks the instance running the fewest tasks. **(default)** |
| `RandomStrategy` | Picks a random instance. |
| `BinpackMem` | Picks the instance with the least free memory (pack tightly). |
| `BinpackCpu` | Picks the instance with the least free CPU (pack tightly). |

Strategies implement a simple interface: `call(instances)` returns the
selected instance. You can write your own:

```ruby
class SpreadByMemory < Consim::AbstractStrategy
  def instance_attribute; :free_mem; end
end
```

Or for something completely custom:

```ruby
class MyStrategy
  def call(instances)
    instances.max_by(&:free_cpu)
  end
end
```

### Simulator

The simulator runs multiple deployment cycles, which is useful for
testing non-deterministic strategies like `RandomStrategy`:

```ruby
sim = Consim::Simulator.new(cluster, services)
sim.simulate(1000)
# => After 1000 runs, 987 succeeded, 13 failed (1.30% failure rate)
```
