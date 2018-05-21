module Consim

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

end
