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
    @kintais = @kintais.where(:t_syukkin => @target_date_min..target_date_max )
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
      return redirect_to kintais_url, :notice => "不正なアクセスです。出禁←(勤怠データが無いのに編集画面にアクセスしようとしました。)"
    end
  end

  # POST /kintais
  # POST /kintais.json
  def create
    @kintai      = Kintai.new(kintai_params)
    @kintai_last = @kintais.last

    if @kintai_last != nil
      if current_user.f_state == true
        return redirect_to kintais_url, :notice => "不正なアクセスです。出禁←(出勤中に出勤しようとした。本来ありえない動作)"
      end
      if @kintai.t_syukkin.to_i < @kintai_last.t_taikin.to_i
        return redirect_to kintais_url, :notice => "最新の退勤時間より前の時間に出勤は出来ません。勤怠情報の修正が必要な場合は修正ボタンからお願いします。"
      end
    end

    respond_to do |format|
      begin
        ActiveRecord::Base.transaction do
          @kintai.save!

          current_user.update_attributes!(:f_state => true ) 
          format.html { redirect_to kintais_url,:notice => "おはようございます。正常に記録されました。" }
          format.json { render action: 'show', status: :created, location: @kintai }
        end
        rescue => e
          format.html { redirect_to kintais_url, :notice => "例外が発生しました。記録に失敗しました。"+e.message }
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
          format.html { redirect_to kintais_url,:notice => "例外が発生しました。記録に失敗しました。"+e.message}
          format.json { render json: @kintai.errors<<@user.errors, status: :unprocessable_entity }
        end
    end
  end

  def taikin_update
    if @kintai == nil
      return redirect_to @kintai, :notice => "不正なアクセスです。出禁←(対象の勤怠データが無いのに退勤しようとしました。)"
    end
    if current_user.f_state == false
      return redirect_to kintais_url, :notice => "不正なアクセスです。出禁←(退勤中に退勤しようとした。本来ありえない動作)"
    end
    if Kintai.new(kintai_params).t_taikin.to_i < @kintai.t_syukkin.to_i
      return redirect_to kintais_url, :notice => "最新の出勤時間より前の時間に退勤は出来ません。勤怠情報の修正が必要な場合は修正ボタンからお願いします。"
    end

    respond_to do |format|
      begin
        ActiveRecord::Base.transaction do
          @kintai.update_attributes!(kintai_params)
          current_user.update_attributes!(:f_state => false )
          format.html { redirect_to kintais_url,:notice => "お疲れ様です。正常に登録されました。"}
          format.json { head :no_content }
        end
        rescue => e
          format.html { redirect_to kintais_url,:notice => "例外が発生しました。記録に失敗しました。"+e.message}
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
          format.html { redirect_to kintais_url,:notice => "例外が発生しました。削除に失敗しました。"+e.message}
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
