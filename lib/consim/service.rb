module Consim

  class Service
    attr_reader :task, :count

    def initialize(count, task)
      @count = count
      @task = task
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
  end

end
