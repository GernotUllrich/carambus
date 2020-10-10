require File.expand_path('../environment', __FILE__)

include Stalker


module Stalker
  extend self

  def log_job_begin(name, args)
    args_flat = unless args.blank?
                  '(' + args.inject([]) do |accum, (key, value)|
                    accum << "#{key}=#{value}"
                  end.join(' ') + ')'
                else
                  ''
                end

    log ["#{Time.now} Working", name, args_flat].join(' ')
    @job_begun = Time.now
  end

  def log_job_end(name, failed=false)
    ellapsed = Time.now - @job_begun
    ms = (ellapsed.to_f * 1000).to_i
    log "#{Time.now} Finished #{name} in #{ms}ms #{failed ? ' (failed)' : ''}"
  end
end

silence_warnings {RAILS_DEFAULT_LOGGER = Logger.new("#{Rails.root}/log/worker.log")}
RAILS_DEFAULT_LOGGER.level = Logger::INFO
module Rails
  def self.logger
    RAILS_DEFAULT_LOGGER
  end
end

def logger
  Rails.logger
end

def report(str, opts = {})
  str_ = "#{"[#{opts[:caller]}]" if opts[:caller].present?}#{str}"
  puts str_ if opts[:debug].present?
  Rails.logger.info str_
end

job 'clean_merge_channel' do |args|
  # begin
  #   @channel = Channel.undeleted_or_protected.find_by_id(args['channel_id'])
  #   if @channel.andand.stream_urls.blank?
  #     @channel.destroy
  #     logger.info "#{Time.now} [clean_merge_channel] destroyed Channel[#{@channel.id}]"
  #   end
  # rescue Exception => e
  #   logger.info "#{Time.now} [clean_merge_channel] Problem working on id=#{@channel.id}: #{e}\n#{e.backtrace.join("\n")}"
  # end
end
