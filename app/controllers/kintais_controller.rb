class KintaisController < ApplicationController
  before_action :set_kintai , only: [:show ,:update, :taikin_update, :edit  , :destroy]
  before_action :set_kintais, only: [:index,:edit  , :create                , :destroy, :get_my_record]
  before_action :set_date   , only: [:index,:export]
  before_action :chk_user   , only: [:show ,:edit  ]
  respond_to :html, :json, :xls

  # GET /kintais
  # GET /kintais.json
  def index
    if current_user.f_state == false
      @kintai  = Kintai.new
    else
      if @kintais != nil
        @kintai = @kintais.last
      end
    end

    #指定した月の勤怠レコードを@kintaisに取得。
    @kintais = @kintais.reorder(nil).where(:t_syukkin => @target_date_min..@target_date_max ).order("t_syukkin ASC")#reorder(nil)で直前のorder byを無効に出来るっぽい
  end

  def setting
    @target_date_min = Date.new(Time.now.year,Time.now.month,1)

    @f_db_err = false
    @f_db_err = db_check #データベースの修正が必要ならtrueが入る
  end

  def export
    tmpfile = Kintai.export(@target_date_min,@target_date_max)

    respond_to do |format|
      format.html
      #format.csv { send_data @kintais.to_csv, filename: "future-lab_kintais#{Time.now.strftime('%Y_%m_%d_%H_%M_%S')}.csv"}
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
    @kintai      = Kintai.new(kintai_params)
    @kintai_last = @kintais.last

    if @kintai_last != nil
      if current_user.f_state == true
        return redirect_to kintais_url, :alert => "不正なアクセスです。出禁←(出勤中に出勤しようとした。本来ありえない動作)"
      end
    end

    begin
      ActiveRecord::Base.transaction do
        #レコード登録数が最大数を超える場合、一番出勤時間が古く、idが一番若いレコードを削除する。
        if @kintais.count >= G_MAX_USER_KINTAIS
          @kintais.reorder(nil).order("t_syukkin ASC").order("id ASC").first.destroy
        end

        @kintai.t_syukkin = Time.now
        @kintai.save!

        current_user.update_attributes!(:f_state => true ) 

        flash[:notice] = "おはようございます。正常に記録されました。"
      end
    end

    respond_with @kintai,:location => kintais_url
  end
  # PATCH/PUT /kintais/1
  # PATCH/PUT /kintais/1.json
  def update
    if @kintai == nil
      return redirect_to @kintai, :notice => "不正なアクセスです。出禁←(対象の勤怠データが無いのに退勤データをアップデートしようとしました。)"
    end

    begin
      ActiveRecord::Base.transaction do
        @kintai.update_attributes!(kintai_params)
        
        flash[:notice] = "勤怠時間を修正しました。"
      end
    end

    respond_with @kintai,:location => kintais_url
  end

  def taikin_update
    if @kintai == nil
      return redirect_to @kintai, :alert => "不正なアクセスです。出禁←(対象の勤怠データが無いのに退勤しようとしました。)"
    end
    if current_user.f_state == false
      return redirect_to kintais_url, :alert => "不正なアクセスです。出禁←(退勤中に退勤しようとした。本来ありえない動作)"
    end

    begin
      ActiveRecord::Base.transaction do
        @kintai.update_attributes!(:t_taikin => Time.now)
        current_user.update_attributes!(:f_state => false )

        flash[:notice] = "お疲れ様です。正常に登録されました。"
      end
    end

    respond_with @kintai,:location => kintais_url
  end

  # DELETE /kintais/1
  # DELETE /kintais/1.json
  def destroy
    begin
      ActiveRecord::Base.transaction do
        if @kintai.id == @kintais.last.id #最後のレコードを削除する場合、ユーザーが出勤中であれば勤務外に戻す。
          if current_user.f_state == true
            current_user.update_attributes!(:f_state => false )
          end
        end
        @kintai.destroy

        flash[:notice] = "削除しました。"
      end
    end

    respond_with @kintai,:location => kintais_url
  end

  #対象のユーザーを削除する
  def user_destroy
    if current_user.f_admin == false
      return redirect_to setting_kintais_path, :notice => "ERROR"
    end

    begin
      ActiveRecord::Base.transaction do
        users = User.where( :name => select_params[:name] )
        users.each do |user|
          Kintai.where(:user_id => user.id).destroy_all
          user.destroy
        end

        redirect_to setting_kintais_path, :notice => "削除しました。"
      end
    end
  end

  #各テーブルに登録可能最大数以上のデータが登録されてしまっている場合、ユーザーテーブルなら新しいユーザーから、
  #勤怠テーブルならそのユーザーの古い勤怠情報から削除する。
  #adminのみ実行できる。
  def db_correction

    begin
      ActiveRecord::Base.transaction do
        #ユーザー数が最大数を超えて登録されている場合
        if User.count > G_MAX_USERS
          users = User.order("id DESC").limit(User.count - G_MAX_USERS)
          users.each do |user|
            Kintai.where(:user_id => user.id).destroy_all 
          end
          users.destroy_all #delete_allはlimit scopeで使用できないのでしゃあなし
        end

        #各ユーザーの勤怠テーブルに最大数を超えて登録されている場合
        users = User.all
        users.each do |user|
          kintais = Kintai.where(:user_id => user.id).order("t_syukkin ASC").order("id ASC")
          if kintais.count - G_MAX_USER_KINTAIS > 0
            kintais.limit(Kintai.count - G_MAX_USER_KINTAIS).destroy_all
          end
        end

        redirect_to setting_kintais_path, :notice => "データベースを修正しました。"
      end
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
      if date_params[:month] == 0
        Time.now.day > G_SIMEBI ? @target_date_max = Date.new(Time.now.year,Time.now.month,G_SIMEBI+1) >> 1 : @target_date_max = Date.new(Time.now.year,Time.now.month,G_SIMEBI+1)
      else
        @target_date_max = Date.new(date_params[:year].to_i,date_params[:month].to_i,G_SIMEBI+1)
      end
     # date_params[:year] == nil ? @target_date_max = Date.new(Time.now.year,Time.now.month,Time.now.day) : @target_date_max = Date.new(date_params[:year].to_i,date_params[:month].to_i,G_SIMEBI)
      @target_date_min = @target_date_max << 1
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def kintai_params
      params.require(:kintai).permit(:user_id, :t_syukkin, :t_taikin)
    end

    def date_params
      params.fetch(:date,{:year => Time.now.year,:month => 0}).permit(:year, :month) #fetchで、値がない場合のデフォルト値を設定。設定しないとActionController::ParameterMissingになるため。値がある場合はそちらが使用される。
    end

    def chk_user
      if current_user.id != @kintai.user_id
        return redirect_to user_root_path, :alert => "他の社員の勤怠情報にはアクセス出来ません。"
      end
    end

    def select_params
      params.require(:user).permit(:name)
    end

    #データベースに２重登録がされ、登録できる最大行数を超えていないかチェックする。
    #修正の必要があると判断される場合trueを返す。
    def db_check
      ret = false

      if current_user.f_admin == false
        return ret
      end

      #ユーザー数が超えていないか
      if User.count > G_MAX_USERS
        return true
      end

      #各ユーザーの勤怠テーブルに最大数を超えて登録されていないか
      users = User.all
      users.each do |user|
        if Kintai.all.where(:user_id => user.id).count - G_MAX_USER_KINTAIS > 0
          return true
        end
      end

      return ret
    end
end
