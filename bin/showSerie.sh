#!/usr/bin/env bash
curl 'https://e12112e2454d41f1824088919da39bc0.club-cloud.de/admin/einzel/serie/showSerie.php?' \
  -H 'authority: e12112e2454d41f1824088919da39bc0.club-cloud.de' \
  -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9' \
  -H 'accept-language: de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7,fr;q=0.6' \
  -H 'cache-control: max-age=0' \
  -H 'content-type: application/x-www-form-urlencoded' \
  -H 'cookie: PHPSESSID=4089268326674d03f6909ec5f73d05af' \
  -H 'origin: https://e12112e2454d41f1824088919da39bc0.club-cloud.de' \
  -H 'referer: https://e12112e2454d41f1824088919da39bc0.club-cloud.de/admin/einzel/serie/showSerienList.php?branchId=%{BRANCH_ID}&fedId=%{FED_ID}&season=%{SEASON}&' \
  -H 'sec-ch-ua: "Google Chrome";v="105", "Not)A;Brand";v="8", "Chromium";v="105"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "macOS"' \
  -H 'sec-fetch-dest: document' \
  -H 'sec-fetch-mode: navigate' \
  -H 'sec-fetch-site: same-origin' \
  -H 'sec-fetch-user: ?1' \
  -H 'upgrade-insecure-requests: 1' \
  -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.0.0 Safari/537.36' \
  --data-raw 'fedId=%{FED_ID}&branchId=%{BRANCH_ID}&season=%{SEASON_R}&serienId=%{SERIEN_ID}' \
  --compressed

