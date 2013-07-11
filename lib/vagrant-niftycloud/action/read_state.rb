require "log4r"

module VagrantPlugins
  module NiftyCloud
    module Action
      # This action reads the state of the machine and puts it in the
      # `:machine_state_id` key in the environment.
      class ReadState
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_niftycloud::action::read_state")
        end

        def call(env)
          env[:machine_state_id] = read_state(env[:niftycloud_compute], env[:machine])

          @app.call(env)
        end

        def read_state(niftycloud, machine)
          return :not_created if machine.id.nil?

          # Find the machine
          server = env[:niftycloud_compute].describe_instances(:instance_id => machine.id)).reservationSet.item.first.instancesSet.item.first
          if server.nil?
            # The machine can't be found
            @logger.info("Machine not found or terminated, assuming it got destroyed.")
            machine.id = nil
            return :not_created
          end

          state = server.instanceState.name
          case state
          when 'stopped', 'warning', 'waiting', 'creating', 'suspending', 'uploading', 'import_error', 'pending'
            @logger.info("Machine not found or terminated, assuming it got destroyed.")
            machine.id = nil
            return :not_created
          else
            return state.to_sym
          end
        end
      end
    end
  end
end
