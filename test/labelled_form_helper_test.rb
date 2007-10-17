require 'test/unit'

require 'rubygems'
require 'flexmock/test_unit'

require 'active_support'
require 'action_view/helpers/tag_helper'
require 'action_view/helpers/form_helper'
require 'action_view/helpers/form_tag_helper'
require 'action_controller/assertions/selector_assertions'

require File.dirname(__FILE__) + '/../lib/labelled_form_helper'

class LabelledFormHelperTest < Test::Unit::TestCase
  include LabelledFormHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::FormTagHelper
  include ActionController::Assertions::SelectorAssertions
  
  def setup
    @person = flexmock(:name => 'Tester')
    
    @error_on_name = flexmock do |mock|
      mock.should_receive(:on).with(:base).and_return(nil)
      mock.should_receive(:on).with(:name).and_return(['name error'])
    end
    @person_with_error_on_name = flexmock(:name => '', :errors => @error_on_name)
    
    @error_on_base = flexmock do |mock|
      mock.should_receive(:on).with(:base).and_return(['base error'])
      mock.should_receive(:on).with(:name).and_return(nil)
    end
    @person_with_error_on_base = flexmock(:name => '', :errors => @error_on_base)

    @person_with_human_field_name = flexmock(
      :name => '', :class => flexmock(
        :columns_hash => {"name" => flexmock(:human_name => 'human name')}
      )
    )
    
    @address = flexmock(:city => 'Amsterdam')
    @person_with_address = flexmock(:name => 'Tester', :address => @address)
    
    @erbout = ''
  end
  
  def test_should_render_empty_form
    labelled_form_for(:person) {}
    assert_equal %q{<form method="post"></form>}, @erbout
  end
  
  def test_should_render_form_with_method_get
    labelled_form_for(:person, :html => {:method => 'get'}) {}
    assert_equal %q{<form method="get"></form>}, @erbout
  end
  
  def test_should_render_form_with_url
    labelled_form_for(:person, :url => 'test_url') {}
    assert_select 'form[method="post"][action="test_url"]'
  end
  
  def test_should_render_form_with_name_field
    labelled_form_for(:person) do |f|
      @erbout << f.text_field(:name)
    end
    
    assert_select 'label[for="person_name"]'
    assert_select 'input#person_name[type="text"]'
    
    element = css_select('#person_name')
    assert_equal 'person[name]', element.first["name"]
    assert_equal @person.name, element.first["value"]
  end
  
  def test_should_not_render_label_with_false
    labelled_form_for(:person) do |f|
      @erbout << f.text_field(:name, :label => false)
    end
    
    assert_select 'label[for="person_name"]', 0
  end
  
  def test_should_not_render_label_with_no_label
    labelled_form_for(:person) do |f|
      @erbout << f.text_field(:name, :no_label => true)
    end
    
    assert_select 'label[for="person_name"]', 0
  end
  
  def test_should_not_render_label_with_no_label_for
    labelled_form_for(:person, :no_label_for => :text_field) do |f|
      @erbout << f.text_field(:name)
    end
    
    assert_select 'label[for="person_name"]', 0
  end
  
  def test_should_render_alternative_label
    labelled_form_for(:person) do |f|
      @erbout << f.text_field(:name, :label => 'alt')
    end
    
    assert_select 'label[for="person_name"]', 'alt'
  end
  
  def test_should_render_class_for_field
    labelled_form_for(:person) do |f|
      @erbout << f.text_field(:name, :class => 'required')
    end
    
    assert_select 'input#person_name.required'
  end
  
  def test_should_render_input_submit_with_class_submit
    labelled_form_for(:person) do |f|
      @erbout << f.submit('save', :class => 'button')
    end
    
    assert_select 'input[type="submit"].submit.button'
    assert_equal 'save', css_select('input[type="submit"].submit.button').first["value"]
  end
  
  def test_should_render_button_of_type_submit
    labelled_form_for(:person) do |f|
      @erbout << f.submit('save', :type => :button, :class => 'save-button')
    end
    
    assert_select 'button[type="submit"].submit.save-button', 'save'
  end
  
  def test_should_render_label
    labelled_form_for(:person) do |f|
      @erbout << f.label(:name) 
    end
    
    assert_select 'label[for="person_name"] span.field_name', 'Name'
  end
  
  def test_should_render_label_with_value
    labelled_form_for(:person) do |f|
      @erbout << f.label(:name, :label_value => 'test label')
    end
    
    assert_select 'label[for="person_name"] span.field_name', 'test label'
  end
  
  def test_should_render_label_with_human_name
    labelled_form_for(:person, @person_with_human_field_name) do |f|
      @erbout << f.label(:name)
    end

    assert_select 'label[for="person_name"] span.field_name', 'human name'
  end
  
  def test_should_not_render_error_message
    labelled_form_for(:person) do |f|
      @erbout << f.text_field(:name)
    end

    assert_select 'label[for="person_name"] .error_message', 0
  end
  
  def test_should_render_error_message_for_name
    labelled_form_for(:person, @person_with_error_on_name) do |f|
      @erbout << f.text_field(:name)
    end

    assert_select 'label[for="person_name"] .error_message', 1, 'name error'
  end
  
  def test_should_render_error_message_for_base
    labelled_form_for(:person, @person_with_error_on_base) do |f|
      @erbout << f.text_field(:name)
    end

    assert_select '.error_message', 1, 'base error'
  end

  def test_should_render_associate_fields
    labelled_form_for(:person, @person_with_address) do |f|
      f.with_association(:address) do |a|
        @erbout << a.text_field(:city)
      end
    end
    
    assert_select 'label[for="address_city"]', 1
    assert_equal @address.city, css_select('input[type="text"]').first['value']
  end
  
  def test_should_render_object_fields
    labelled_form_for(:person, @person_with_address) do |f|
      f.with_object(:address) do |a|
        @erbout << a.text_field(:city)
      end
    end

    assert_select 'label[for="address_city"]', 1
    assert_equal @address.city, css_select('input[type="text"]').first['value']
  end
    
private
  def url_for(arg)
    arg.empty? ? nil : arg
  end
  
  def concat(text, binding)
    @erbout << text
  end
  
  def response_from_page_or_rjs
    HTML::Document.new(@erbout).root
  end
end
