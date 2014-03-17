class User < ActiveRecord::Base
  has_many :kintais
  validates_presence_of :name,:message => "名前を入力して下さい。" # 空を許可しない
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
end
