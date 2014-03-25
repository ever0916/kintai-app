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

  #対象のuser_idの社員の、その月の勤怠情報にエラーが無いか調べる。[勤怠情報+1]分の長さの配列を返し、エラーがある場合はエラーメッセージが格納される。
  #最後の行には合計勤務時間が秒数で格納される。
  def self.chk_export(user_id,target_date_min,target_date_max)
    #指定した月の勤怠レコードを@user_kintaisに取得。
    @user_kintais = Kintai.all.where(:t_syukkin => target_date_min..target_date_max ).where(:user_id => user_id).order("t_syukkin ASC")

    ret_ary = Array.new(@user_kintais.count + 1)

    goukei = 0
    @user_kintais.each_with_index do |user_kintai,count|
      if user_kintai.t_taikin == nil
        ret_ary[count] = "退勤が押されていないか、未だに働き続けている可能性があります。死にます。"
        next
      end

      chk = @user_kintais.where.not(:id => user_kintai.id ).where.not(:t_taikin => "")
      chk.each_with_index do |chk,cnt|
        if (user_kintai.t_syukkin > chk.t_syukkin && user_kintai.t_syukkin < chk.t_taikin) || (user_kintai.t_taikin > chk.t_syukkin && user_kintai.t_taikin < chk.t_taikin) 
          ret_ary[cnt]   = "他のレコードと勤怠時間が被っています。本人が分裂した可能性があります。"
          ret_ary[count] = "他のレコードと勤怠時間が被っています。本人が分裂した可能性があります。"
        end
      end

      goukei += (user_kintai.t_taikin - user_kintai.t_syukkin)
    end

    ret_ary[ret_ary.count - 1] = goukei

    return ret_ary
  end

end

