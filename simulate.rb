# Example of running a simulation to test non-deterministic strategies.
#
# $ ruby -Ilib simulate.rb

require "consim"

NUM_INSTANCES = 100

instances = NUM_INSTANCES.times.map { Consim::Instance.new(cpu: 4 * Consim::VCPU, mem: 7602) }
cluster = Consim::Cluster.new(instances)

services = [
  Consim::Service.new(NUM_INSTANCES, Consim::DistinctTask.new("consul", cpu: Consim::VCPU / 4, mem: 128)),
  Consim::Service.new(213, Consim::Task.new("Web", cpu: Consim::VCPU, mem: 1024),
    strategy: Consim::RandomStrategy),
  Consim::Service.new(213, Consim::Task.new("Tiny", cpu: Consim::VCPU / 8, mem: 64),
    strategy: Consim::RandomStrategy)
]

sim = Consim::Simulator.new(cluster, services)
sim.simulate(100)
