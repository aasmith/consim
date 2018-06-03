# Example of basic usage.
#
# $ ruby -Ilib example.rb

require "consim"

# The number of instances in our cluster.
NUM_INSTANCES = 100

# Create 100 instances, each with 4 CPUs and about 8GB RAM.
instances = NUM_INSTANCES.times.map { Consim::Instance.new(cpu: 4 * Consim::VCPU, mem: 7602) }

# Our cluster of instances.
cluster = Consim::Cluster.new instances

# The list of services to run in the cluster.
services = [

  # Run a "distinct task", that can run once and only once any instance.
  # It needs 25% of a single CPU, and 128 MB of memory.
  Consim::Service.new(NUM_INSTANCES, Consim::DistinctTask.new("consul", cpu: Consim::VCPU / 4, mem: 128)),

  # Run 213 tasks of a web service. It needs a full cpu and 1 GB of memory.
  Consim::Service.new(213, Consim::Task.new("Web", cpu: Consim::VCPU, mem: 1024),
    strategy: Consim::LeastTaskStrategy),

  # Run a tiny service to be randomly spread out.
  Consim::Service.new(213, Consim::Task.new("Web", cpu: Consim::VCPU/8, mem: 64),
    strategy: Consim::RandomStrategy)
]

# Deploy each of the services into the cluster.
services.each do |service|
  cluster.deploy service
end

# Print some stats about resource usage in the cluster.
cluster.summary
