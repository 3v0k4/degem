module Degem
  class MultiDelegator
    def initialize(*delegates)
      @delegates = delegates
    end

    def method_missing(method, *args, &block)
      delegate = @delegates.find { _1.respond_to?(method) }
      return delegate.public_send(method, *args, &block) if delegate

      super
    end

    def respond_to_missing?(method, include_private = false)
      @delegates.any? { _1.respond_to?(method, include_private) } || super
    end
  end
end
