# encoding: utf-8
class LogStash::Inputs::RabbitMQTrace
  module BunnyTraceImpl
    require "logstash/inputs/rabbitmq/bunny_trace"
    include LogStash::Inputs::RabbitMQ::BunnyImpl
    
    def create_event(delivery_info, properties, data)
      
    end
    
  end # BunnyTraceImpl
end
