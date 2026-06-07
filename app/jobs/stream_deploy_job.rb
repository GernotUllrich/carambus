# frozen_string_literal: true

# Deploys the stream configuration file to the Raspberry Pi for a single
# StreamConfiguration. Used by the admin "Alle deployen" bulk action
# (Admin::StreamConfigurationsController#deploy_all) and mirrors the
# `rake streaming:deploy[TABLE_ID]` task.
#
# The actual SSH deployment is delegated to StreamControlJob's "deploy" action
# so the (non-trivial) SSH/config-file logic lives in exactly one place.
class StreamDeployJob < ApplicationJob
  queue_as :default

  def perform(stream_config_id)
    StreamControlJob.perform_now(stream_config_id, "deploy")
  end
end
