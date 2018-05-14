# TODO:
#
#  distinctinstance on task
#  different service distribution strategies (currently random)
#  multiple runs to test for exhaustion
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
    free_cpu?(task) && free_mem?(task)
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

end

class Task
  attr_reader :cpu, :mem, :name

  def initialize(name, cpu:, mem:)
    @name = name
    @cpu = cpu
    @mem = mem
  end
end

class Service
  attr_reader :task, :count

  def initialize(count, task)
    @count = count
    @task = task
  end

  def tasks
    [task] * count
  end

  def size
    tasks.size
  end
end

class Cluster

  attr_reader :instances, :services

  def initialize(instances)
    @instances = instances
  end

  def deploy(service)
    service.tasks.each.with_index do |task, n|

      # take a random instance that accepts task
      target = instances.select { |i| i.accept? task }.sample

      if target.nil?
        warn "Ran out allocating task %s (%s of %s)" % [
          task.name, n, service.size
        ]

        resources_used_up = Hash.new { |h,k| h[k] = 0 }

        instances.each do |i|
          i.exhausted(task).each do |res|
            resources_used_up[res] += 1
          end
        end

        resources_used_up.sort.each do |res, count|
          warn "%3s (%2.f%%) instances out of %s" % [
            count,
            count / instances.size.to_f * 100,
            res
          ]
        end

        abort "No instances left for task."

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

  private

  def gb(mb)
    mb / 1000
  end

  def vcpu(units)
    units.to_f / 1024
  end
end

