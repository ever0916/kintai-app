class User < ActiveRecord::Base
  has_many :kintais
  validates_presence_of :name,:message => "名前を入力して下さい。" # 空を許可しない
  validates_uniqueness_of :name
  validate :user_check, :on => :create 
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable #メール認証機能有効化のため追加


  #これ以上ユーザー登録できるかどうかチェック(2連続押しで切り抜けた時は知らね)
  def user_check
    errors.add(:id,"これ以上ユーザー登録出来ません。") if User.get_remainder_users <= 0
  end

  def self.get_remainder_users
    return G_MAX_USERS - User.count
  end
end
