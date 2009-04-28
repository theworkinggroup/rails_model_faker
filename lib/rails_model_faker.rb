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
        name = name.to_sym

        @rmf_can_fake[name] =
          if (block)
            block
          else
            # For associations, delay creation of block until first call
            # to allow for additional relationships to be defined after
            # the can_fake call. Leave placeholder only.
            :reflection
          end
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
      params.merge!(scope(:create).symbolize_keys) if (scope(:create))
    
      @rmf_can_fake.each do |field, block|
        unless (params.key?(field))
          case (block)
          when :reflection
            if (reflection = reflect_on_association(field))
              primary_key = reflection.primary_key_name.to_sym
              block = @rmf_can_fake[field] =
                lambda do |existing_params|
                  existing_params.key?(primary_key) ? nil : reflection.klass.send(:create_fake)
                end
            end
          end
            
          result = block.call(params)
          
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
