# Helper module for making labelled form.
module LabelledFormHelper
  # Create a form for a given model object.  Labels and errors are automatically included.
  # The +form_builder+ is a LabelledFormBuilder, which handles all standard form helper
  # methods.  All the field and select sections are decorated with a label, except for +check_box+,
  # +radio_button+ and +hidden_field+.
  #
  # Example:
  #   <% labelled_form_for :person, @person, :url => { :action => "update" } do |f| %>
  #     <%= f.text_field :first_name %>
  #     <%= f.text_field :last_name %>
  #     <%= f.text_area :biography %>
  #     <%= f.check_box :admin %>
  #   <% end %>
  def labelled_form_for(object_name, *args, &proc) # :yields: form_builder
    options = args.pop if Hash === args.last
    object = *args
    object = instance_variable_get("@#{object_name}") unless object
    if object.respond_to?(:errors) && messages = object.errors.on(:base)
      messages = messages.to_sentence if messages.respond_to? :to_sentence
      concat(%Q@<span class="error_message">#{h(messages)}</span>@, proc.binding)
    end
    options = options.merge(:binding => proc.binding, :builder => LabelledFormBuilder)
    form_for(object_name, object, options, &proc)
  end

  # Form build for +form_for+ method which includes labels with almost all form fields.  All
  # unknown method calls are passed through to the underlying template hoping to hit a form helper
  # method.
  class LabelledFormBuilder
    attr_accessor :object_name, :object

    def initialize(object_name, object, template, options, proc)
      @object_name, @object, @template, @options, @proc = object_name, object, template, options, proc        
    end
    
    # Pass methods to underlying template hoping to hit some homegrown form helper method.
    def method_missing(selector, method, *args)
      args << {} unless args.last.kind_of?(Hash)
      options = args.last
      options.merge!(:object => @object)
      
      concat label(method) unless options.delete(:no_label)
      concat @template.send(selector, @object_name, method, *args)
    end

    # Returns a submit button.  This button has style class +submit+.
    # [+value+]   the text on the button
    # [+options+] HTML attributes
    def submit(value = 'Submit', options = {})
      options = {:type => 'submit', :value => t(value)}.merge(options)
      if options[:class]
        options[:class] += ' submit'
      else
        options[:class] = 'submit'
      end
      concat %Q@<input #{options2attributes(options)}/>@
    end

    # Returns a label for a given attribute.  The +for+ attribute point to the same
    # +id+ attribute generated by the form helper tags.
    # [+method_name+] model object attribute name
    # [+options+]     HTML attributes
    def label(method_name, options = {})
      column = object.class.respond_to?(:columns_hash) && object.class.columns_hash[method_name.to_s]
      concat %Q@
        <label for="#{object_name}_#{method_name}" #{options2attributes(options)}>
          <span class="field_name">#{t(column ? column.human_name : method_name.to_s.humanize)}</span>
          #{error_messages(method_name)}
        </label>
      @
    end

    # Error messages for given field, concatenated with +to_sentence+.
    def error_messages(method_name)
      if object.respond_to?(:errors) && messages = object.errors.on(method_name)
        messages = messages.to_sentence if messages.respond_to? :to_sentence
        %Q@<span class="error_message">#{t(messages)}</span>@
      end
    end
    
  private
    def h(*args); CGI::escapeHTML(*args); end
    
    def options2attributes(options)
      options.map { |k,v| "#{k}=\"#{h v.to_s}\"" }.join(' ')
    end
    
    def concat(text)
      @template.concat(text, @options[:binding])
      ''
    end
    
    def t(text)
      Object.const_defined?(:Localization) ? Localization._(text) : text
    end
  end
end