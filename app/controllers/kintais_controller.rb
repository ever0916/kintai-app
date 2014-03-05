class KintaisController < ApplicationController
  before_action :set_kintai, only: [:show, :edit, :update, :destroy]

  # GET /kintais
  # GET /kintais.json
  def index
    @kintais = Kintai.all
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
    @kintai = Kintai.new(kintai_params)

    respond_to do |format|
      if @kintai.save
        format.html { redirect_to @kintai, notice: 'Kintai was successfully created.' }
        format.json { render action: 'show', status: :created, location: @kintai }
      else
        format.html { render action: 'new' }
        format.json { render json: @kintai.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /kintais/1
  # PATCH/PUT /kintais/1.json
  def update
    respond_to do |format|
      if @kintai.update(kintai_params)
        format.html { redirect_to @kintai, notice: 'Kintai was successfully updated.' }
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
