class UsersController < ApplicationController
  before_action :admin_only_check, except: %i[show index stop_impersonating]
  before_action :set_user, only: %i[show edit update destroy impersonate]

  # GET /users
  # GET /users.json
  def index
    @users = User.all
  end

  # GET /users/1
  # GET /users/1.json
  def show; end

  # GET /users/new
  def new
    @user = User.new
  end

  # GET /users/1/edit
  def edit; end

  # POST /users
  # POST /users.json
  def create
    @user = User.new(user_params)
    if @user.save
      sign_in(@user)
      redirect_to root_path, notice: 'Account created successfully'
    else
      render :new
    end
  end

  # PATCH/PUT /users/1
  # PATCH/PUT /users/1.json
  def update
    authorize! :update, @user
    if @user.update(user_params)
      redirect_to @user, notice: "User was successfully updated."
    else
      render :edit
    end
  end

  # POST /users/1/impersonate
  # Nur echte system_admins duerfen die Identitaet wechseln. Andere system_admins
  # koennen NICHT uebernommen werden (keine Admin-zu-Admin-Eskalation).
  def impersonate
    unless true_user&.system_admin?
      redirect_back fallback_location: root_path,
                    alert: "Nur Systemadministratoren dürfen die Benutzeridentität wechseln."
      return
    end

    if @user.system_admin?
      redirect_back fallback_location: root_path,
                    alert: "Andere Systemadministratoren können nicht übernommen werden."
      return
    end

    if @user == true_user
      redirect_back fallback_location: root_path,
                    alert: "Das ist bereits dein eigenes Konto."
      return
    end

    impersonate_user(@user)
    redirect_to root_path, notice: "Du agierst jetzt als #{@user.display_name}."
  end

  # DELETE /users/stop_impersonating
  # Beendet eine laufende Impersonation. Bewusst ohne admin_only_check, da
  # current_user waehrend der Impersonation der (evtl. nicht-Admin) Ziel-User ist.
  def stop_impersonating
    name = current_user&.display_name
    stop_impersonating_user
    redirect_to root_path, notice: name ? "Du agierst wieder als du selbst (war: #{name})." : "Identitätswechsel beendet."
  end

  # DELETE /users/1
  # DELETE /users/1.json
  def destroy
    @user.destroy
    respond_to do |format|
      format.html { redirect_to users_url, notice: "User was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_user
    @user = User.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def user_params
    if current_user == @user
      params.require(:user).permit(:preferences)
    else
      params.require(:user).permit() # Keine Parameter für andere Benutzer
    end
  end
end
