require "log4r"

module VagrantPlugins
  module NiftyCloud
    module Action
      # This action reads the SSH info for the machine and puts it into the
      # `:machine_ssh_info` key in the environment.
      class ReadSSHInfo
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_niftycloud::action::read_ssh_info")
        end

        def call(env)
          env[:machine_ssh_info] = read_ssh_info(env[:niftycloud_compute], env[:machine])

          @app.call(env)
        end

        def read_ssh_info(niftycloud, machine)
          return nil if machine.id.nil?

          # Find the machine
          instances = env[:niftycloud_compute].describe_instances(:instance_id => machine.id)
          if instances.nil?
            # The machine can't be found
            @logger.info("Machine couldn't be found, assuming it got destroyed.")
            machine.id = nil
            return nil
          end

          reservationSet.item.each do |set|
            set.instancesSet.item.each do |instance|
              server = instance.instancesSet.item.first
              if server.instanceId == machine.id
                # Read the DNS info
                return {
                  :host => server.ipAddress
                  :port => 22
                }
              end
            end
          end
        end
      end
    end
  end
end
