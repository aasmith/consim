module Consim

  class Cluster

    attr_reader :instances, :services

    def initialize(instances)
      @instances = instances
      @services = []
    end

    def deploy(service)
      cache = nil
      last = nil

      strategy = service.strategy.new

      service.tasks.each.with_index do |task, n|

        # find eligible instances for this task.
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

        last = strategy.call(cache)

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

      @services << service
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

  class ResourceExhaustionError < StandardError
  end

end
