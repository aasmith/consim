module Consim

  # Abstract strategy that provides a cache and does the work to min_by
  # a specified instance attribute, such as task_count.
  class AbstractStrategy
    def initialize
      @cache = []
    end

    def call(instances)
      @cache = build_cache(instances) if @cache.empty?

      @cache.shift
    end

    def build_cache(instances)
      slacker = instances.min_by(&instance_attribute)

      instances.select do |i|
        i.send(instance_attribute) == slacker.send(instance_attribute)
      end
    end

  end

  # Picks an instance running the fewest tasks.
  class LeastTaskStrategy < AbstractStrategy
    def instance_attribute; :task_count; end
  end

  # Picks a random instance.
  class RandomStrategy
    define_method :call, :sample.to_proc
  end

  # Binpackers - picks the instance with the scarcest resource.

  class BinpackMem < AbstractStrategy
    def instance_attribute; :free_mem; end
  end

  class BinpackCpu < AbstractStrategy
    def instance_attribute; :free_cpu; end
  end

  DefaultStrategy = LeastTaskStrategy

end
