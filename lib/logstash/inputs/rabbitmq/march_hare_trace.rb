# encoding: utf-8
require "logstash/json"

class LogStash::Inputs::RabbitMQTrace
  # MarchHare-based implementation for JRuby
  module MarchHareTraceImpl
    require "logstash/inputs/rabbitmq/march_hare_trace"
    include LogStash::Inputs::RabbitMQ::MarchHareImpl
    
    
    def format_for(content_type)
      if !content_type.nil? then
        for format in @formats.keys do
          escaped = Regexp.escape(format).gsub('\*','.*?')
          regex = Regexp.new "^#{escaped}$", Regexp::IGNORECASE
          return @formats[format] if (content_type =~ regex)          
        end
      end          
      
      return "binary"
    end
    
    def converter_for(content_encoding) 
      content_encoding = "UTF-8" if content_encoding.nil? || content_encoding.empty?
      converter = LogStash::Util::Charset.new(content_encoding)
      converter.logger = @logger
      converter
    end
    
    def decode_payload(event, content_type, content_encoding, data)
      
      format = format_for(content_type)
      
      if format == "binary" then
        event["message"] = "Binary data"
      else
        begin
          msg = converter_for(content_encoding).convert(data)
          event["message"] = msg
          if format == "json"            
            event["payload"] = {"json" => LogStash::Json.load(msg)}
          else
            event["payload"] = {format => msg}
          end          
        rescue => e
          event["message"] = "Undecodable Binary data"
        end
      end

      if @include_metadata then
        event["payload"] ||= {}
        event["payload"]["size"] = data.length
      end
    end
    
    def to_ruby(obj)
      if obj.respond_to?(:to_hash) then
        hash = {}
        obj.to_hash.each_pair {|key, value| hash[key.to_s] = to_ruby(value) }
        hash
      elsif obj.respond_to?(:to_a) then
        arr = []
        obj.to_a.each { |item| arr <<= to_ruby(item) }
        arr
      else
        obj
      end
    end
    
    def create_event(metadata, data)
      headers =  metadata.properties.headers
      if !headers.nil? then
        original_exchange = headers["exchange_name"].to_s
        if !@excluded_exchanges.include?(original_exchange) then
                  
          routing_key = metadata.routing_key.to_s
          if routing_key.start_with?("publish.")
            action = "publish"
            queue = nil
          elsif routing_key.start_with?("deliver.")
            action = "deliver"
     	      queue = routing_key[8..-1]
          end
        
          if @actions.include?(action) && (queue.nil? || !@excluded_queues.include?(queue)) then
            event = LogStash::Event.new()
            decorate(event)
            original_properties = headers["properties"]

            decode_payload(event, original_properties["content_type"].to_s, original_properties["content_encoding"].to_s, data)
            event["action"] = action
          
            if @include_metadata then
              event["queue"] = queue unless queue.nil?
            
              event["exchange"] = original_exchange
            
              event["routing_keys"] = to_ruby(headers["routing_keys"])
              event["node"] = headers["node"].to_s
              
              original_headers = original_properties["headers"] || {}
              
              properties = to_ruby(original_properties)
              event["properties"] = properties            
            end
            return event
          end
        end
        nil
      end    
    end
  end # MarchHareTraceImpl
end
