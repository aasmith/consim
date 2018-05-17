# TODO:
#
#  different service distribution strategies (currently random)
#  example
#  docs
#  enforce task unique names
#

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
end

class DistinctTask < Task
  def accept?(instance)
    !instance.tasks.map(&:name).include? self.name
  end
end

class ResourceExhaustionError < StandardError
end

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

class Cluster

  attr_reader :instances, :services

  def initialize(instances)
    @instances = instances
  end

  def deploy(service)
    cache = nil
    last = nil

    service.tasks.each.with_index do |task, n|

      # take a random instance that accepts task
      cache ||= instances.select { |i| i.accept? task }

      # build the list of acceptable instances once, and store
      # the instance that was most recently selected. If the instance
      # is no longer able to accept the task next time around, then
      # remove it from the list. This removes the need to keep rebuilding
      # the list of acceptable instances every deploy. This provides a
      # ~15x speedup.

      if last && !last.accept?(task)
        cache.delete last
      end

      last = cache.sample

      target = last


      if target.nil?
        err = []

        err << "Ran out allocating task %s (%s of %s):" % [
          task.name, n, service.size
        ]

        resources_used_up = Hash.new { |h,k| h[k] = 0 }

        instances.each do |i|
          i.exhausted(task).each do |res|
            resources_used_up[res] += 1
          end
        end

        err << resources_used_up.sort.map do |res, count|
          " * %3s (%2.f%%) instances out of %s" % [
            count,
            count / instances.size.to_f * 100,
            res
          ]
        end

        raise ResourceExhaustionError.new(err.flatten.join("\n"))

      end

      target.deploy task
    end
  end

  def summary
    puts "Using %s instances" % instances.size
    puts

    summary = Hash.new { |h,k| h[k] = 0 }

    instances.each do |i|
      summary[i.tasks.count] += 1
    end

    summary.keys.sort.each do |k|
      puts "%3s (%4.1f%%) -> %s" % [
        summary[k],
        summary[k] / instances.size.to_f * 100,
        k
      ]
    end

    # cluster stats

    cusedmem = instances.map(&:used_mem).reduce(:+)
    cusedcpu = instances.map(&:used_cpu).reduce(:+)

    cmem = instances.map(&:mem).reduce(:+)
    ccpu = instances.map(&:cpu).reduce(:+)

    puts
    puts "Cluster Stats"

    puts "  Using %2.1f%% of cpu (%.2f vCPU of %.2f)" % [
      cusedcpu / ccpu.to_f * 100,
      vcpu(cusedcpu),
      vcpu(ccpu)
    ]

    puts "  Using %2.1f%% of mem (%sGB of %sGB)" % [
      cusedmem / cmem.to_f * 100,
      gb(cusedmem),
      gb(cmem)
    ]

    puts
    puts "  Instance avg cpu usage %.2f vCPU" % [
      vcpu(cusedcpu / instances.size)
    ]

    puts "  Instance avg cpu spec  %.2f vCPU" % [
      vcpu(ccpu / instances.size)
    ]

    puts
    puts "  Instance avg mem usage %sMB" % [
      cusedmem / instances.size
    ]

    puts "  Instance avg mem spec  %sMB" % [
      cmem / instances.size
    ]
  end

  def reset
    instances.each do |instance|
      instance.reset
    end
  end

  private

  def gb(mb)
    mb / 1000
  end

  def vcpu(units)
    units.to_f / 1024
  end
end

# A class to facilitize multiple deployment run-throughs, as some placement
# strategies can be non-deterministic.
class Simulator

  attr_reader :cluster, :services

  def initialize(cluster, services)
    @cluster = cluster
    @services = services
  end

  def simulate(n = 100)
    STDOUT.sync

    errors = []

    n.times do |i|
      begin
        services.each do |service|
          cluster.deploy service
        end

      rescue ResourceExhaustionError => e
        print "F"

        errors << e
      end

      print "."

      cluster.reset
    end

    puts
    puts
    puts "After %s runs, %s succeeded, %s failed (%.2f%% failure rate)" % [
      n,
      n - errors.size,
      errors.size,
      errors.size / n.to_f * 100
    ]

    puts "with the following errors:" unless errors.empty?

    errors.each do |e|
      puts e
    end
  end
end
