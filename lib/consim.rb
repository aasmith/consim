require "consim/task"
require "consim/service"
require "consim/instance"
require "consim/cluster"
require "consim/simulator"

module Consim

  # Number of cgroup slices per cpu.
  VCPU = 1024

end

# TODO:
#
#  different service distribution strategies (currently random)
#  example
#  docs
#  enforce task unique names
#
