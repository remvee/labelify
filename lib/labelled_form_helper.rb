# Helper module for making labelled form.
module LabelledFormHelper
  # Pretty forms with labels.
  def labelled_form_for(name, object = nil, options = {}, &proc)
    object = instance_variable_get("@#{name}") unless object
    if messages = object.errors.on(:base)
      messages = messages.to_sentence if messages.respond_to? :to_sentence
      concat(%Q[<span class="error_message">#{h(messages)}</span>], proc.binding)
    end
    form_for(name, object, options.merge(:builder => LabelledFormBuilder), &proc)
  end

  # Form build for +form_for+ method which includes labels with all form fields.
  class LabelledFormBuilder < ActionView::Helpers::FormBuilder
    def text_field(method_name, options = {})
      generic_field(method_name, {:type => 'text'}.merge(options))
    end

    def password_field(method_name, options = {})
      generic_field(method_name, {:type => 'password'}.merge(options))
    end

    def file_field(method_name, options = {})
      generic_field(method_name, {:type => 'file'}.merge(options))
    end

    def hidden_field(method_name, options = {})
      label, html_id, param_name, value, options = collect_data(method_name, options)
      %Q@<input id="#{html_id}" name="#{param_name}" value="#{h value.to_s}" #{options} />@
    end
    
    def text_area(method_name, options = {})
      label, html_id, param_name, value, options = collect_data(method_name, options)
      %Q@
        <label for="#{html_id}">
          #{label}
          #{error_messages(method_name)}
        </label>
        <textarea id="#{html_id}" name="#{param_name}" #{options}>#{h value.to_s}</textarea>
      @
    end

    def check_box(method_name, options = {}, checked_value = "1", unchecked_value = "0")
      label, html_id, param_name, value, options = collect_data(method_name, options)
      options += ' checked="checked"' if value
      %Q@
        <label for="#{html_id}">
          #{label}
          #{error_messages(method_name)}
        </label>
        <input id="#{html_id}" type="checkbox" name="#{param_name}" value="#{h checked_value}" #{options} />
        <input type="hidden" name="#{param_name}" value="#{h unchecked_value}" />
      @
    end
    
    def submit(value = 'Submit', options = {})
      options = {:type => 'submit', :value => value}.merge(options)
      if options[:class]
        options[:class] += ' submit'
      else
        options[:class] = 'submit'
      end
      %Q@<input #{options.map { |k,v| "#{k}=\"#{h v.to_s}\"" }.join(' ')}/>@
    end

  private
    def collect_data(method_name, options)
      options[:class] = ((options[:class] || '') + ' error').strip if object.errors[method_name]

      [
        object.class.columns_hash[method_name.to_s].human_name,
        "#{object_name}_#{method_name}",
        "#{object_name}[#{method_name}]",
        object.send(method_name),
        options.map { |k,v| "#{k}=\"#{h v.to_s}\"" }.join(' ')
      ]
    end

    def generic_field(method_name, options = {})
      label, html_id, param_name, value, options = collect_data(method_name, options)
      %Q@
        <label for="#{html_id}">
          #{label}
          #{error_messages(method_name)}
        </label>
        <input id="#{html_id}" name="#{param_name}" value="#{h value.to_s}" #{options}/>
      @
    end

    def error_messages(method_name)
      if messages = object.errors.on(method_name)
        messages = messages.to_sentence if messages.respond_to? :to_sentence
        %Q@<span class="error_message">#{messages}</span>@
      end
    end
    
    def h(*args); CGI::escapeHTML(*args); end
  end
end