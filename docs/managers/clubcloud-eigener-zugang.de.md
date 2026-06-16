# Deinen eigenen ClubCloud-Zugang hinterlegen

> **Für Sportwarte und Turnierleiter.** Diese Anleitung erklärt, wie du deinen
> persönlichen ClubCloud-Login im Carambus-Profil hinterlegst — damit deine
> Aktionen in der ClubCloud unter **deinem** Namen erscheinen.

## Warum?

Wenn du im Carambus-Chat (oder über Claude Desktop) etwas in der ClubCloud
**änderst** — z.B. einen Spieler akkreditieren, eine Meldung anlegen, den
Meldeschluss verschieben — dann braucht Carambus einen ClubCloud-Login, um das
in deinem Namen zu tun.

Früher liefen **alle** Änderungen unter einer **geteilten Sammelkennung**. In der
ClubCloud sah es dann so aus, als hätte immer dieselbe Person alles gemacht.
Mit deinem **eigenen** Zugang werden deine Änderungen korrekt **dir** zugeordnet.

## So hinterlegst du deinen Zugang

1. Melde dich in Carambus an und öffne deine **Profil-/Account-Seite**
   (Konto bearbeiten).
2. Scrolle zur Sektion **„ClubCloud-Zugang"**.
3. Trage deinen **ClubCloud-Benutzernamen** und dein **ClubCloud-Passwort** ein
   (dieselben Daten, mit denen du dich direkt in der ClubCloud anmeldest).
4. **Speichern.** Fertig — ab jetzt laufen deine Schreibaktionen unter deiner
   eigenen ClubCloud-Identität.

Dein Passwort wird **verschlüsselt** gespeichert und niemandem angezeigt.

## Ändern und Entfernen

- **Passwort ändern:** neues Passwort eintragen + speichern.
- **Passwort unverändert lassen:** Passwort-Feld einfach **leer lassen** — dein
  gespeichertes Passwort bleibt erhalten (das Feld zeigt es aus Sicherheitsgründen
  nie an).
- **Zugang ganz entfernen:** das **Benutzername-Feld leeren** und speichern —
  damit werden Benutzername und Passwort gelöscht.

## Was passiert OHNE hinterlegten Zugang?

- **Lesen und Vorschau (Probelauf) funktionieren weiter** — du kannst dir
  Turniere, Meldelisten usw. ansehen.
- Sobald du eine **echte Schreibaktion** auslöst (z.B. „X akkreditieren"),
  bekommst du den Hinweis, deinen **ClubCloud-Zugang im Profil zu hinterlegen**.
  Die Aktion wird erst ausgeführt, wenn dein Zugang hinterlegt ist.

## Turnierleiter ohne eigenen ClubCloud-Account

Turnierleiter haben oft **keinen** eigenen ClubCloud-Account. Das ist in Ordnung:
Wenn dich ein Sportwart als Turnierleiter für ein bestimmtes Turnier einsetzt,
**erbst du für dieses Turnier** automatisch dessen ClubCloud-Zugang. Du musst
dann nichts hinterlegen — dein Schreibrecht bleibt trotzdem auf dein Turnier
beschränkt.

## Häufige Fragen

**Brauche ich das, wenn ich nur lese?**
Nein. Nur **Schreibaktionen** in der ClubCloud brauchen deinen Zugang.

**Sieht jemand mein Passwort?**
Nein — es wird verschlüsselt gespeichert und nirgends angezeigt.

**Ist das dasselbe wie der „Region-Admin-Zugang"?**
Nein. Der region-weite Admin-Zugang (`config/credentials`, siehe
[`clubcloud_credentials.md`](clubcloud_credentials.md)) ist eine geteilte
Technik-Konfiguration. Dein **eigener** Zugang hier im Profil ist persönlich und
sorgt für die korrekte Zuordnung deiner Änderungen.

---

*Technische Details (Resolver, Session-Handling, Audit): siehe
[`docs/developers/per-user-cc-identitaet.de.md`](../developers/per-user-cc-identitaet.de.md).*
