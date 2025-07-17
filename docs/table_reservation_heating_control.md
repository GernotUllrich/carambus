# Table Reservation and Heating Control

**BC Wedel, Gernot, May 7, 2024**

This documentation describes the processes for table reservations and automatic heating control at BC Wedel.

## Table Reservations

### Reservation Process

Table reservations can be made by authorized members in the central Google Calendar "BC Wedel".

#### Calendar Access

Access links can be requested by sending an informal email to the following addresses:
- `gernot.ullrich@gmx.de`
- `wcauel@gmail.com`

#### Reservation Title Format

The title of the reservation must follow a specific format to be correctly evaluated by **Carambus**.

##### Examples of reservation titles:

- **Single table**: `T6 Gernot + Lothar`
- **Multiple tables**: `T1, T4-T8 Clubabend`
- **Tournament with discipline**: `T5, T7 NDM Cadre 35/2 Klasse 5-6`

> **Note**: The term "Cadre" is a special term that must be used in the reservation.

## Heating Control (Table Heaters)

The table heaters are automatically controlled based on calendar entries and activities on the **Scoreboard**.

### Activation (ON)

The heaters are automatically activated:

1. **2 hours before a reservation**
2. **At the latest within 5 minutes**, when a game is recognized on the **Scoreboard**

### Deactivation (OFF)

The heaters are automatically deactivated:

1. **After reservation start**: If no activity is recognized on the **Scoreboard** for one hour
2. **Without running reservation**: If no reservation is running and no activity is recognized on the **Scoreboard** for one hour

## Technical Integration

### Carambus System

The **Carambus** system evaluates the calendar entries and coordinates the heating control.

### Scoreboard Integration

The **Scoreboard** recognizes game activities and communicates them to the heating control system.

## Maintenance and Support

### Calendar Access

For problems with calendar access, contact:
- `gernot.ullrich@gmx.de`
- `wcauel@gmail.com`

### Heating Problems

For problems with heating control:
1. Check calendar entries for correct formatting
2. Monitor Scoreboard activity
3. Contact the system administrator

## Change History

- **May 7, 2024**: First version of documentation
- Created by: Gernot Ullrich
- Location: BC Wedel

---

*This documentation is part of the Carambus operational documentation for BC Wedel.* 