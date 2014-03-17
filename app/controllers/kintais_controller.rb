class KintaisController < ApplicationController
  before_action :set_kintai , only: [:show ,:update, :taikin_update, :edit  , :destroy]
  before_action :set_kintais, only: [:index,:edit  , :create                , :destroy, :get_my_record]
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
    @target_date_min = Date.new(Time.now.year,Time.now.month,1)
    target_date_max = @target_date_min >> 1
    @kintais = @kintais.reorder(nil).where(:t_syukkin => @target_date_min..target_date_max ).order("t_syukkin ASC")#reorder(nil)で直前のorder byを無効に出来るっぽい
  end

  def get_my_record
    if current_user.f_state == false
      @kintai  = Kintai.new
    else
      if @kintais != nil
        @kintai = @kintais.last
      end
    end

    #指定した月の勤怠レコードを@kintaisに取得。
    @target_date_min = Date.new(date_params[:year].to_i,date_params[:month].to_i,1)
    target_date_max = @target_date_min >> 1
    @kintais = @kintais.where(:t_syukkin => @target_date_min..target_date_max )

    render "index"
  end

  def setting
    @target_date_min = Date.new(Time.now.year,Time.now.month,1)
  end

  def export
    require 'spreadsheet'

    @users   = User.all.order("id ASC")
    @kintais = Kintai.all

    #指定した月の勤怠レコードを@kintaisに取得。
    @target_date_min = Date.new(date_params[:year].to_i,date_params[:month].to_i,1)
    target_date_max = @target_date_min >> 1

    #テンプレートファイルの生成
    book = Spreadsheet::Workbook.new
    @users.each do |user|
      #シートの生成。名前を付ける
      sheet = book.create_worksheet(:name => user.name)

      @chk = @user_kintais = @kintais.where(:t_syukkin => @target_date_min..target_date_max ).where(:user_id => user.id).order("t_syukkin ASC")
      
      sheet[0,0] = user.name
      sheet[0,1] = @target_date_min.strftime("%Y年%m月分")
      sheet[2,0] = "出勤時刻"
      sheet[2,1] = "退勤時刻"
      sheet[2,2] = "勤務時間"

      goukei = 0
      f_err  = false
      @user_kintais.each_with_index do |user_kintai,count|
        #値の設定
        sheet[count+3,0] = user_kintai.t_syukkin.strftime("%d日 %H:%M")
        if user_kintai.t_taikin == nil
          f_err = true
          sheet.row(count+3).set_format(0,Spreadsheet::Format.new(:pattern => 1,:pattern_fg_color => :red))
          sheet.row(count+3).set_format(1,Spreadsheet::Format.new(:pattern => 1,:pattern_fg_color => :red))
          sheet.row(count+3).set_format(2,Spreadsheet::Format.new(:pattern => 1,:pattern_fg_color => :red))
          sheet.row(count+3).set_format(3,Spreadsheet::Format.new(:pattern => 1,:pattern_fg_color => :red))
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
            sheet.row(count+3).set_format(0,Spreadsheet::Format.new(:pattern => 1,:pattern_fg_color => :red))
            sheet.row(count+3).set_format(1,Spreadsheet::Format.new(:pattern => 1,:pattern_fg_color => :red))
            sheet.row(count+3).set_format(2,Spreadsheet::Format.new(:pattern => 1,:pattern_fg_color => :red))
            sheet.row(count+3).set_format(3,Spreadsheet::Format.new(:pattern => 1,:pattern_fg_color => :red))
            sheet[count+3,3] = "他のレコードと勤怠時間が被っています。" + current_user.name + "さんが分裂した可能性があります。"
            sheet.row(cnt+3).set_format(0,Spreadsheet::Format.new(:pattern => 1,:pattern_fg_color => :red))
            sheet.row(cnt+3).set_format(1,Spreadsheet::Format.new(:pattern => 1,:pattern_fg_color => :red))
            sheet.row(cnt+3).set_format(2,Spreadsheet::Format.new(:pattern => 1,:pattern_fg_color => :red))
            sheet.row(cnt+3).set_format(3,Spreadsheet::Format.new(:pattern => 1,:pattern_fg_color => :red))
            sheet[cnt+3,3] = "他のレコードと勤怠時間が被っています。" + current_user.name + "さんが分裂した可能性があります。"
          end
        end

        goukei += user_kintai.t_taikin - user_kintai.t_syukkin;
      end
      if f_err == false
        rz = goukei.divmod(3600)
        sheet[@user_kintais.length+3,2] = "計#{rz[0]}時間#{rz[1].to_i / 60}分"
      end
      sheet[@user_kintais.length+5,0] = "※背景が赤いレコードは誤りがあるか、退勤時刻が入力されていません。"
    end


    #ダウンロードする為にtempファイルを作成
    tmpfile = Tempfile.new ["test", ".xls"]
    book.write tmpfile

    tmpfile.open # reopen

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
    if @kintais == nil
      return redirect_to kintais_url, :alert => "不正なアクセスです。出禁←(勤怠データが無いのに編集画面にアクセスしようとしました。)"
    end
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

    respond_to do |format|
      begin
        ActiveRecord::Base.transaction do
          @kintai.t_syukkin = Time.now
          @kintai.save!

          current_user.update_attributes!(:f_state => true ) 
          format.html { redirect_to kintais_url,:notice => "おはようございます。正常に記録されました。" }
          format.json { render action: 'show', status: :created, location: @kintai }
        end
        rescue => e
          format.html { redirect_to kintais_url, :alert => "例外が発生しました。記録に失敗しました。"+e.message }
          format.json { render json: @kintai.errors<<@user.errors, status: :unprocessable_entity }
        end
    end
  end
  # PATCH/PUT /kintais/1
  # PATCH/PUT /kintais/1.json
  def update
    if @kintai == nil
      return redirect_to @kintai, :notice => "不正なアクセスです。出禁←(対象の勤怠データが無いのに退勤データをアップデートしようとしました。)"
    end

    respond_to do |format|
      begin
        ActiveRecord::Base.transaction do
          @kintai.update_attributes!(kintai_params)
          format.html { redirect_to kintais_url,:notice => "勤怠時間を修正しました。" }
          format.json { head :no_content }
        end
        rescue => e
          format.html { redirect_to kintais_url,:alert => "例外が発生しました。修正に失敗しました。"+e.message}
          format.json { render json: @kintai.errors<<@user.errors, status: :unprocessable_entity }
        end
    end
  end

  def taikin_update
    if @kintai == nil
      return redirect_to @kintai, :alert => "不正なアクセスです。出禁←(対象の勤怠データが無いのに退勤しようとしました。)"
    end
    if current_user.f_state == false
      return redirect_to kintais_url, :alert => "不正なアクセスです。出禁←(退勤中に退勤しようとした。本来ありえない動作)"
    end

    respond_to do |format|
      begin
        ActiveRecord::Base.transaction do
          @kintai.update_attributes!(:t_taikin => Time.now)
          current_user.update_attributes!(:f_state => false )
          format.html { redirect_to kintais_url,:notice => "お疲れ様です。正常に登録されました。"}
          format.json { head :no_content }
        end
        rescue => e
          format.html { redirect_to kintais_url,:alert => "例外が発生しました。記録に失敗しました。"+e.message}
          format.json { render json: @kintai.errors<<@user.errors, status: :unprocessable_entity }
        end
    end
  end

  # DELETE /kintais/1
  # DELETE /kintais/1.json
  def destroy
    respond_to do |format|
      begin
        ActiveRecord::Base.transaction do
          if @kintai.id == @kintais.last.id #最後のレコードを削除する場合、ユーザーが出勤中であれば勤務外に戻す。
            if current_user.f_state == true
              current_user.update_attributes!(:f_state => false )
            end
          end
          @kintai.destroy
          format.html { redirect_to kintais_url,:notice => "削除しました。" }
          format.json { head :no_content }
        end
        rescue => e
          format.html { redirect_to kintais_url,:alert => "例外が発生しました。削除に失敗しました。"+e.message}
          format.json { render json: @kintai.errors<<@user.errors, status: :unprocessable_entity }
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

    # Never trust parameters from the scary internet, only allow the white list through.
    def kintai_params
      params.require(:kintai).permit(:user_id, :t_syukkin, :t_taikin)
    end

    def date_params
      params.require(:date).permit(:year, :month)
    end
end
