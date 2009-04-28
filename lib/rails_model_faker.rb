module RailsModelFaker
  def self.included(base)
    base.send(:extend, ClassMethods)
    base.send(:include, InstanceMethods)
  end
  
  def self.add_module(new_module)
    FakeMethods.send(:extend, new_module)
  end
  
  def self.can_fake(*names, &block)
    case (names.last)
    when Hash
      options = names.pop
    end
    
    if (options and options[:with])
      block = options[:with]
    end

    FakeMethods.send(
      :extend,
      names.inject(Module.new) do |m, name|
        m.send(:define_method, name, &block)
        m
      end
    )
  end
  
  def self.config(&block)
    RailsModelFaker.instance_eval(&block)
  end
  
  def self.include(addon)
    RailsModelFaker.send(:extend, addon)
  end
  
  module FakeMethods
    # Placeholder for generic fake methods
  end
  
  module ClassMethods
    def fake_field_config
      @rmf_can_fake ||= { }
    end
    
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
        name = name.to_sym

        # For associations, delay creation of block until first call
        # to allow for additional relationships to be defined after
        # the can_fake call. Leave placeholder (true) instead.

        @rmf_can_fake[name] = block || true
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

    def create_fake!(params = nil)
      create!(fake_params(params))
    end
    
    def fake(name, params = nil)
      name = name.to_sym
      
      block = @rmf_can_fake[name]

      case (block)
      when true
        # Configure association faker the first time it is called
        if (reflection = reflect_on_association(name))
          primary_key = reflection.primary_key_name.to_sym
          block = @rmf_can_fake[name] =
            lambda do |new_class, existing_params|
              existing_params.key?(primary_key) ? nil : reflection.klass.send(:create_fake)
            end
        else
          block = @rmf_can_fake[name] = name
        end
      end

      params ||= { }

      case (block)
      when Module
        block.send(name, self, params)
      when Symbol
        FakeMethods.send(block, self, params)
      when nil
        raise "Unknown faker method #{name}"
      else
        block.call(self, params)
      end
    end
    
    def fake_params(params = nil)
      params = (params || { }).symbolize_keys
      params.merge!(scope(:create).symbolize_keys) if (scope(:create))
    
      @rmf_can_fake.each do |field, block|
        unless (params.key?(field))
          result = fake(field, params)
          
          case (result)
          when nil
            # Declined to populate parameters
          else
            params[field] = result
          end
        end
      end
      
      params
    end
  end
  
  module InstanceMethods
    # ...
  end
end
