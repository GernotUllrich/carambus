class Ability
  include CanCan::Ability
  SYSTEM_ID_THRESHOLD = 50_000_000

  def initialize(user)
    user ||= User.new # Gast-Benutzer
    
    if user.system_admin?
      can :manage, :all
    elsif user.club_admin?
      # Allgemeine Regel für alle Ressourcen mit hohen IDs
      can :manage, :all do |obj|
        obj.id > SYSTEM_ID_THRESHOLD
      end
      
      # Spezielle Regeln für Benutzer
      can :manage, User do |u|
        (u.id == user.id || u.id > SYSTEM_ID_THRESHOLD) && 
        (u == user || !u.role_changed?)
      end
    end
    
    # Präferenzen-Selbstverwaltung ohne Block
    can :update, User, id: user.id
  end
end 