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

    def inspect
      "Service %s:\n  %s x %s\n  Total: %s cpu, %s mem" % [
        name, size, task.inspect, cpu, mem
      ]
    end
  end

end
