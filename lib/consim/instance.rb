module Consim

  class Instance
    attr_reader :cpu, :mem, :tasks
    attr_reader :free_cpu, :free_mem

    def initialize(cpu:, mem:)
      @cpu, @free_cpu = cpu, cpu
      @mem, @free_mem = mem, mem

      @tasks = []
    end

    def accept?(task)
      free_cpu?(task) && free_mem?(task) && task.accept?(self)
    end

    def free_cpu?(task)
      task.cpu < free_cpu
    end

    def free_mem?(task)
      task.mem < free_mem
    end

    def used_cpu
      cpu - free_cpu
    end

    def used_mem
      mem - free_mem
    end

    def task_count
      tasks.size
    end

    def exhausted(task)
      [].tap do |resources|
        resources << "cpu" unless free_cpu?(task)
        resources << "mem" unless free_mem?(task)
      end
    end

    def deploy(task)
      if accept? task
        @free_cpu -= task.cpu
        @free_mem -= task.mem

        tasks << task
      end
    end

    def undeploy(task)
      tasks.delete task

      @free_cpu += task.cpu
      @free_mem += task.mem
    end

    def reset
      until tasks.empty? do
        undeploy tasks.last
      end
    end

  end

end
