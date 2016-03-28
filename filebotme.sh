#!/bin/sh -x

addressees="user@email.com anotheruser@email.com"
subject="Subject of email here"

cd /tmp
docker run --env-file=/usr/local/etc/synctoS3.env --volume=/volume1/Downloads/:/tmp/Downloads/ wicksy/synology:latest /scripts/synology-task-wrapper.py > /tmp/synctos3.log 2>&1
chmod 600 /tmp/synctos3.log

if [[ -s /volume1/Downloads/EMAIL ]] ; then
  content="$(cat /volume1/Downloads/EMAIL)"
  for emailto in ${addressees}
  do
    cmd="/usr/bin/php -r \"mail('${emailto}','${subject}','${content}');\""
    eval ${cmd}
  done
  rm -f /volume1/Downloads/EMAIL
fi

for container in $(docker ps -a | egrep -v '(seconds|minutes|hours)' | awk '/wicksy\/synology:/ {print $1}')
do
  echo docker rm -fv ${container}
  docker rm -fv ${container}
done

/usr/local/bin/filebot -script 'fn:amc' /volume1/Downloads/ --output '/volume1/Media/Not Watched Yet' --action move -non-strict --conflict auto --lang en --def 'music=y' 'unsorted=y' 'clean=y' 'deleteAfterExtract=y' 'excludeList=.excludes' --log info --log-file '/volume3/@appstore/filebot-node/filebot.log' >> '/volume3/@appstore/filebot-node/log/1441471372245.log' 2>&1

exit 0
