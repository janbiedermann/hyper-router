module React
  class Router
    include Hyperloop::Component::Mixin

    class << self
      def hash_history
        RouterHistory.new(`ReactRouter.hashHistory`)
      end

      def browser_history
        RouterHistory.new(`ReactRouter.browserHistory`)
      end

      def create_memory_history(opts = {})
        RouterHistory.new(`ReactRouter.createMemoryHistory(#{opts.to_n})`)
      end

      def Link(to, opts = {}, &children)
        opts[:activeClassName] = opts.delete(:active_class).to_n if opts[:active_class]
        opts[:activeStyle] = opts.delete(:active_style).to_n if opts[:active_style]
        if opts[:only_active_on_index]
          opts[:onlyActiveOnIndex] = opts.delete(:only_active_on_index).to_n
        end
        opts[:to] = to.to_n
        Native::Link(opts, &children)
      end
    end

    def route(*args, &children)
      DSL::Route.new(*args, &children)
    end

    def index(opts = {})
      DSL::Index.new(opts)
    end

    def redirect(from, opts = {})
      DSL::Route.new(opts.merge(path: from)).on(:enter) { |c| c.replace(opts[:to]) }
    end

    def index_redirect(opts = {})
      DSL::Index.new(opts).on(:enter) { |c| c.replace(opts[:to]) }
    end

    def build_routes(&block)
      React::Router::DSL.build_routes(&block)
    end

    def gather_params
      params = { routes: React::Router::DSL.children_to_n(build_routes { routes }) }
      params[:history] = history.to_n if respond_to? :history
      %w(create_element stringify_query parse_query_string on_error on_update).each do |method|
        params[method.camelcase(false)] = send("#{method}_wrapper") if respond_to? method
      end
      params
    end

    def render
      Native::Router(gather_params)
    end

    # private

    class Native < React::NativeLibrary
      imports 'ReactRouter'
    end

    def stringify_query_wrapper
      ->(query) { stringify_query(query) }
    end

    def parse_query_string_wrapper
      ->(query_string) { parse_query_string(query_string) }
    end

    def on_update_wrapper
      -> { on_update(Hash.new(`this.props`), Hash.new(`this.state`)) }
    end

    def create_element_wrapper
      lambda do |component, props|
        comp_classes = React::API.class_eval { @@component_classes }
        rb_component = comp_classes.detect { |_key, value| value == component }.first
        # Not sure if this could ever happen,
        # could not figure out a way to test it so commented it out.
        # unless rb_component
        #   rb_component = Class.new(React::Component::Base)
        #   comp_classes[rb_component] = component
        # end
        rb_props = convert_props(props)
        result = create_element(rb_component, rb_props)
        convert_or_create_element(result, component, props, rb_component, rb_props)
      end
    end

    def on_error_wrapper
      -> (message) { on_error(message) }
    end

    private

    def convert_props(props)
      children_are_null = `#{props}.children == undefined || #{props}.children == null`
      { children:     children_are_null ? [] : [`#{props}.children`].flatten,
        history:      `#{props}.history`,
        location:     `#{props}.location`,
        params:       `#{props}.params`,
        route:        `#{props}.route`,
        route_params: `#{props}.route_params`,
        routes:       `#{props}.routes` }
    end

    def convert_or_create_element(result, component, props, rb_component, rb_props)
      is_result_native_react_element = `!!result._isReactElement`
      if is_result_native_react_element
        result
      elsif !result
        `React.createElement(#{component}, #{props})`
      elsif result.is_a? React::Element
        result.to_n
      else
        React.create_element(rb_component, rb_props).to_n
      end
    end
  end
end

module Hyperloop
  class Router < React::Router
  end
end
