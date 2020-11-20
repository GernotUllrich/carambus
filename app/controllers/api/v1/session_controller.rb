class Api::V1::SessionController < ApiController
  def login
    user = User.find_by :email=>params[:email]
    if user && user.valid_password?(params[:password])
      payload = {user_id: user.id}
      token = encode_token(payload)
      user_hash = JSON.parse(user.to_json)
      ### TODO TEST
      tournament = Tournament[716]
      tournament.to_json(:include => { :region => [ :include => :clubs]})
      ###
      user_json = user_hash.merge(tournament: JSON.parse(tournament.to_json))
      render json: {
          user: user_json,
          jwt: token}
    else
      render json: {status: "error", message: "We don't find such an user according to your information,please try again."}
    end
  end

  def auto_login
    if session_user
      render json: session_user, include: ['order','orders.dishes']
    else
      render json: {errors: "No User Logged In."}
    end
  end
end
