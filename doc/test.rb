



Player.joins(:club => :region).where(regions: {id: 1}).where.not(players: {ba_id: nil}).where(players: {cc_id: nil}).map{ |p| [p.ba_id,p.firstname,p.lastname,p.club.cc_id,p.club.ba_id,p.club.shortname,(q = Player.joins(:club).where(firstname:p.firstname, lastname: p.lastname); q.map{|p2| [p2.ba_id,p2.firstname,p2.lastname,p2.club.cc_id,p2.club.ba_id,p2.club.shortname]} if q.count > 1)]}
