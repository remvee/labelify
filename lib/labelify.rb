# Helper module for making labeled forms.
module Labelify
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
  # [<code>:no_label_for</code>]     an array of method names not to render a label for
  def labelled_form_for(object_name, *args, &proc) # :yields: form_builder
    object, options = collect_arguments(object_name, *args, &proc)
    render_base_errors(object, &proc)
    form_for(object_name, object, options, &proc)
  end
  
  # Create a scope around a model object like +form_for+ but without rendering +form+ tags.
  def labelled_fields_for(object_name, *args, &proc) # :yields: form_builder
    object, options = collect_arguments(object_name, *args, &proc)
    render_base_errors(object, &proc)
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
  
  def render_base_errors(object, &proc)
    if object.respond_to?(:errors) && object.errors.on(:base)
      messages = object.errors.on(:base)
      messages = messages.to_sentence if messages.respond_to? :to_sentence
      concat(content_tag(:span, h(messages), :class => 'error_message'), proc.binding)
    end
  end
  
  # Form build for +form_for+ method which includes labels with almost
  # all form fields.  All unknown method calls are passed through to
  # the underlying template hoping to hit a form helper method.
  class FormBuilder
    def initialize(object_name, object, template, options, proc) # :nodoc:
      @object_name, @object, @template, @options, @proc = object_name, object, template, options, proc
      
      @options[:no_label_for] &&= [*@options[:no_label_for]]
      @options[:no_label_for] ||= [:hidden_field, :label]
    end
    
    # Pass methods to underlying template hoping to hit some homegrown form helper method.
    # Including an option with the name +label+ will have the following effect:
    # [+true+]           include a label (the default).
    # [+false+]          exclude the label.
    # [any other value]  the label to use.
    def method_missing(selector, method_name, *args, &block)
      args << {} unless args.last.kind_of?(Hash)
      options = args.last
      options.merge!(:object => @object)

      r = ''
      error_placement = options.merge(@options)[:error_placement]
      
      unless @options[:no_label_for].include?(selector)
        label_value = options.delete(:label)
        if (label_value.nil? || label_value != false) && !options.delete(:no_label)
          label_options = {:error_placement => error_placement}
          label_options[:class] = options[:class] if options.include?(:class)
          label_options[:label_value] = label_value unless label_value.kind_of? TrueClass
          r << label(method_name, label_options)
        end
      end

      r << error_messages(method_name) if error_placement == :before_field
      r << @template.send(selector, @object_name, method_name, *args, &block)
      r << error_messages(method_name) if error_placement == :after_field
      r
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
      column = @object.class.respond_to?(:columns_hash) && @object.class.columns_hash[method_name.to_s]
      
      label_value = options.delete(:label_value)      
      label_value ||= String === args.first && args.shift
      label_value ||= column ? column.human_name : method_name.to_s.humanize
     
      r = '' 
      error_placement = options.merge(@options)[:error_placement] || :inside_label
      r << error_messages(method_name) if error_placement == :before_label
      r << @template.label(@object_name, method_name,
        content_tag(:span, t(label_value), :class => 'field_name') + (error_placement == :inside_label ? error_messages(method_name) : ''),
        options.merge(:object => @object)
      )
      r << error_messages(method_name) if error_placement == :after_label
      r
    end

    # Error messages for given field, concatenated with +to_sentence+.
    def error_messages(method_name)
      if @object.respond_to?(:errors) && @object.errors.on(method_name)
        messages = @object.errors.on(method_name)
        messages = messages.kind_of?(Array) ? messages.map{|m|t(m)}.to_sentence : t(messages)
        content_tag(:span, messages, :class => 'error_message')
      else
        ''
      end
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
    
    def t(text)
      Object.const_defined?(:Localization) ? Localization._(text) : text
    end
    
    def tag(*args)
      @template.send(:tag, *args)
    end
    
    def content_tag(*args)
      @template.send(:content_tag, *args)
    end
  end
end
