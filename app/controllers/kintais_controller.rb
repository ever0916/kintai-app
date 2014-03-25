class KintaisController < ApplicationController
  before_action :set_kintai , only: [:show ,:update, :taikin_update, :edit  , :destroy]
  before_action :set_kintais, only: [:index,:edit  , :create                , :destroy, :get_my_record]
  before_action :set_date   , only: [:index,:export,:setting]
  before_action only: [:create] do |c|
    chk_f_state(true,"不正なアクセスです。(勤務中に出勤しようとしました。出禁←)")
  end
  before_action only: [:taikin_update] do |c|
    chk_f_state(false,"不正なアクセスです。(退勤中に退勤しようとしました。出禁←)")
  end
  before_action :chk_user   , only: [:show ,:edit  ]
  before_action :chk_admin  , only: [:user_destroy,:db_correction]
  respond_to :html, :json, :xls

  # GET /kintais
  # GET /kintais.json
  def index
    @kintai = @kintais.last if current_user.f_state == true

    #指定した月の勤怠レコードを@kintaisに取得。
    @kintais = @kintais.reorder(nil).where(:t_syukkin => @target_date_min..@target_date_max ).order("t_syukkin ASC")#reorder(nil)で直前のorder byを無効に出来るっぽい
  end

  def setting
    @f_db_err = db_check #データベースの修正が必要ならtrueが入る
  end

  def export
    #エクセルbookの作成
    @book = Spreadsheet::Workbook.new
    
    User.all.order("id ASC").each do |user|
      #エクセルシート空テンプレート作成
      @sheet = create_tmp_sheet(user.name)

      #指定した月の勤怠レコードを@kintaisに取得。
      @user_kintais = Kintai.all.where(:t_syukkin => @target_date_min..@target_date_max ).where(:user_id => user.id).order("t_syukkin ASC")

      @user_kintais.each_with_index do |user_kintai,count|
        #値の設定
        write_date_to_sheet(user_kintai.t_syukkin,count+3,0)
        write_date_to_sheet(user_kintai.t_taikin ,count+3,1)
        write_time_hm_sa_to_sheet(user_kintai.t_taikin,user_kintai.t_syukkin,count+3,2)
      end

      #エラーと合計勤務時間の出力
      ary = @user_kintais.chk_export(user.id,@target_date_min,@target_date_max)
      ary.each_with_index do |msg,count|
        if count + 1 == ary.count
          #合計時間の出力
          write_time_hm_to_sheet(msg,@user_kintais.length+3,2)
        else
          #エラーの出力
          write_err_to_sheet(count + 3,msg)
        end
      end
    end

    #ダウンロードする為にtempファイルを作成
    tmpfile = Tempfile.new ["test", ".xls"]
    @book.write tmpfile

    tmpfile.open # reopen

    respond_to do |format|
      format.xls { send_data tmpfile.read, filename: "future-lab_kintais#{Time.now.strftime('%Y_%m_%d_%H_%M_%S')}.xls"}
    end

    tmpfile.close(true)
  end

  # GET /kintais/1
  # GET /kintais/1.json
  def show
  end

  # GET /kintais/new
  def new
    @kintai = Kintai.new
  end

  # GET /kintais/1/edit
  def edit
  end

  # POST /kintais
  # POST /kintais.json
  def create
    ActiveRecord::Base.transaction do
      #レコード登録数が最大数を超える場合、一番出勤時間が古く、idが一番若いレコードを削除する。
      @kintais.reorder(nil).order("t_syukkin ASC,id ASC").first.destroy if @kintais.count >= G_MAX_USER_KINTAIS
      Kintai.new(:user_id => current_user.id,:t_syukkin => Time.now).save!
      current_user.update_attributes!(:f_state => !current_user.f_state ) 
    end
    
    flash[:notice] = "おはようございます。正常に記録されました。"
    respond_with @kintai,:location => kintais_url
  end
  # PATCH/PUT /kintais/1
  # PATCH/PUT /kintais/1.json
  def update
    @kintai.update_attributes!(kintai_params)
    flash[:notice] = "勤怠時間を修正しました。"
    respond_with @kintai,:location => kintais_url
  end

  def taikin_update
    ActiveRecord::Base.transaction do
      @kintai.update_attributes!(:t_taikin => Time.now)
      current_user.update_attributes!(:f_state => !current_user.f_state )
    end
    flash[:notice] = "お疲れ様です。正常に登録されました。"
    respond_with @kintai,:location => kintais_url
  end

  # DELETE /kintais/1
  # DELETE /kintais/1.json
  def destroy
    ActiveRecord::Base.transaction do
      #最後のレコードを削除する場合、ユーザーが出勤中であれば勤務外に戻す。
      current_user.update_attributes!(:f_state => false ) if @kintai.id == @kintais.last.id if current_user.f_state == true
      @kintai.destroy
      flash[:notice] = "削除しました。"
    end

    respond_with @kintai,:location => kintais_url
  end

  #対象のユーザーを削除する
  def user_destroy
    ActiveRecord::Base.transaction do
      user = User.find_by_name(select_params[:name])
      Kintai.where(:user_id => user.id).destroy_all
      user.destroy
    end

    redirect_to setting_kintais_path, :notice => "削除しました。"
  end

  #各テーブルに登録可能最大数以上のデータが登録されてしまっている場合、ユーザーテーブルなら新しいユーザーから、
  #勤怠テーブルならそのユーザーの古い勤怠情報から削除する。
  #adminのみ実行できる。
  def db_correction
    ActiveRecord::Base.transaction do
      #ユーザーが最大数を超えて登録されている場合に、新しいユーザーデータから削除する。
      user_correction

      #各ユーザーの勤怠テーブルに最大数を超えて登録されている場合に、出勤日の古いレコードから削除する。
      kintai_correction

      redirect_to setting_kintais_path, :notice => "データベースを修正しました。"
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_kintai
      @kintai = Kintai.find(params[:id])
    end
    def set_kintais
      @kintais = Kintai.where(:user_id => current_user.id).order("id ASC")
    end
    def set_date
      @target_date_max = Date.new(date_params[:year].to_i,date_params[:month].to_i,G_SIMEBI+1)
      @target_date_min = @target_date_max << 1
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def kintai_params
      params.require(:kintai).permit(:user_id, :t_syukkin, :t_taikin)
    end

    def date_params
      params.fetch(:date,{:year => Time.now.year,:month => Time.now.day > G_SIMEBI ? (Time.now.month % 12) + 1 : Time.now.month }).permit(:year, :month) #fetchで、値がない場合のデフォルト値を設定。設定しないとActionController::ParameterMissingになるため。値がある場合はそちらが使用される。
    end

    def chk_f_state(flg,msg)
      return redirect_to kintais_url, :alert => msg if current_user.f_state == flg
    end

    def chk_user
      return redirect_to user_root_path, :alert => "他の社員の勤怠情報にはアクセス出来ません。" if current_user.id != @kintai.user_id
    end

    def chk_admin
      #return redirect_to setting_kintais_path, :notice => "ERROR" if current_user.f_admin == false
    end

    def select_params
      params.require(:user).permit(:name)
    end

    #ユーザーが最大数を超えて登録されている場合に、新しいユーザーデータから削除する。
    def user_correction
      return if (cnt = User.count - G_MAX_USERS) <= 0

      users = User.order("id DESC").limit(cnt)
      users.each do |user|
        Kintai.where(:user_id => user.id).destroy_all 
      end
      users.destroy_all #delete_allはlimit scopeで使用できないのでしゃあなし
    end

    #各ユーザーの勤怠テーブルに最大数を超えて登録されている場合に、出勤日の古いレコードから削除する。
    def kintai_correction
      User.all.each do |user|
        kintais = Kintai.where(:user_id => user.id).order("t_syukkin ASC,id ASC")
        cnt = kintais.count - G_MAX_USER_KINTAIS
        kintais.limit(cnt).destroy_all if cnt > 0
      end
    end

    #データベースに２重登録がされ、登録できる最大行数を超えていないかチェックする。
    #修正の必要があると判断される場合trueを返す。
    def db_check
      return false if current_user.f_admin == false

      #ユーザー数が超えていないか
      return true if User.count > G_MAX_USERS

      #各ユーザーの勤怠テーブルに最大数を超えて登録されていないか
      User.all.each do |user|
        return true if Kintai.all.where(:user_id => user.id).count - G_MAX_USER_KINTAIS > 0
      end

      return false
    end

    #エクセルシート空テンプレート作成
    def create_tmp_sheet(str_name)
      #シートの生成。名前を付ける
      sheet = @book.create_worksheet(:name => str_name)
      sheet[0,0] = str_name
      sheet[0,1] = @target_date_max.strftime("%Y年%m月分")
      sheet[2,0] = "出勤時刻"
      sheet[2,1] = "退勤時刻"
      sheet[2,2] = "勤務時間"

      for i in 0..2 do
        sheet.column(i).width = 15 # カラム幅設定
      end
      sheet.column(3).width = 100

      return sheet
    end

    #エクセルシートの対象行に勤怠時間を出力する。
    def write_date_to_sheet(date,h,w)
      return if date == nil
      @sheet[h,w] = date.strftime("%m月%d日 %H:%M")
    end

    #エクセルシートの対象行にsec1-sec2の差を何時間、何分の形式で出力する。
    #sec1=秒数,sec2,秒数,h=行,w=列
    def write_time_hm_sa_to_sheet(sec1,sec2,h,w)
      return if sec1 == nil

      rz = (sec1.to_i - sec2.to_i).divmod(3600)
      @sheet[h,w] = "#{rz[0]}時間#{rz[1].to_i / 60}分"
    end

    #エクセルシートの対象行にsecを何時間、何分の形式で出力する。
    def write_time_hm_to_sheet(sec,h,w)
      return if sec == nil

      rz = sec.divmod(3600)
      @sheet[h,w] = "#{rz[0]}時間#{rz[1].to_i / 60}分"
    end

    #エクセルシートの対象行の背景を赤くし、その行の３列目にerr_msgを出力する。
    #@f_errがtrueになる。
    def write_err_to_sheet(count,err_msg)
      return if err_msg == nil
      for i in 0..3 do
        @sheet.row(count).set_format(i,Spreadsheet::Format.new(:pattern => 1,:pattern_fg_color => :red))
      end
      @sheet[count,3] = err_msg
    end
end
