# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
KintaiApp::Application.initialize!

#validationでフォームのスタイルが崩れるのを防ぐ
ActionView::Base.field_error_proc = Proc.new {|html_tag, instance|  %(<span class="fieldWithErrors">#{html_tag}</span>)}
