class Kintai < ActiveRecord::Base
  validates_presence_of :t_syukkin,:message => "出勤レコードの値が空です。出禁←"
  validate :kintai_check, :unless => Proc.new { self.t_syukkin.nil? || self.t_taikin.nil? }
  validate :time_check

  belongs_to :user

  #出勤時間と退勤時間が逆転していないかを検証する。
  #退勤時間がnilの場合は検証しない
  def kintai_check
    errors.add(:t_taikin,"出勤時間と退勤時間が逆転しました。タイムリープしてしまった可能性がありますね。") if self.t_taikin < self.t_syukkin
  end

  #出勤時刻、退勤時刻が現在時刻を超えていないか検証する。
  def time_check
    errors.add(:t_syukkin,"出勤時間を現在時刻より後に設定することは出来ません。") if self.t_syukkin > Time.now unless self.t_syukkin.nil?
    errors.add(:t_taikin ,"退勤時間を現在時刻より後に設定することは出来ません。") if self.t_taikin  > Time.now unless self.t_taikin.nil?
  end

  def self.export(target_date_min = nil,target_date_max = nil)
    require 'spreadsheet'

    if target_date_min == nil || target_date_max == nil
       return
    end

    @users   = User.all.order("id ASC")
    @kintais = Kintai.all

    #テンプレートファイルの生成
    book = Spreadsheet::Workbook.new
    @users.each do |user|
      #シートの生成。名前を付ける
      sheet = book.create_worksheet(:name => user.name)

      #指定した月の勤怠レコードを@kintaisに取得。
      @chk = @user_kintais = @kintais.where(:t_syukkin => target_date_min..target_date_max ).where(:user_id => user.id).order("t_syukkin ASC")
      
      sheet[0,0] = user.name
      sheet[0,1] = target_date_max.strftime("%Y年%m月分")
      sheet[2,0] = "出勤時刻"
      sheet[2,1] = "退勤時刻"
      sheet[2,2] = "勤務時間"

      for i in 0..2 do
        sheet.column(i).width = 15 # カラム幅設定
      end
      sheet.column(3).width = 100

      goukei = 0
      f_err  = false
      @user_kintais.each_with_index do |user_kintai,count|
        #値の設定
        sheet[count+3,0] = user_kintai.t_syukkin.strftime("%d日 %H:%M")
        if user_kintai.t_taikin == nil
          f_err = true
          for i in 0..3 do
            sheet.row(count+3).set_format(i,Spreadsheet::Format.new(:pattern => 1,:pattern_fg_color => :red))
          end
          sheet[count+3,3] = "退勤が押されていないか、未だに働き続けている可能性があります。死にます。"
          next
        end

        sheet[count+3,1] = user_kintai.t_taikin.strftime("%d日 %H:%M")

        rz = (user_kintai.t_taikin - user_kintai.t_syukkin).divmod(3600)
        sheet[count+3,2] = "#{rz[0]}時間#{rz[1].to_i / 60}分"

        @chk.each_with_index do |chk,cnt|

          if chk.t_taikin == nil || cnt == count
            next
          end
          if (user_kintai.t_syukkin > chk.t_syukkin && user_kintai.t_syukkin < chk.t_taikin) || (user_kintai.t_taikin > chk.t_syukkin && user_kintai.t_taikin < chk.t_taikin) 
            f_err = true
            for i in 0..3 do
              sheet.row(count+3).set_format(i,Spreadsheet::Format.new(:pattern => 1,:pattern_fg_color => :red))
              sheet.row(cnt+3).set_format(i,Spreadsheet::Format.new(:pattern => 1,:pattern_fg_color => :red))
            end
            sheet[count+3,3] = "他のレコードと勤怠時間が被っています。本人が分裂した可能性があります。"
            sheet[cnt+3,3] = "他のレコードと勤怠時間が被っています。本人が分裂した可能性があります。"
          end
        end

        goukei += user_kintai.t_taikin - user_kintai.t_syukkin;
      end
      if f_err == false
        rz = goukei.divmod(3600)
        sheet[@user_kintais.length+3,2] = "計#{rz[0]}時間#{rz[1].to_i / 60}分"
      else
        sheet.merge_cells(@user_kintais.length+5,0,@user_kintais.length+5,3)#セルの結合。引き数はstart_row,start_col,end_row,end_col
        sheet[@user_kintais.length+5,0] = "※背景が赤いレコードは誤りがあるか、退勤時刻が入力されていません。"
      end
    end

    #ダウンロードする為にtempファイルを作成
    tmpfile = Tempfile.new ["test", ".xls"]
    book.write tmpfile

    tmpfile.open # reopen
    
    return tmpfile
  end
end

