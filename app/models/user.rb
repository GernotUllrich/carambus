class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  belongs_to :player, foreign_key: "player_id"
  validates :email, uniqueness: true

  attr_accessor :player_ba_id

  has_paper_trail

  def display_name
    username.presence || (lastname.present? ? "#{lastname}, #{firstname}" : nil) || email
  end
end
