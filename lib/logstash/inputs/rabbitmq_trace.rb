# encoding: utf-8
require "logstash/inputs/rabbitmq"
require "logstash/namespace"

# Trace events from a RabbitMQ.
#
# The default settings will listen to amq.rabbitmq.trace and listen to all messages except logs.
# Will decode json payload.
#
# To enable tracing on RabbitMQ start tracing plugin on any queue in desired virtual host.
# It can be any queue, better not used one to avoid trace file growth.
#
# This has been tested with March Hare. You can
# find links to both here:
#
# * RabbitMQ - <http://www.rabbitmq.com/>
# * March Hare: <http://rubymarchhare.info>
# * Bunny - <https://github.com/ruby-amqp/bunny>
class LogStash::Inputs::RabbitMQTrace < LogStash::Inputs::RabbitMQ

  config_name "rabbitmq_trace"
  milestone 1

  #
  # (Optional) Exchange binding
  #

  # Optional.
  #
  # The name of the exchange to bind the queue to.
  config :exchange, :validate => :string, :default => "amq.rabbitmq.trace"

  # Optional.
  #
  # The routing key to use when binding a queue to the exchange.
  # This is only relevant for direct or topic exchanges.
  #
  # * Routing keys are ignored on fanout exchanges.
  # * Wildcards are not valid on direct exchanges.
  config :key, :validate => :string, :default => "#"
  
  # Optional.
  #
  # Exchanges to ignore for publishes and deliveries
  config :excluded_exchanges, :validate => :array, :default => ["amq.rabbitmq.log"]
  
  # Optional.
  #
  # List of queues to ingore deliveries to
  config :excluded_queues, :validate => :array, :default => []
  
  # Optional.
  #
  # List of actions to trace
  config :actions, :validate => :array, :default => ["publish", "delivery"]
  
  # Optional.
  #
  # Formats to use when decoding payload based on content type
  #
  # Formats:
  #   json - decode into event.payload.json
  #   binary - skip
  #   any other - put text in event.payload.{format}
  # 
  # * Wildcards are valid on content types.
  config :formats, :validate => :hash, :default => {"application/json" => "json", "text/*" => "text"}


  def initialize(params)
    super
  end

  # Use March Hare on JRuby to avoid IO#select CPU spikes
  # (see github.com/ruby-amqp/bunny/issues/95).
  #
  # On MRI, use Bunny.
  #
  # See http://rubybunny.info and http://rubymarchhare.info
  # for the docs.
  if RUBY_ENGINE == "jruby"
    require "logstash/inputs/rabbitmq/march_hare_trace"

    include MarchHareTraceImpl
  else
    @logger.error("Bunny Trace is not supported")
    require "logstash/inputs/rabbitmq/bunny_trace"

    include BunnyTraceImpl
  end
end # class LogStash::Inputs::RabbitMQ
