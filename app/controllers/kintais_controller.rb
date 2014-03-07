class KintaisController < ApplicationController
  before_action :set_kintai, only: [:show, :edit, :update, :destroy]

  # GET /kintais
  # GET /kintais.json
  def index
    @kintais = Kintai.all
    @kintai  = Kintai.new
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
    @kintai_last = Kintai.last
    @user        = User.find(current_user.id)


    if @kintai_last != nil
      if @kintai.t_kintai.to_i < @kintai_last.t_kintai.to_i
        return redirect_to @kintai, :notice => "最新の勤怠情報より前の時間に出勤退勤は出来ません。勤怠情報の修正が必要な場合は修正ボタンからお願いします。"
      end
    end

    respond_to do |format|
      begin
        ActiveRecord::Base.transaction do
          @kintai.save!

          if @user.f_state == false
            @user.update_attributes!(:f_state => true ) 
            format.html { redirect_to @kintai, notice: 'おはようございます。正常に記録されました。'}
          else
            @user.update_attributes!(:f_state => false )
            format.html { redirect_to @kintai, notice: 'お疲れ様です。正常に記録されました。'}
          end
          format.json { render action: 'show', status: :created, location: @kintai }
        end
        rescue => e
          redirect_to @kintai, :notice => "例外が発生しました。記録に失敗しました。"+e.message
          format.json { render json: @kintai.errors<<@user.errors, status: :unprocessable_entity }
        end
    end
  end
  # PATCH/PUT /kintais/1
  # PATCH/PUT /kintais/1.json
  def update
    respond_to do |format|
      if @kintai.update(kintai_params)
        format.html { redirect_to @kintai, notice: '勤怠情報を修正しました。' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @kintai.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /kintais/1
  # DELETE /kintais/1.json
  def destroy
    @kintai.destroy
    respond_to do |format|
      format.html { redirect_to kintais_url }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_kintai
      @kintai = Kintai.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def kintai_params
      params.require(:kintai).permit(:user_id, :f_kintai, :t_kintai)
    end
end
