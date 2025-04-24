class UploadsController < ApplicationController
  before_action :logged_in_check, except: %i[show index]
  before_action :set_upload, only: %i[show edit update destroy]

  # Uncomment to enforce Pundit authorization
  # after_action :verify_authorized
  # rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # GET /uploads
  def index
    @pagy, @uploads = pagy(Upload.sort_by_params(params[:sort], sort_direction))

    # Uncomment to authorize with Pundit
    # authorize @uploads
  end

  # GET /uploads/1 or /uploads/1.json
  def show; end

  # GET /uploads/new
  def new
    @upload = Upload.new

    # Uncomment to authorize with Pundit
    # authorize @upload
  end

  # GET /uploads/1/edit
  def edit; end

  # POST /uploads or /uploads.json
  def create
    begin
      Rails.logger.info "got create #{upload_params.inspect}"
      @upload = Upload.new(upload_params)
      @upload.user_id = current_user.id
      @upload.filename = upload_params["filename"].original_filename
      @upload.save
      upload_dir = "/var/www/html/island25/uploads/#{current_user.id}"
      Rails.logger.info "got public/roald/MyAlbum/uploads/#{current_user.id}"
      FileUtils.mkdir_p(upload_dir)
      f = File.open(File.join(upload_dir, @upload.filename), "wb")
      f.write(upload_params["filename"].read)
      f.close
      UploadMailer.report_upload("gernot.ullrich@gmx.de", current_user, @upload.filename).deliver
    rescue StandardError => e
      Rails.logger.info "Upload error #{e} #{e.backtrace.join("/n")}"
    end

    # Uncomment to authorize with Pundit
    # authorize @upload

    respond_to do |format|
      if @upload.save
        format.html { redirect_to uploads_path, notice: "Upload was successfully created." }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /uploads/1 or /uploads/1.json
  def update
    respond_to do |format|
      if @upload.update(upload_params)
        format.html { redirect_to @upload, notice: "Upload was successfully updated." }
        format.json { render :show, status: :ok, location: @upload }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @upload.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /uploads/1 or /uploads/1.json
  def destroy
    @upload.destroy
    respond_to do |format|
      format.html { redirect_to uploads_url, status: :see_other, notice: "Upload was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_upload
    @upload = Upload.find(params[:id])

    # Uncomment to authorize with Pundit
    # authorize @upload
  rescue ActiveRecord::RecordNotFound
    redirect_to uploads_path
  end

  # Only allow a list of trusted parameters through.
  def upload_params
    params.require(:upload).permit(:filename, :user_id, :position)

    # Uncomment to use Pundit permitted attributes
    # params.require(:upload).permit(policy(@upload).permitted_attributes)
  end
end
