#!/bin/sh -x

date
pkill Plex
synoservice --restart "pkgctl-Plex Media Server"
sleep 10
synoservice --status "pkgctl-Plex Media Server"
sleep 10
ps -ef | grep -i plex
date
curl -vi http://localhost:32400/web/index.html
exit 0