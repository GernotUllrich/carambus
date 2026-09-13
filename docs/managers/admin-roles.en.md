# Admin Roles and Permissions

What someone may do in Carambus depends on three things: the **role** of the user account, the **personas**
sports director (Sportwart) or regional sports director (Landessportwart), and whether they are entered as
**tournament director** for a tournament. Rights add up; a club admin with the sports director persona has both.

Without signing in, every visitor sees the public lists and detail pages: upcoming and past tournaments, players,
clubs and results. The rights below concern making changes.

## Roles and personas {#roles}

**Role**: every account has exactly one.

| Role | Value in the system | In short |
|---|---|---|
| Player | `player` | Default for new accounts; maintains their own profile (including their own ClubCloud access) |
| Club admin | `club_admin` | Tournaments, tournament monitor, master data |
| System admin | `system_admin` | Everything, plus the admin area (users, roles, settings) |

**Personas** are added on top of the role. Only a system admin assigns them:

- **Sports director (Sportwart)**: applies to the tournaments within their scope, i.e. the venues and disciplines
  assigned to them. If no discipline is assigned, all disciplines apply; "Karambol" covers its sub-disciplines
  (e.g. Cadre 35/2, three-cushion). Without an assigned venue the persona applies to no tournament.
- **Regional sports director (Landessportwart)**: like the sports director, but for all venues.

**Tournament director** is whoever is entered as tournament director of a tournament. The right applies to that
tournament.

## Who may do what {#matrix}

The columns "Tournament director" and "Sports director" mean an account with the role player and that persona or
assignment.

| Action | Player | Tournament director | Sports director | Club admin | System admin |
|---|---|---|---|---|---|
| View lists and detail pages | yes | yes | yes | yes | yes |
| Create a tournament (only on a local server) | – | – | – | yes | yes |
| Use the tournament wizard on the tournament page | – | – | – | yes | yes |
| Edit the participant list | – | yes | yes | yes | yes |
| Name the tournament director of a tournament | – | – | yes | yes | yes |
| Open the tournament monitor, reset a tournament | – | – | – | yes | yes |
| Edit master data (clubs, players, leagues, teams, tables, disciplines, seasons, tournament plans …) | – | – | – | yes | yes |
| Reload a club or league from the ClubCloud | – | yes | yes | yes | yes |
| ClubCloud write actions in the Carambus assistant | – | yes | yes | – | yes |
| Admin area: users, roles, personas, settings, members' contact data | – | – | – | – | yes |

Where a right is missing, the button is greyed out or not shown. Sports directors without an admin role do part of
this through the Carambus assistant (see [ClubCloud MCP Cloud Quickstart](clubcloud-mcp-cloud-quickstart.md)).

## What Carambus does not do {#limits}

- **No audit log.** Administrative actions and role changes are not logged. Only ClubCloud write actions that go
  through the Carambus assistant are logged (who, when, which tool).
- **No notification** when a role changes. Tell the person yourself.
- **No club binding.** A club admin is not assigned to a club: they can edit the master data of all clubs on this
  server. Records that come from the central server (such as clubs and players from the ClubCloud) are read-only on
  a local server.
- **No admin area for club admins.** The avatar menu does show them "Admin → Dashboard", and they land there after
  signing in; the admin area, however, turns them away with "System-Admin only". Only a system admin changes the
  server settings (context, venue, club, quick game presets); the application must be restarted afterwards.
- **No backups through the interface.** Backups and maintenance are part of running the server.

## Assigning roles and personas {#assign}

System admins only:

1. Avatar menu → **Admin** → **Dashboard**. The user list opens.
2. **Edit** the user.
3. Field **Role**: `player`, `club_admin` or `system_admin`.
4. In the same form: **Sportwart-Persona** (sports director or regional sports director), **Sportwart-Disziplinen**,
   **Sportwart-Spielorte** and **Verknüpfter Spieler** (linked player).
5. Save.

Admins set the tournament director of a tournament in the tournament's edit form. Sports directors name them through
the Carambus assistant ("make Max Mustermann tournament director of the Cadre tournament"), because the edit button
is only active for admins. The system admin also maintains the assignments in the admin area under
**User Tournaments**.

With shell access to the server, the Rails console works too:

```ruby
user = User.find_by(email: "admin@example.com")
user.role = "system_admin"
user.save!
```

## For developers: checking rights in code {#code}

```ruby
current_user.admin?          # true for club_admin OR system_admin
current_user.system_admin?   # system admin only
current_user.sportwart?      # persona sports director or regional sports director

# Tournament rights are checked by Pundit:
policy(@tournament).manage_teilnehmerliste?   # tournament director, sports director in scope, admin
policy(@tournament).assign_leiter?            # sports director in scope, admin
```

The buttons in the lists follow `current_user.admin?`. The CanCanCan rules in `app/models/ability.rb` are evaluated
in only a few places; they are not authoritative for tournaments.
