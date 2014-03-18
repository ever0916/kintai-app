class ApplicationController < ActionController::Base
  #ヘルパーメソッドの宣言
  helper_method :get_remainder_users #残りの登録可能ユーザー数を返す
  helper_method :get_now_path #現在のパスを返す
  
  before_filter :authenticate_user!
  before_filter :configure_permitted_parameters, if: :devise_controller?
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  # 現在のパスを返す
  def get_now_path
    request.fullpath
  end

  protected
    def configure_permitted_parameters
      devise_parameter_sanitizer.for(:sign_up) << :name
    end
end
