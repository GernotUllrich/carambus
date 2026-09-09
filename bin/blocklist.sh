#!/bin/bash
# Pflege der iptables-Sperrliste (Kette carambus-blocklist).
#
# Läuft AUF dem Server, nicht auf dem Entwicklungsrechner:
#   ssh <host> 'sudo /var/www/<scenario>/current/bin/blocklist.sh suggest'
#
# Warum eine eigene Kette und nicht ufw-user-input: /etc/iptables/rules.v4 gehört
# dem Ansible-Template und wird bei jedem Lauf überschrieben. Die Sperrliste liegt
# deshalb in /etc/iptables/blocklist.v4, das Ansible mit `force: no` nie anfasst
# (roles/bootstrap/tasks/main.yml, Task "Seed blocklist file"). Geladen wird sie vom
# netfilter-persistent-Plugin 35-blocklist, das nach 15-ip4tables läuft.
#
# NIEMALS `netfilter-persistent save` zum Sichern benutzen: das ruft auch
# 15-ip4tables auf und überschreibt rules.v4 mit dem laufenden Stand — danach
# kollidiert jeder Ansible-Lauf damit. Dieses Skript schreibt immer erst die Datei
# und lädt dann neu.

set -euo pipefail

# Über BLOCKLIST= übersteuerbar, damit add/remove gegen eine Testdatei prüfbar sind,
# ohne die echte Sperrliste eines laufenden Servers anzufassen.
BLOCKLIST=${BLOCKLIST:-/etc/iptables/blocklist.v4}
CHAIN=carambus-blocklist
ACCESS_LOG=${ACCESS_LOG:-/var/log/carambus_bcw/access.log}

# Verkehrsquellen, die nie gesperrt werden dürfen.
#
# Die Liste ist am 2026-09-09 aus dem echten Log entstanden und nicht theoretisch:
# Unter den Top-IPs nach Anfragevolumen standen ausschließlich 127.0.0.1, die
# Scoreboards im LAN und der eigene DSL-Anschluss. Ein Vorschlagsmechanismus ohne
# diese Ausschlüsse hätte den Spielbetrieb abgeschaltet.
readonly PRIVATE_NETS='^(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.|169\.254\.|::1|fe80:|fc|fd)'

# Suchmaschinen gehören nicht in eine IP-Sperrliste. Der nginx-Bot-Block
# beantwortet sie bereits mit 403 (docs/administrators/nginx-bot-block.de.md);
# das ist die richtige Ebene. Eine IP-Sperre träfe wechselnde Crawler-Netze und
# wäre Pflege ohne Ertrag.
readonly SEARCH_ENGINE_UA='(googlebot|bingbot|baiduspider|yandexbot|duckduckbot|applebot)'

# Anfragemuster, die kein legitimer Client dieser Anwendung je stellt.
#
# NICHT enthalten: /vendor/ und *.php als Pauschalmuster. /vendor/ liefert die
# Assets der Anwendung selbst (14.719 Treffer im Log, alle von eigenen Geräten) —
# als Angriffsmuster gelesen ist es ein reiner Fehlalarm-Generator.
readonly SCAN_PATHS='(/\.env|/\.git/|/wp-admin|/wp-login|/wp-content|/phpmyadmin|/xmlrpc\.php|/cgi-bin/|/vendor/phpunit|/\.aws/|/config\.json|/\.ssh/)'

# Zweites Signal: Anfragen mit absoluter URL auf einen FREMDEN Host. Wer so fragt,
# sucht einen offenen Proxy — ein normaler Client schickt nur den Pfad. Im Log vom
# 2026-09-09 war das der einzige echte Angriffsversuch in sechs Monaten
# (cdhxjssw_com.fsdihui.com/index.php), und der Pfad-Filter allein fand ihn nicht.
#
# Absolute URLs auf den EIGENEN Host sind harmlos und häufig — Proxys und manche
# Clients schicken sie. Der eigene Name lässt sich aber nicht zuverlässig aus der
# Konfiguration ableiten: bc-wedel.duckdns.org steht weder in nginx server_name
# noch im Hostnamen (der lautet "raspberrypi"). Ein fest eingetragener Name wäre
# beim nächsten Verein wieder falsch.
#
# Deshalb kalibriert sich das Skript am Log selbst: Der eigene Host ist derjenige,
# den der Server in absoluten Anfragen tatsächlich BEDIENT (Status 2xx/3xx) — ein
# fremdes Proxy-Ziel kann er nicht bedienen, dort steht 4xx/5xx. Der Status-Bezug
# ist wichtig: ohne ihn wäre ein Angreifer, der eine fremde Domain oft genug
# anfragt, allein durch Menge als "eigen" durchgerutscht.
own_hosts_re() {
    local log=$1 names
    names=$(grep -aoiE '"[A-Z]+ https?://[^/ ]+[^"]*" (2|3)[0-9][0-9] ' "$log" 2>/dev/null \
            | sed -E 's#^"[A-Z]+ https?://([^/ ]+).*#\1#' | sed 's/:[0-9]*$//' \
            | sort | uniq -c | sort -rn | head -3 | awk '{print $2}')
    names="$names $(hostname -f 2>/dev/null) $(hostname 2>/dev/null) localhost"
    echo "$names" | tr ' ' '\n' | grep -v '^$' | sed 's/\./\\./g' | sort -u | paste -sd'|' -
}

usage() {
    cat <<EOF
Sperrliste pflegen (Kette $CHAIN)

  $0 status            Kette, Datei und Ladeweg anzeigen
  $0 list              gesperrte Adressen auflisten
  $0 suggest [tage]    Kandidaten aus dem Zugriffslog vorschlagen (nur lesen)
  $0 add <ip|cidr>     sperren (Datei schreiben, dann neu laden)
  $0 remove <ip|cidr>  entsperren

Beispiele:
  $0 suggest 30
  $0 add 203.0.113.7
  $0 add 47.79.0.0/16
EOF
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Fehler: braucht root (sudo $0 $*)" >&2
        exit 1
    fi
}

# Akzeptiert IPv4 mit optionaler Präfixlänge. Bewusst streng: ein Tippfehler in
# einer Sperrregel fällt sonst erst auf, wenn jemand ausgesperrt ist.
valid_target() {
    [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/([0-9]|[12][0-9]|3[0-2]))?$ ]] || return 1
    local ip=${1%%/*} o
    IFS=. read -ra o <<<"$ip"
    for n in "${o[@]}"; do [ "$n" -le 255 ] || return 1; done
    # Die eigenen Netze schützen sich selbst gegen einen Fehlgriff.
    [[ $ip =~ $PRIVATE_NETS ]] && { echo "Fehler: $ip liegt in einem privaten/lokalen Netz" >&2; return 1; }
    return 0
}

normalize() { case "$1" in */*) echo "$1" ;; *) echo "$1/32" ;; esac; }

blocked_targets() {
    [ -f "$BLOCKLIST" ] || return 0
    grep -oE '^-A '"$CHAIN"' -s [^ ]+' "$BLOCKLIST" 2>/dev/null | awk '{print $4}' || true
}

cmd_status() {
    echo "Datei:  $BLOCKLIST ($( [ -f "$BLOCKLIST" ] && echo "$(blocked_targets | wc -l) Einträge" || echo 'fehlt' ))"
    echo "Kette:  $CHAIN ($(iptables -S "$CHAIN" 2>/dev/null | grep -c -- '-s ' || echo 0) Regeln aktiv)"
    echo -n "Sprung: "
    iptables -S ufw-user-input 2>/dev/null | grep -- "-j $CHAIN" || echo "FEHLT — die Kette wird nicht durchlaufen!"
    echo -n "Plugin: "
    [ -x /usr/share/netfilter-persistent/plugins.d/35-blocklist ] && echo "35-blocklist vorhanden" || echo "FEHLT"
    echo "Log:    $ACCESS_LOG ($( [ -r "$ACCESS_LOG" ] && wc -l < "$ACCESS_LOG" || echo '?' ) Zeilen)"
}

cmd_list() {
    local n=0
    while read -r t; do [ -n "$t" ] && { echo "  $t"; n=$((n+1)); }; done < <(blocked_targets)
    echo "($n Einträge in $BLOCKLIST)"
}

cmd_suggest() {
    local days=${1:-30}
    [ -r "$ACCESS_LOG" ] || { echo "Kein lesbares Zugriffslog: $ACCESS_LOG" >&2; exit 1; }

    local cutoff
    cutoff=$(date -d "-${days} days" +%Y%m%d 2>/dev/null) || { echo "Ungültige Tagesangabe: $days" >&2; exit 1; }

    local blocked tmp
    blocked=$(mktemp); tmp=$(mktemp)
    trap 'rm -f "$blocked" "$tmp"' RETURN
    blocked_targets | sed 's#/32$##' > "$blocked"

    # Zeitfenster schneiden. Der Vergleich läuft numerisch über YYYYMMDD, ohne einen
    # einzigen Subprozess — ein `date`-Aufruf pro Zeile wäre bei 55.000 Zeilen
    # unbenutzbar langsam.
    #
    # Kein Regex für das Datum: Auf Debian ist awk = mawk, und mawk kennt keine
    # Intervall-Ausdrücke ({2}, {3}, {4}). Ein Muster wie /[0-9]{2}\/[A-Za-z]{3}/
    # matcht dort nie — die Bedingung war dadurch stumm immer falsch. Im
    # combined-Format steht das Datum fest in Feld 4 ("[09/Sep/2026:10:06:53"),
    # das ist ohnehin schneller und portabel.
    awk -v cutoff="$cutoff" '
        substr($4, 1, 1) == "[" {
            d = substr($4, 2, 11)                          # 09/Sep/2026
            mon = index("JanFebMarAprMayJunJulAugSepOctNovDec", substr(d, 4, 3))
            if (mon == 0) next
            stamp = substr(d, 8, 4) sprintf("%02d", (mon + 2) / 3) substr(d, 1, 2)
            if (stamp + 0 >= cutoff + 0) print
        }' "$ACCESS_LOG" > "$tmp" 2>/dev/null || true

    # Fällt die Datumsauswertung aus (fremdes Logformat), lieber alles auswerten als
    # stillschweigend nichts zu melden — dann aber sagen, dass das Fenster nicht gilt.
    local window="letzte $days Tage"
    if [ ! -s "$tmp" ]; then
        if [ -s "$ACCESS_LOG" ]; then
            window="GESAMTES Log — Zeitfilter griff nicht, Datumsformat unerwartet"
            cp "$ACCESS_LOG" "$tmp"
        else
            window="Log ist leer"
        fi
    fi

    local own; own=$(own_hosts_re "$tmp")
    local hits; hits=$(mktemp); trap 'rm -f "$blocked" "$tmp" "$hits"' RETURN

    # Signal 1: Anfragepfade, die kein legitimer Client stellt.
    grep -aiE "\"[A-Z]+ [^ ]*$SCAN_PATHS" "$tmp" 2>/dev/null > "$hits" || true
    # Signal 2: absolute URL auf einen fremden Host (Suche nach offenem Proxy).
    grep -aiE '"[A-Z]+ https?://' "$tmp" 2>/dev/null | grep -avEi "\"[A-Z]+ https?://($own)" >> "$hits" || true

    echo "Kandidaten aus $ACCESS_LOG ($window)"
    echo "gesucht:        Scan-Pfade und Proxy-Anfragen auf fremde Hosts"
    echo "ausgeschlossen: private/lokale Netze, Suchmaschinen-Bots, bereits Gesperrte, eigene Hosts"
    echo

    local found=0
    while read -r count ip; do
        [ -z "$ip" ] && continue
        [[ $ip =~ $PRIVATE_NETS ]] && continue
        grep -qxF "$ip" "$blocked" && continue
        printf '  %-18s %5s Treffer\n' "$ip" "$count"
        grep -aF "$ip " "$hits" | sed -e 's/.*\] "/"/' -e 's/" [0-9]* .*//' \
            | sort | uniq -c | sort -rn | head -3 \
            | while read -r n req; do printf '  %-18s   %sx %s\n' "" "$n" "${req:0:100}"; done
        found=$((found+1))
    done < <(grep -aviE "$SEARCH_ENGINE_UA" "$hits" | awk '{print $1}' | sort | uniq -c | sort -rn | head -20)

    if [ "$found" -eq 0 ]; then
        echo "  Keine Kandidaten."
        echo
        echo "  Das ist der Normalfall für einen Host hinter einer Fritzbox mit zwei"
        echo "  freigegebenen Ports. Ein leeres Ergebnis heißt: nichts zu tun."
    else
        echo
        echo "Sperren mit: sudo $0 add <adresse>"
        echo "Vorher prüfen, ob die Adresse zu einem Vereinsmitglied gehören kann —"
        echo "der eigene DSL-Anschluss taucht im Log mit wechselnden Adressen auf."
    fi
}

# Schreibt die Datei und lädt sie dann. Nie umgekehrt, nie über
# `netfilter-persistent save` (siehe Kopfkommentar).
reload_rules() {
    if [ -x /usr/share/netfilter-persistent/plugins.d/35-blocklist ]; then
        netfilter-persistent reload >/dev/null
    else
        echo "Warnung: Plugin 35-blocklist fehlt — lade nur die Sperrliste." >&2
        iptables -N "$CHAIN" 2>/dev/null || true
        iptables -F "$CHAIN"
        iptables-restore -n < "$BLOCKLIST"
    fi
}

cmd_add() {
    local target; target=$(normalize "$1")
    valid_target "$1" || exit 1

    if blocked_targets | grep -qxF "$target"; then
        echo "$target ist bereits gesperrt."; return 0
    fi

    [ -f "$BLOCKLIST" ] || printf '*filter\nCOMMIT\n' > "$BLOCKLIST"
    cp "$BLOCKLIST" "$BLOCKLIST.bak"

    local rule="-A $CHAIN -s $target -j DROP"
    if grep -q '^COMMIT' "$BLOCKLIST"; then
        sed -i "0,/^COMMIT/s|^COMMIT|$rule\nCOMMIT|" "$BLOCKLIST"
    else
        echo "$rule" >> "$BLOCKLIST"
    fi
    chmod 0640 "$BLOCKLIST"

    reload_rules
    echo "gesperrt: $target ($(blocked_targets | wc -l) Einträge, vorherige Fassung in $BLOCKLIST.bak)"
}

cmd_remove() {
    local target; target=$(normalize "$1")
    [ -f "$BLOCKLIST" ] || { echo "$BLOCKLIST fehlt."; exit 1; }

    if ! blocked_targets | grep -qxF "$target"; then
        echo "$target steht nicht in der Sperrliste."; return 0
    fi

    cp "$BLOCKLIST" "$BLOCKLIST.bak"
    grep -vF -- "-A $CHAIN -s $target -j DROP" "$BLOCKLIST" > "$BLOCKLIST.tmp"
    mv "$BLOCKLIST.tmp" "$BLOCKLIST"
    chmod 0640 "$BLOCKLIST"

    reload_rules
    echo "entsperrt: $target ($(blocked_targets | wc -l) Einträge, vorherige Fassung in $BLOCKLIST.bak)"
}

case "${1:-}" in
    status)  require_root; cmd_status ;;
    list)    require_root; cmd_list ;;
    suggest) require_root; cmd_suggest "${2:-30}" ;;
    add)     require_root; [ -n "${2:-}" ] || { usage; exit 1; }; cmd_add "$2" ;;
    remove)  require_root; [ -n "${2:-}" ] || { usage; exit 1; }; cmd_remove "$2" ;;
    ""|-h|--help|help) usage ;;
    *) echo "Unbekannt: $1" >&2; usage; exit 1 ;;
esac
