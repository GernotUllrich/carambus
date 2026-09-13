# Table Reservation and Heating Control

Carambus has no booking system of its own. Tables are reserved in the **club's Google Calendar**. Carambus reads these
entries regularly and switches the table heaters accordingly, and also depending on whether a table's scoreboard is
running.

## Requirements {#requirements}

To be set up once by the administrator of the club server:

- **One switchable plug per table** of the TP-Link Kasa type. Carambus switches it through its local protocol
  (port 9999). Which device and firmware generations still support this has not been checked.
- **Fixed IP addresses** for plugs and scoreboards. Under `/table_locals` (system admin only), enter per table the IP
  of the plug (`tpl_ip_address`) and that of the scoreboard device (`ip_address`).
- **Google service account** with write access to the club calendar. The server credentials contain
  `google_service` (the service account key), `location_calendar_id` (the calendar) and `location_id` (the venue).
- **A crontab entry** for the check run `rake carambus:check_reservations`. It is not in `config/schedule.rb` and is
  therefore entered by hand, every 5 minutes recommended. Without it, no heater is switched.
- Switching only happens on the production server (`RAILS_ENV=production`).

Access to the calendar is granted by your club's calendar administrator.

## 1. Table reservation {#reservation}

### In the Google Calendar

Authorised members enter bookings directly in the club calendar. Changing and deleting is only possible there.

### At the scoreboard

On the scoreboard start page, **Reservations** leads to the next bookings and to **New table reservation** (title,
date, from–to, save). The entry ends up in the same Google Calendar.

!!! warning "Winter time"
    The scoreboard form converts the time with a fixed UTC+2 (summer time). Between late October and late March an
    entry created there is therefore one hour early. In winter, better reserve in the calendar.

### Title of the entry {#title-format}

Carambus reads from the title which tables are meant.

**Examples:**

- **"T6 Miller + Smith"**: one table
- **"T1, T4-T8 Club evening"**: several tables
- **"T5, T7 Cadre 35/2 Class 5-6"**: tournament reservation, as the automatic tournament reservation creates it
- **"T1-T6 Club championship (!)"**: protected booking (see rule 5)

**Rules:**

- **Table reference:** a capital "T" directly before the number (`T6`). "Table 6" or "t6" are not recognised.
- **What "T6" means:** the **6th table of the venue when sorted by table name**, not the table with a 6 in its name.
  As long as the tables are called "Tisch 1" to "Tisch 9", both agree. From ten tables on ("Tisch 10" sorts before
  "Tisch 2") or with mixed names they differ; check the order in the venue's table list.
- **Several tables:** separated by commas (`T1, T4`) or as a range (`T4-T8`, both ends with T).
- **Only existing tables.** A T number larger than the number of tables currently aborts the whole check run, and
  then no heater is switched for any table.
- **Description:** the text after the table references is free and only used for display.
- **Protected bookings:** "(!)" anywhere in the title prevents automatic switch-off during the booking.

!!! danger "Entries without a recognisable table reference are deleted"
    If the check run finds no table in a title, it deletes the entry from the Google Calendar. This currently also
    affects entries that name **only pool tables**. Pure notice entries start with a word and a colon, e.g.
    `info: club closed`; they stay and do not heat.

## 2. Heating control: the rules {#rules}

Each check run reads the upcoming entries from the calendar and pings the scoreboard device of each table to see
whether it is reachable on the network. "Scoreboard on" below means exactly that: the device at the configured IP
answers.

### Rule 1: heater on before a booking

**Pre-heating time:** 2 hours before the start; 4 hours for tables of the kind "Match Billard" or "Snooker". Pool
tables are not heated according to the calendar.

**Example:** booking 18:00–22:00 on a normal table → heater on from 16:00.

**Large tables:** between 4 and 2 hours before the start the check run currently switches the heater on and off again
in the same run as long as the scoreboard is not running. It is reliably on only 2 hours before. For the full 4 hours,
add "(!)" to the booking.

**Short-notice bookings:** if a booking is entered within the pre-heating time, the next check run switches the heater on.

### Rule 2: heater on for a spontaneous game

As soon as a table's scoreboard is on, the next check run switches the heater on, even without a booking (and also on
pool tables with a configured plug). A scoreboard that is never switched off therefore keeps the heater on permanently.

### Rule 3: heater off when the scoreboard is off

- **Without a current booking:** heater off at the next check run.
- **With a booking:** in the 2 hours before the start and in the first 30 minutes after it the heater stays on; after
  that rule 4 applies.
- The calendar entry itself stays unchanged.

### Rule 4: heater off when nobody plays after the start

If the scoreboard is still off 30 minutes after the start of the booking, the heater goes off (reason in the log:
`inactivity detected`). Exception: bookings with "(!)".

### Rule 5: protected bookings "(!)"

With "(!)" in the title the heater stays on from the pre-heating time until the end of the booking, regardless of the
scoreboard. Use: tournaments and events where the heater must run for sure.

**After the booking ends** the next check run switches the heater off (reason `event finished`), also with "(!)". If
the scoreboard is still on then, the following run switches it on again by rule 2. Switch the scoreboard off after
playing.

### Rule 6: tournament reservations

Tournaments are entered in the calendar by the task `carambus:auto_reserve_tables` after the entry deadline, if it is
set up via crontab. Details: [Automatic table reservation](automatische_tischreservierung.md) (German).

**Cancellation:** delete all calendar entries of the tournament (the automation may have created several; within 7
days after the entry deadline it recreates deleted ones) and switch the scoreboard off. Renaming to "ABGESAGT: …"
does not stop pre-heating that is already running right away.

### Rule 7: changed bookings

Carambus detects changed bookings by booking ID, start, end and title and takes over the new data at the next check
run. The heater then follows the new time. If a booking disappears from the calendar, the table forgets it as well.

**Example:** booking "T5 Training, 14:30–15:30" is moved to 15:40–16:40 → the next run heats according to the new time.

### Technical details {#technical}

**Parameters:**

- **Check interval:** as often as the crontab line specifies (recommended: every 5 minutes)
- **Scoreboard check:** ping to the IP address of the scoreboard device
- **Look-ahead:** bookings are evaluated from their pre-heating time on (2 or 4 hours)
- **Pre-heating times:** Match Billard and Snooker 4 hours, other tables (carom) 2 hours, pool no calendar-based heating

**Tolerances:**

- **Before the start:** 120 minutes (heater stays on in the pre-heating phase)
- **After the start:** 30 minutes (time to switch the scoreboard on)

**Logs:**

- `log/events`: upcoming calendar entries
- `log/table_status`: current state of all tables
- Rails log of the server: every switching with its reason, marked `🔥 HEATER ON` or `🔥 HEATER OFF`
- plus the log file given in your own crontab line

## 3. Troubleshooting {#troubleshooting}

### Heater goes off during the game

**Possible causes:**

1. **Scoreboard not reachable:** the ping fails, Carambus considers the scoreboard off.
2. **Booking over:** the end of the booking has passed (see rule 5).
3. **Booking deleted or changed:** the booking is no longer in the calendar in that form.

**Solution:** search the Rails log for `🔥 HEATER OFF`; the entry names the reason.

### Heater does not come on

**Possible causes:**

1. **Title not recognised:** e.g. "Table 6" instead of "T6". The check run may already have deleted such entries.
2. **Booking too far in the future:** more than 2 hours to the start (Match Billard/Snooker: 4 hours).
3. **Pool table:** pool tables are not heated according to the calendar.
4. **A different table is meant:** the T number refers to the position in the table list (see title of the entry).
5. **No check run:** the crontab entry for `carambus:check_reservations` is missing.
6. **No plug configured**, or the plug is not reachable.

**Solution:** check the title, then look at `log/events`, `log/table_status` and the log file of the crontab line.

### Heater goes off 30 minutes after the start

**Cause:** the scoreboard was not reachable until then (log: `HEATER OFF`, reason `inactivity detected`).

**Solution:**

- switch the scoreboard on earlier
- or mark the booking with "(!)"
