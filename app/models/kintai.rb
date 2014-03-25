class Kintai < ActiveRecord::Base
  validates_presence_of :t_syukkin,:message => "出勤レコードの値が空です。出禁←"
  validate :kintai_check, :unless => Proc.new { self.t_syukkin.nil? || self.t_taikin.nil? }
  validate :time_check

  belongs_to :user

  #出勤時間と退勤時間が逆転していないかを検証する。
  #退勤時間がnilの場合は検証しない
  def kintai_check
    errors.add(:empty_attr,"【出勤時間】と【退勤時間】が逆転しました。タイムリープしてしまった可能性がありますね。") if self.t_taikin < self.t_syukkin
  end

  #出勤時刻、退勤時刻が現在時刻を超えていないか検証する。
  def time_check
    errors.add(:t_syukkin,"を現在時刻より後に設定することは出来ません。") if self.t_syukkin > Time.now unless self.t_syukkin.nil?
    errors.add(:t_taikin ,"を現在時刻より後に設定することは出来ません。") if self.t_taikin  > Time.now unless self.t_taikin.nil?
  end

  def self.export(target_date_min = nil,target_date_max = nil)
    #テンプレートファイルの生成
    @book = Spreadsheet::Workbook.new
    User.all.order("id ASC").each do |user|
      #シートの生成。名前を付ける
      @sheet = self.create_sheet_tmp user.name,target_date_max

      #指定した月の勤怠レコードを@kintaisに取得。
      @user_kintais = Kintai.all.where(:t_syukkin => target_date_min..target_date_max ).where(:user_id => user.id).order("t_syukkin ASC")

      goukei = 0
      @f_err  = false
      @user_kintais.each_with_index do |user_kintai,count|
        #値の設定
        @sheet[count+3,0] = user_kintai.t_syukkin.strftime("%m月%d日 %H:%M")
        if user_kintai.t_taikin == nil
          self.write_err_to_sheet count+3,"退勤が押されていないか、未だに働き続けている可能性があります。死にます。"
          next
        else
          @sheet[count+3,1] = user_kintai.t_taikin.strftime("%m月%d日 %H:%M")
        end
        self.write_time_hm_to_sheet(user_kintai.t_taikin - user_kintai.t_syukkin - 3600,count+3,2)

        chk = @user_kintais.where.not(:id => user_kintai.id ).where.not(:t_taikin => nil)
        chk.each_with_index do |chk,cnt|
          if (user_kintai.t_syukkin > chk.t_syukkin && user_kintai.t_syukkin < chk.t_taikin) || (user_kintai.t_taikin > chk.t_syukkin && user_kintai.t_taikin < chk.t_taikin) 
            self.write_err_to_sheet count+3,"他のレコードと勤怠時間が被っています。本人が分裂した可能性があります。"
            self.write_err_to_sheet cnt+3  ,"他のレコードと勤怠時間が被っています。本人が分裂した可能性があります。"
          end
        end

        goukei += user_kintai.t_taikin - user_kintai.t_syukkin - 3600
      end
      if @f_err == false
        self.write_time_hm_to_sheet(goukei,@user_kintais.length+3,2)
      else
        @sheet.merge_cells(@user_kintais.length+5,0,@user_kintais.length+5,3)#セルの結合。引き数はstart_row,start_col,end_row,end_col
        @sheet[@user_kintais.length+5,0] = "※背景が赤いレコードは誤りがあるか、退勤時刻が入力されていません。"
      end
    end

    #ダウンロードする為にtempファイルを作成
    tmpfile = Tempfile.new ["test", ".xls"]
    @book.write tmpfile

    tmpfile.open # reopen

    return tmpfile
  end

  #シートのテンプレートを設定
  def self.create_sheet_tmp(user_name,date)
    sheet = @book.create_worksheet(:name => user_name)

    sheet[0,0] = user_name
    sheet[0,1] = date.strftime("%Y年%m月分")
    sheet[2,0] = "出勤時刻"
    sheet[2,1] = "退勤時刻"
    sheet[2,2] = "勤務時間"

    for i in 0..2 do
      sheet.column(i).width = 15 # カラム幅設定
    end
    sheet.column(3).width = 100

    return sheet
  end

  #エクセルシートの対象行に時間を何時間、何分の形式で出力する。
  #sec=秒数,h=行,w=列
  def self.write_time_hm_to_sheet(sec,h,w)
    rz = sec.divmod(3600)
    @sheet[h,w] = "#{rz[0]}時間#{rz[1].to_i / 60}分"
  end

  #エクセルシートの対象行の背景を赤くし、その行の３列目にerr_msgを出力する。
  #@f_errがtrueになる。
  def self.write_err_to_sheet(count,err_msg)
    @f_err = true
    for i in 0..3 do
      @sheet.row(count).set_format(i,Spreadsheet::Format.new(:pattern => 1,:pattern_fg_color => :red))
    end
    @sheet[count,3] = err_msg
  end
end

