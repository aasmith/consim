module Consim

  class Service
    attr_reader :task, :count, :strategy

    def initialize(count, task, name = nil, strategy: DefaultStrategy)
      @strategy = strategy
      @count = count
      @task = task
      @name = name
    end

    def tasks
      count.times.map { task.dup }
    end

    def size
      tasks.size
    end

    def cpu
      count * task.cpu
    end

    def mem
      count * task.mem
    end

    def name
      @name || task.name
    end

    def choose(instances)
      strategy.call instances
    end

    def inspect
      "Service %s:\n  %s x %s\n  Total: %s cpu, %s mem" % [
        name, size, task.inspect, cpu, mem
      ]
    end
  end

  # Picks an instance running the fewest tasks.
  LeastTaskStrategy = lambda { |instances| instances.min_by &:task_count }

  # Picks a random instance.
  RandomStrategy = :sample.to_proc

  # Binpackers - picks the instance with the scarcest resource.
  BinpackMem = lambda { |instances| instances.min_by &:free_mem }
  BinpackCpu = lambda { |instances| instances.min_by &:free_cpu }

  DefaultStrategy = LeastTaskStrategy

end
