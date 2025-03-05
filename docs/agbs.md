---
---
title: AGBs
summary:
version:
published_at: !ruby/object:ActiveSupport::TimeWithZone
  utc: 2025-03-05 14:56:38.943915000 Z
  zone: !ruby/object:ActiveSupport::TimeZone
    name: Europe/Berlin
  time: 2025-03-05 15:56:38.943915000 Z
tags: []
metadata: {}
position: 0
id: 4
---

Diese Webanwendung hat im wesentlichen zwei Schnittstellen:
- Turnierpläne und Ergebnisse aus der Website billardarea.de (BA), bzw. seit 2022 aus den verschiedenen regionalen ClubCloud-Instanzen.
- die Anzeigetafeln an den Tischen.

Nachdem die Turnierdaten und Setzlisten von der ClubCloud abgegriffen sind arbeitet Carambus selbständig, wobei der gewählte Turniermodus mit den Anzeigetafeln abgeglichen wird. Ohne weitere Eingriffe durch den Turnier-Manager wird durch die Eingaben an den Anzeigetafeln der Turnierablauf gesteuert gemäss dem gewählten Turniermodus abgewickelt.

Aus Sicherheitsgründen (no waranty here! ;-) ) sollte sich das Turnier-Management nicht allein auf die Eingaben an den Anzeigetafeln stützen.  Eine parallele Erfassung der Spielergebnisse auf den. vorgegebenen Spielprotokollformularen sollte manuell durchgeführt werden.

