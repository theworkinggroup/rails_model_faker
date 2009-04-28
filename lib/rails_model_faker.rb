module RailsModelFaker
  def self.included(base)
    base.send(:extend, ClassMethods)
    base.send(:include, InstanceMethods)
  end
  
  module ClassMethods
    def can_fake(*names, &block)
      options = nil

      case (names.last)
      when Hash
        options = names.pop
      end
      
      if (options and options[:with])
        block = options[:with]
      end
      
      @rmf_can_fake ||= { }
      
      names.flatten.each do |name|
        @rmf_can_fake[name.to_sym] = block
      end
    end
    
    def can_fake?(*names)
      @rmf_can_fake ||= { }
      
      names.flatten.reject do |name|
        @rmf_can_fake.key?(name)
      end.empty?
    end
    
    def build_fake(params = nil)
      new(fake_params(params))
    end

    def create_fake(params = nil)
      create(fake_params(params))
    end
    
    def fake_param(name)
      name = name.to_sym
      
      return unless (@rmf_can_fake[name])
      
      @rmf_can_fake[name].call(name)
    end
    
    def fake_params(params = nil)
      params = (params || { }).symbolize_keys
      
      @rmf_can_fake.each do |field, block|
        unless (params.key?(field))
          params[field] = block.call(field)
        end
      end
      
      params
    end
  end
  
  module InstanceMethods
    # ...
  end
end