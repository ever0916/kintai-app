class Kintai < ActiveRecord::Base
  validates_presence_of :t_syukkin,:message => "出勤レコードの値が空です。出禁←"
  validate :kintai_check, :unless => Proc.new { self.t_syukkin.nil? || self.t_taikin.nil? }
  validate :time_check

  belongs_to :user

  #出勤時間と退勤時間が逆転していないかを検証する。
  #退勤時間がnilの場合は検証しない
  def kintai_check
    p self.t_taikin.to_s + "    " + self.t_syukkin.to_s
    errors.add(:empty_attr,"【出勤時間】と【退勤時間】が逆転しました。タイムリープしてしまった可能性がありますね。") if self.t_taikin < self.t_syukkin
  end

  #出勤時刻、退勤時刻が現在時刻を超えていないか検証する。
  def time_check
    errors.add(:t_syukkin,"を現在時刻より後に設定することは出来ません。") if self.t_syukkin > Time.now unless self.t_syukkin.nil?
    errors.add(:t_taikin ,"を現在時刻より後に設定することは出来ません。") if self.t_taikin  > Time.now unless self.t_taikin.nil?
  end

end

