module Consim

  class Task
    attr_reader :cpu, :mem, :name

    def initialize(name, cpu:, mem:)
      @name = name
      @cpu = cpu
      @mem = mem
    end

    def accept?(instance)
      true
    end

    def inspect
      "%s %s: (%s cpu, %s mem)" % [
        self.class.name.split("::").last, name, cpu, mem
      ]
    end
  end

  class DistinctTask < Task
    def accept?(instance)
      !instance.tasks.map(&:name).include? self.name
    end
  end

end
