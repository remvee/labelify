# Helper module for making labeled forms.
module Labelify
  mattr_accessor :default_error_placement, :default_label_placement
  
  # Create a form for a given model object.  Unlike +form_for+ this variant
  # automatically includes labels and errors.  The +form_builder+ handles all
  # standard form helper methods.  All the field and select sections are decorated
  # with a label, except for +hidden_field+.  The <code>:no_label_for</code>
  # option can be provide to suppress labels on other methods as well by giving
  # a string or regex.
  #
  # Example:
  #   <% labelled_form_for :person, @person, :url => { :action => "update" } do |f| %>
  #     <%= f.text_field :first_name %>
  #     <%= f.text_field :last_name %>
  #     <%= f.text_area :biography %>
  #     <%= f.check_box :admin %>
  #   <% end %>
  #
  # Options:
  # [<code>:error_placement</code>]  one of <code>:before_field</code>, <code>:after_field</code>, <code>:before_label</code>, <code>:after_label</code> and defaults to <code>:inside_label</code>
  # [<code>:label_placement</code>]  one of <code>:after_field</code> and defaults to <code>:before_field</code>
  # [<code>:no_label_for</code>]     an array of method names not to render a label for
  def labelled_form_for(object_name, *args, &proc) # :yields: form_builder
    object, options = collect_arguments(object_name, *args, &proc)
    render_base_errors(object)
    form_for(object_name, object, options, &proc)
  end

  # Create a scope around a model object like +form_for+ but without rendering +form+ tags.
  def labelled_fields_for(object_name, *args, &proc) # :yields: form_builder
    object, options = collect_arguments(object_name, *args, &proc)
    render_base_errors(object)
    fields_for(object_name, object, options, &proc)
  end

private
  def collect_arguments(object_name, *args, &proc)
    options = Hash === args.last ? args.pop : {}
    options = options.merge(:binding => proc.binding, :builder => FormBuilder)

    object = *args
    if [String,Symbol].include?(object_name.class)
      object ||= instance_variable_get("@#{object_name.to_s.sub(/\[\]$/, '')}")
    end

    [object, options]
  end

  def render_base_errors(object)
    if object.respond_to?(:errors) && object.errors.on(:base)
      messages = object.errors.on(:base)
      messages = messages.to_sentence if messages.respond_to? :to_sentence
      concat(content_tag(:span, h(messages), :class => 'error_message'))
    end
  end

  # Form build for +form_for+ method which includes labels with almost
  # all form fields.  All unknown method calls are passed through to
  # the underlying template hoping to hit a form helper method.
  class FormBuilder
    attr_accessor :object_name, :object, :options

    def initialize(object_name, object, template, options, proc) # :nodoc:
      @object_name, @object, @template, @options, @proc = object_name, object, template, options, proc

      @default_options = @options ? @options.slice(:index) : {}
      if @object_name.to_s.match(/\[(.*)\]$/)
        @object ||= @template.instance_variable_get("@#{Regexp.last_match(1)}")
      end

      @options[:no_label_for] &&= [*@options[:no_label_for]]
      @options[:no_label_for] ||= [:hidden_field, :label]
    end

    def labelled_fields_for(object_name, *args, &block)
      fields_for(object_name, *args, &block)
    end

    # Taken directly from Rails fields_for implementation
    def fields_for(record_or_name_or_array, *args, &block)
      if options.has_key?(:index)
        index = "[#{options[:index]}]"
      elsif defined?(@auto_index)
        self.object_name = @object_name.to_s.sub(/\[\]$/,"")
        index = "[#{@auto_index}]"
      else
        index = ""
      end

      if options[:builder]
        args << {} unless args.last.is_a?(Hash)
        args.last[:builder] ||= options[:builder]
      end

      case record_or_name_or_array
      when String, Symbol
        if nested_attributes_association?(record_or_name_or_array)
          return fields_for_with_nested_attributes(record_or_name_or_array, args, block)
        else
          name = "#{object_name}#{index}[#{record_or_name_or_array}]"
        end
      when Array
        object = record_or_name_or_array.last
        name = "#{object_name}#{index}[#{ActionController::RecordIdentifier.singular_class_name(object)}]"
        args.unshift(object)
      else
        object = record_or_name_or_array
        name = "#{object_name}#{index}[#{ActionController::RecordIdentifier.singular_class_name(object)}]"
        args.unshift(object)
      end

      @template.fields_for(name, *args, &block)
    end

    # Pass methods to underlying template hoping to hit some homegrown form helper method.
    # Including an option with the name +label+ will have the following effect:
    # [+true+]           include a label (the default).
    # [+false+]          exclude the label.
    # [any other value]  the label to use.
    def method_missing(selector, method_name, *args, &block)
      args << {} unless args.last.kind_of?(Hash)
      options = args.pop
      options.merge!(:object => @object)

      r = ''
      error_placement = options.delete(:error_placement) || @options[:error_placement] || Labelify.default_error_placement || :inside_label
      label_placement = options.delete(:label_placement) || @options[:label_placement] || Labelify.default_label_placement || :before_field
      invisible = @options[:no_label_for].include?(selector)

      unless invisible
        label_value = options.delete(:label)
        if (label_value.nil? || label_value != false) && !options.delete(:no_label)
          label_options = {:error_placement => error_placement}
          label_options[:class] = options[:class] if options.include?(:class)
          label_options[:label_value] = label_value unless label_value.kind_of? TrueClass
          label_content = label(method_name, objectify_options(label_options))
        end
      end

      r << label_content if !label_content.nil? && label_placement == :before_field
      r << inline_error_messages(method_name) if error_placement == :before_field
      r << @template.send(selector, @object_name, method_name, *(args << objectify_options(options)), &block)
      r << inline_error_messages(method_name) if error_placement == :after_field
      r << label_content if !label_content.nil? && label_placement == :after_field

      invisible ? r : content_tag(:div, r, :class => 'field')
    end

    # Returns a submit button.  This button has style class +submit+.  If given a +type+ option +button+
    # a button element will be rendered instead of input element.  This button element will contain a
    # span element with the given value.
    # [+value+]   the text on the button
    # [+options+] HTML attributes
    def submit(value = 'Submit', options = {})
      if options[:class]
        options[:class] += ' submit'
      else
        options[:class] = 'submit'
      end

      if options[:type].to_s == 'button'
        content_tag(:button, content_tag(:span, h(value)), options.merge(:type => 'submit'))
      else
        tag(:input, {:type => 'submit', :value => t(value)}.merge(options))
      end
    end

    # Returns a label for a given attribute.  The +for+ attribute point to the same
    # +id+ attribute generated by the form helper tags.
    # [+method_name+] model object attribute name
    # [+options+]     HTML attributes
    def label(method_name, *args)
      options = Hash === args.last ? args.pop : {}
      column_name = @object.class.respond_to?(:human_attribute_name) && @object.class.human_attribute_name(method_name.to_s)

      label_value = options.delete(:label_value)
      label_value ||= String === args.first && args.shift
      label_value ||= column_name ? column_name : method_name.to_s.humanize

      r = ''
      error_placement = options.delete(:error_placement) || @options[:error_placement] || Labelify.default_error_placement || :inside_label
      r << inline_error_messages(method_name) if error_placement == :before_label
      r << @template.label(@object_name, method_name,
        content_tag(:span, t(label_value), :class => 'field_name') + (error_placement == :inside_label ? inline_error_messages(method_name) : ''),
        options.merge(:object => @object)
      )
      r << inline_error_messages(method_name) if error_placement == :after_label
      r
    end

    # Error messages for given field, concatenated with +to_sentence+.
    def inline_error_messages(method_name)
      if @object.respond_to?(:errors) && @object.errors.on(method_name.to_s)
        messages = @object.errors.on(method_name.to_s)
        messages = messages.kind_of?(Array) ? messages.map{|m|t(m)}.to_sentence : t(messages)
        " " + content_tag(:span, messages, :class => 'error_message')
      else
        ''
      end
    end

    # Base error messages
    def base_error_messages
      if @object.respond_to?(:errors) && @object.errors.on(:base)
        messages = @object.errors.on(:base)
        messages = messages.to_sentence if messages.respond_to? :to_sentence
        content_tag(:span, h(messages), :class => 'error_message')
      end
    end

    # Keep the default error_messages.
    def error_messages(options = {})
      @template.error_messages_for(@object_name, options.merge(:object => @object))
    end

    # Scope a piece of the form to an associated object.
    def with_association(association, &proc) # :yields:
      with_object(association, @object ? @object.send(association) : nil, &proc)
    end

    # Scope a piece of the form to another object.
    def with_object(object_name, object = nil)
      object ||= eval("@#{object_name}", @options[:binding])
      old_object, old_object_name = @object, @object_name
      @object_name, @object = object_name, object
      yield self
    ensure
      @object, @object_name = old_object, old_object_name
    end

  private
    def h(*args); CGI::escapeHTML(*args); end

    def options2attributes(options)
      options.map { |k,v| "#{k}=\"#{h v.to_s}\"" }.join(' ')
    end

    if Object.const_defined?(:Localization)
      def t(text); Localization._(text); end
    else
      def t(text); text; end
    end

    def tag(*args)
      @template.send(:tag, *args)
    end

    def content_tag(*args)
      @template.send(:content_tag, *args)
    end

    def objectify_options(options)
      @default_options.merge(options.merge(:object => @object))
    end

    def nested_attributes_association?(association_name)
      @object.respond_to?("#{association_name}_attributes=")
    end

    def fields_for_with_nested_attributes(association_name, args, block)
      name = "#{object_name}[#{association_name}_attributes]"
      association = @object.send(association_name)
      explicit_object = args.first if args.first.respond_to?(:new_record?)

      if association.is_a?(Array)
        children = explicit_object ? [explicit_object] : association
        explicit_child_index = args.last[:child_index] if args.last.is_a?(Hash)

        children.map do |child|
          fields_for_nested_model("#{name}[#{explicit_child_index || nested_child_index}]", child, args, block)
        end.join
      else
        fields_for_nested_model(name, explicit_object || association, args, block)
      end
    end

    def fields_for_nested_model(name, object, args, block)
      if object.new_record?
        @template.fields_for(name, object, *args, &block)
      else
        @template.fields_for(name, object, *args) do |builder|
          @template.concat builder.hidden_field(:id)
          block.call(builder)
        end
      end
    end

    def nested_child_index
      @nested_child_index ||= -1
      @nested_child_index += 1
    end
  end
end
