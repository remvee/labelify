# Helper module for making labelled form.
module LabelledFormHelper
  # Pretty forms with labels.
  def labelled_form_for(name, object = nil, options = {}, &proc)
    object = instance_variable_get("@#{name}") unless object
    if messages = object.errors.on(:base)
      messages = messages.to_sentence if messages.respond_to? :to_sentence
      concat(%Q@<span class="error_message">#{h(messages)}</span>@, proc.binding)
    end
    form_for(name, object, options.merge(:builder => LabelledFormBuilder), &proc)
  end

  # Form build for +form_for+ method which includes labels with all form fields.
  class LabelledFormBuilder < ActionView::Helpers::FormBuilder
    %w(text_field password_field file_field check_box radio_button text_area hidden_field select
              datetime_field date_field collection_select country_select time_zone_select).each do |method|
      define_method(method.to_sym) do |method_name, *args|
        label_tag(method_name) + @template.send(method.to_sym, object_name, method_name, *args)
      end
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
    def label_tag(method_name)
      column = object.class.columns_hash[method_name.to_s]
      %Q@
        <label for="#{object_name}_#{method_name}">
          #{column ? column.human_name : method_name.to_s.humanize}
          #{error_messages(method_name)}
        </label>
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