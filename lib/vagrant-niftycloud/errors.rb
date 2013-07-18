require "vagrant"

module VagrantPlugins
  module NiftyCloud
    module Errors
      class VagrantNiftyCloudError < Vagrant::Errors::VagrantError
        error_namespace("vagrant_niftycloud.errors")
      end

      class NiftyCloudConfigurationError < VagrantNiftyCloudError
        error_key(:niftycloud_configuration_error)
      end

      class NiftyCloudArgumentError < VagrantNiftyCloudError
        error_key(:niftycloud_argument_error)
      end
      
      class NiftyCloudResponseError < VagrantNiftyCloudError
        error_key(:niftycloud_response_error)
      end

      class NiftyCloudResponseFormatError < VagrantNiftyCloudError
        error_key(:niftycloud_response_format_error)
      end

      class InstanceReadyTimeout < VagrantNiftyCloudError
        error_key(:instance_ready_timeout)
      end

      class RsyncError < VagrantNiftyCloudError
        error_key(:rsync_error)
      end
    end
  end
end
