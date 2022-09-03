class WordlesController < ApplicationController
  before_action :set_wordle, only: [:show, :edit, :update, :destroy]

  # GET /wordles
  def index
    @pagy, @wordles = pagy(Wordle.sort_by_params(params[:sort], sort_direction))

    # We explicitly load the records to avoid triggering multiple DB calls in the views when checking if records exist and iterating over them.
    # Calling @wordles.any? in the view will use the loaded records to check existence instead of making an extra DB call.
    @wordles.load
  end

  # GET /wordles/1
  def show
  end

  # GET /wordles/new
  def new
    @wordle = Wordle.new
  end

  # GET /wordles/1/edit
  def edit
  end

  # POST /wordles
  def create
    words = JSON.parse(wordle_params['words'])
    hints = JSON.parse(wordle_params['hints'])
    data = JSON.parse(wordle_params['data'])
    seqno = wordle_params['seqno'].to_i
    @wordle = Wordle.new(words: words, hints: hints, data: data, seqno: seqno )

    if @wordle.save
      redirect_to @wordle, notice: "Wordle was successfully created."
    else
      render :new
    end
  end

  # PATCH/PUT /wordles/1
  def update
    words = JSON.parse(wordle_params['words'])
    hints = JSON.parse(wordle_params['hints'])
    data = JSON.parse(wordle_params['data'])
    seqno = wordle_params['seqno'].to_i
    if @wordle.update(words: words, hints: hints, data: data, seqno: seqno )
      redirect_to @wordle, notice: "Wordle was successfully updated."
    else
      render :edit
    end
  end

  # DELETE /wordles/1
  def destroy
    @wordle.destroy
    redirect_to wordles_url, notice: "Wordle was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_wordle
    @wordle = Wordle.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def wordle_params
    params.require(:wordle).permit(:words, :hints, :data, :seqno)
  end
end
