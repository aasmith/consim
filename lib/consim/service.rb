module Consim

  class Service
    attr_reader :task, :count

    def initialize(count, task, name = nil)
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
  end

end
