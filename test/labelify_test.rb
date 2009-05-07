require 'test/unit'

require 'rubygems'
require 'flexmock/test_unit'

require 'active_support'
require 'action_view/helpers/tag_helper'
require 'action_view/helpers/form_tag_helper'
require 'action_view/helpers/form_options_helper'
require 'action_view/helpers/active_record_helper'
require 'action_controller'
require 'action_controller/assertions/selector_assertions'

require File.dirname(__FILE__) + '/../lib/labelify'

class LabelifyTest < Test::Unit::TestCase
  include Labelify
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::FormOptionsHelper
  include ActionView::Helpers::FormTagHelper
  include ActionView::Helpers::ActiveRecordHelper
  include ActionController::Assertions::SelectorAssertions

  def setup
    @person = flexmock('person', :name => 'Tester', :password => 'Secret', :active => true, :to_param => 1)

    @error_on_name = flexmock do |mock|
      mock.should_receive(:on).with(:base).and_return(nil)
      mock.should_receive(:on).with("name").and_return(['name error'])
      mock.should_receive(:count).and_return(1)
      mock.should_receive(:full_messages).and_return("full messages")
    end
    @person_with_error_on_name = flexmock('person_with_error_on_name', :name => '', :errors => @error_on_name)

    @multiple_errors_on_name_and_base = flexmock do |mock|
      mock.should_receive(:on).with(:base).and_return(['base error1', 'base error2'])
      mock.should_receive(:on).with("name").and_return(['name error1', 'name error2'])
    end
    @person_with_multiple_errors_on_name_and_base = flexmock('person_with_multiple_errors_on_name_and_base', :name => '', :errors => @multiple_errors_on_name_and_base)

    @error_on_base = flexmock do |mock|
      mock.should_receive(:on).with(:base).and_return(['base error'])
      mock.should_receive(:on).with("name").and_return(nil)
    end
    @person_with_error_on_base = flexmock('person_with_error_on_base', :name => '', :errors => @error_on_base)

    @person_with_human_field_name = flexmock('person_with_human_field_name',
      :name => '', :class => flexmock(:human_attribute_name => 'human name')
    )

    @address = flexmock('address', :city => 'Amsterdam')
    @person_with_address = flexmock('person_with_address', :name => 'Tester', :address => @address)

    @address_with_error_on_name = flexmock('address_with_error_on_name', :name => '', :errors => @error_on_name)

    @erbout = ''
  end

  def test_labelled_form_for_should_render_empty_form
    labelled_form_for(:person) {}
    assert_equal %q{<form method="post"></form>}, @erbout
  end

  def test_labelled_form_for_should_render_form_with_method_get
    labelled_form_for(:person, :html => {:method => 'get'}) {}
    assert_equal %q{<form method="get"></form>}, @erbout
  end

  def test_labelled_form_for_should_render_form_with_url
    labelled_form_for(:person, :url => 'test_url') {}
    assert_select 'form[method="post"][action="test_url"]'
  end

  def test_labelled_form_for_should_render_form_with_name_field
    labelled_form_for(:person) do |f|
      @erbout << f.text_field(:name)
    end

    assert_select 'label[for="person_name"]'
    assert_select 'input#person_name[type="text"]'

    element = css_select('#person_name')
    assert_equal 'person[name]', element.first["name"]
    assert_equal @person.name, element.first["value"]
  end

  def test_labelled_form_for_should_render_form_with_select_field
    labelled_form_for(:person) do |f|
      @erbout << f.select(:name, [['Bob', 'bob']], { :prompt => "Please choose a name" })
    end
    assert_select 'label[for="person_name"]', 1
    assert_select 'select#person_name', 1
  end

  def test_labelled_form_for_should_not_render_label_and_div_for_hidden_field
    labelled_form_for(:person) do |f|
      @erbout << f.hidden_field(:name)
    end

    assert_select 'div.field', 0
    assert_select 'label[for="person_name"]', 0
  end

  def test_labelled_form_for_should_not_render_extra_label_for_label_method
    labelled_form_for(:person) do |f|
      @erbout << f.label(:name)
    end

    assert_select 'label[for="person_name"]', 1
  end

  def test_labelled_form_for_should_not_render_label_with_false
    labelled_form_for(:person) do |f|
      @erbout << f.text_field(:name, :label => false)
    end

    assert_select 'label[for="person_name"]', 0
  end

  def test_labelled_form_for_should_not_render_label_with_no_label
    labelled_form_for(:person) do |f|
      @erbout << f.text_field(:name, :no_label => true)
    end

    assert_select 'label[for="person_name"]', 0
  end

  def test_labelled_form_for_should_not_render_label_with_single_no_label_for
    labelled_form_for(:person, :no_label_for => :text_field) do |f|
      @erbout << f.text_field(:name)
      @erbout << f.password_field(:password)
    end

    assert_select 'label', 1
  end

  def test_labelled_form_for_should_not_render_label_with_multi_no_label_for
    labelled_form_for(:person, :no_label_for => [:text_field, :password_field]) do |f|
      @erbout << f.text_field(:name)
      @erbout << f.password_field(:password)
      @erbout << f.check_box(:active)
    end

    assert_select 'label', 1
  end

  def test_labelled_form_for_should_render_alternative_label
    labelled_form_for(:person) do |f|
      @erbout << f.text_field(:name, :label => 'alt')
    end

    assert_select 'label[for="person_name"]', 'alt'
  end

  def test_labelled_form_for_should_render_class_for_field
    labelled_form_for(:person) do |f|
      @erbout << f.text_field(:name, :class => 'required')
    end

    assert_select 'input#person_name.required'
  end

  def test_labelled_form_for_should_render_input_submit_with_class_submit
    labelled_form_for(:person) do |f|
      @erbout << f.submit('save', :class => 'button')
    end

    assert_select 'input[type="submit"].submit.button'
    assert_equal 'save', css_select('input[type="submit"].submit.button').first["value"]
  end

  def test_labelled_form_for_should_render_button_of_type_submit
    labelled_form_for(:person) do |f|
      @erbout << f.submit('save', :type => :button, :class => 'save-button')
    end

    assert_select 'button[type="submit"].submit.save-button', 'save'
  end

  def test_labelled_form_for_should_render_label
    labelled_form_for(:person) do |f|
      @erbout << f.label(:name)
    end

    assert_select 'label[for="person_name"] span.field_name', 'Name'
  end

  def test_labelled_form_for_should_render_label_with_value
    labelled_form_for(:person) do |f|
      @erbout << f.label(:name, :label_value => 'test label')
    end

    assert_select 'label[for="person_name"] span.field_name', 'test label'
  end

  def test_labelled_form_for_should_render_label_with_human_name
    labelled_form_for(:person, @person_with_human_field_name) do |f|
      @erbout << f.label(:name)
    end

    assert_select 'label[for="person_name"] span.field_name', 'human name'
  end

  def test_labelled_form_for_should_not_render_error_message
    labelled_form_for(:person) do |f|
      @erbout << f.text_field(:name)
    end

    assert_select 'label[for="person_name"] .error_message', 0
  end

  def test_labelled_form_for_should_render_error_message_for_name
    labelled_form_for(:person, @person_with_error_on_name) do |f|
      @erbout << f.text_field(:name)
    end

    assert_select 'label[for="person_name"] .error_message', 'name error'
  end

  def test_labelled_form_for_should_render_multiple_errors_messages
    labelled_form_for(:person, @person_with_multiple_errors_on_name_and_base) do |f|
      @erbout << f.text_field(:name)
    end

    assert_select '.error_message', 'base error1 and base error2'
    assert_select 'label[for="person_name"] .error_message', 'name error1 and name error2'
  end

  def test_labelled_form_for_should_render_error_message_for_base
    labelled_form_for(:person_with_error_on_base) do |f|
      @erbout << f.text_field(:name)
    end

    assert_select '.error_message', 'base error'
  end

  def test_labelled_form_for_should_render_general_error_messages
    labelled_form_for(:person, @person_with_error_on_name) do |f|
      @erbout << f.error_messages
    end

    assert_select '.errorExplanation h2 + p + ul li', :text => 'full messages'
  end

  def test_labelled_form_for_should_render_general_error_messages_customized
    labelled_form_for(:person, @person_with_error_on_name) do |f|
      @erbout << f.error_messages(:header_message => "header", :message => "message")
    end

    assert_select '.errorExplanation h2', :text => 'header'
    assert_select '.errorExplanation h2 + p', :text => 'message'
    assert_select '.errorExplanation h2 + p + ul li', :text => 'full messages'
  end

  def test_labelled_form_for_should_render_associate_fields
    labelled_form_for(:person, @person_with_address) do |f|
      f.with_association(:address) do |a|
        @erbout << a.text_field(:city)
      end
    end

    assert_select 'label[for="address_city"]', 1
    assert_equal @address.city, css_select('input[type="text"]').first['value']
  end

  def test_labelled_form_for_should_render_object_fields
    labelled_form_for(:person, @person_with_address) do |f|
      f.with_object(:address) do |a|
        @erbout << a.text_field(:city)
      end
    end

    assert_select 'label[for="address_city"]', 1
    assert_equal @address.city, css_select('input[type="text"]').first['value']
  end

  def test_labelled_form_for_should_allow_helpers_with_block
    labelled_form_for(:person, @person) do |f|
      @erbout << f.make_span_for_block(:name) do
        'body'
      end
    end

    assert_select 'form span.span_for_block', 'body'
  end

  def test_labelled_form_for_should_allow_my_text_field_helper
    labelled_form_for(:person) do |f|
      @erbout << f.my_text_field(:name)
    end

    assert_select 'label[for="person_name"]', 1
    assert_select 'input[type="my-text"]', 1
    assert_equal @person.name, css_select('input').first['value']
  end

  def test_labelled_form_for_should_be_able_to_use_as_default_form_builder
    before = ActionView::Base.default_form_builder
    ActionView::Base.default_form_builder = Labelify::FormBuilder

    begin
      form_for(:person) do |f|
        @erbout << f.text_field(:name)
      end

      assert_select 'label[for="person_name"]', 1
      assert_select 'input#person_name', 1
    end

    ActionView::Base.default_form_builder = before
  end

  def test_labelled_fields_for_should_render_nothing
    labelled_fields_for(:person) {}
    assert_equal '', @erbout
  end

  def test_labelled_fields_for_should_render_text_field
    labelled_fields_for(:person) do |f|
      @erbout << f.text_field(:name)
    end
    assert_select 'label[for="person_name"]', 1
    assert_select 'input#person_name', 1
  end

  def test_labelled_fields_should_allow_indexed_fields
    labelled_fields_for('person[]') do |f|
      @erbout << f.text_field(:name)
    end
    assert_select 'label[for="person_1_name"]', 1
    assert_select 'input#person_1_name', 1
  end

  def test_labelled_fields_should_allow_indexed_fields_with_given_object
    labelled_fields_for('p[]', @person) do |f|
      @erbout << f.text_field(:name)
    end
    assert_select 'label[for="p_1_name"]', 1
    assert_select 'input#p_1_name', 1
  end

  def test_label_method_should_fallback_to_rails_implementation
    labelled_fields_for(:person) do |f|
      @erbout << f.label(:name, 'Naam')
    end

    assert_select 'label[for="person_name"] span.field_name', 'Naam'
  end

  def test_error_placement_should_put_error_on_proper_location
    {
      :after_field  => /<input.*<span.*error_message/,
      :before_field => /<span.*error_message.*<input/,
      :after_label  => /<label.*<span.*error_message/,
      :before_label => /<span.*error_message.*<label/,
    }.each do |placement,pattern|
      @erbout = ''
      labelled_form_for(:person, @person_with_error_on_name, :error_placement => placement) do |f|
        @erbout << f.text_field(:name)
      end
      assert_match pattern, @erbout
      assert_select 'label span.error_message', false

      @erbout = ''
      labelled_form_for(:person, @person_with_error_on_name) do |f|
        @erbout << f.text_field(:name, :error_placement => placement)
      end
      assert_match pattern, @erbout
      assert_select 'label span.error_message', false
      assert_select '[error_placement]', false
    end
  end

  def test_labelled_fields_for_inside_labelled_form_for_should_render_text_field
    labelled_form_for(:person) do |f|
      f.labelled_fields_for(:address) do |address|
        @erbout << address.text_field(:city)
      end
    end
    assert_select 'label[for="person_address_city"]', 1
    assert_select 'input#person_address_city', 1
  end

  def test_labelled_fields_for_inside_labelled_form_for_should_allow_indexed_fields
    labelled_form_for(:person) do |f|
      f.labelled_fields_for(:address, {:index => '1'}) do |address|
        @erbout << address.text_field(:city)
      end
    end
    assert_select 'label[for="person_address_1_city"]', 1
    assert_select 'input#person_address_1_city', 1
  end

  def test_labelled_form_for_should_render_error_message_for_base
    labelled_form_for(:person_with_error_on_name) do |f|
      @erbout << f.text_field(:name)
      f.labelled_fields_for(:address_with_error_on_name) do |address|
        @erbout << address.text_field(:name)
      end
    end

    assert_select 'label[for="person_with_error_on_name_name"] .error_message', 'name error'
    assert_select 'label[for="person_with_error_on_name_address_with_error_on_name_name"] .error_message', 'name error'
  end

  def test_base_errors_messages
    labelled_form_for(:person_with_error_on_base) do |f|
      @erbout << f.base_error_messages
    end

    assert_select 'span[class="error_message"]', 'base error'
  end

  def test_label_placement_should_put_label_on_proper_location
    {
      :before_field => /<label.*<input/,
      :after_field  => /<input.*<label/
    }.each do |label_placement,pattern|
      @erbout = ''
      labelled_form_for(:person, @person) do |f|
        @erbout << f.text_field(:name, :label_placement => label_placement)
      end
      assert_match pattern, @erbout
    end
  end

private
  def make_span_for_block(object, name, options = {})
    content_tag(:span, yield, :class => 'span_for_block')
  end

  def my_text_field(object, method, options)
    tag(:input, :value => options[:object].send(method), :type => 'my-text')
  end

  def url_for(arg)
    arg.empty? ? nil : arg
  end

  def concat(text, *binding)
    @erbout << text
  end

  def response_from_page_or_rjs
    HTML::Document.new(@erbout).root
  end

  def protect_against_forgery?
    false
  end
end
