#!/bin/sh -x

# Email info
#
addressees="user@email.com anotheruser@email.com"
subject="Subject of email here"

# Copy selected files to S3 bucket
#
cd /tmp
docker run --env-file=/usr/local/etc/synctoS3.env --volume=/volume1/Downloads/:/tmp/Downloads/ wicksy/synology:latest /scripts/synology-task-wrapper.py > /tmp/synctos3.log 2>&1
chmod 600 /tmp/synctos3.log

# Look for any files uploaded to S3 in the log and create email content from any
#
if [[ "$(grep -c 'Processing file: .*' /tmp/synctos3.log)" -gt 0 ]]; then
  content="$(grep 'Processing file: .*' /tmp/synctos3.log)"
  echo "${content}" > /volume1/Downloads/EMAIL
fi

# If something has been uploaded send an email about it
#
if [[ -s /volume1/Downloads/EMAIL ]] ; then
  content="$(cat /volume1/Downloads/EMAIL)"
  for emailto in ${addressees}
  do
    cmd="/usr/bin/php -r \"mail('${emailto}','${subject}','${content}');\""
    eval ${cmd}
  done
  rm -f /volume1/Downloads/EMAIL
fi

# Tidy up old docker containers (that have exited)
#
for container in $(docker ps -a | egrep -v '(second|minute|hour)' | awk '/wicksy\/synology:/ {print $1}')
do
  echo docker rm -fv ${container}
  docker rm -fv ${container}
done

# Tidy up orphans
#
for dangling in $(docker images -q -f "dangling=true")
do
  docker rmi -f ${dangling}
done

# Move any video files to proper named folders, rename episodes, etc
#
/usr/local/bin/filebot -script 'fn:amc' /volume1/Downloads/ --output '/volume1/Media/Not Watched Yet' --action move -non-strict --conflict auto --lang en --def 'music=y' 'unsorted=y' 'clean=y' 'deleteAfterExtract=y' 'excludeList=.excludes' --log info --log-file '/volume3/@appstore/filebot-node/filebot.log' >> '/volume3/@appstore/filebot-node/log/1441471372245.log' 2>&1

# Anything left move away so this script keeps trying to process it during subsequent calls
#
for unmoved in $(find /volume1/Downloads/ -type f -name '*.mp4' -o -name '*.avi' -o -name '*.mkv')
do
  echo ${unmoved}
  mv -f "${unmoved}" "/volume1/Media/Not Watched Yet/Unsorted/"
  rmdir "$(dirname ${unmoved})"
done

exit 0
