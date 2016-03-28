#!/bin/bash

# Variables expected to be passed in here:
#
# DSM_SECRETS (Executable bash setting variables for secrets e.g. AWS keys)
# DSM_MEDIA_SOURCE_DIR (Where to search for files to sync up to S3)
# DSM_MEDIA_S3_BUCKET (What S3 bucket to sync files up to)
# DSM_MEDIA_FILES (The filespecs to search for e.g. Movie*.mp4)
#
# Designed to work with https://github.com/wicksy/docker-lab/blob/master/synology/docker/py/synology-task-wrapper.py

source "${DSM_SECRETS}"

source=${DSM_MEDIA_SOURCE_DIR}
bucket=${DSM_MEDIA_S3_BUCKET}

finished="/tmp/Downloads/FINISHED.$(date '+%A')"
pid=$$
email="/tmp/Downloads/EMAIL"

for files in ${DSM_MEDIA_FILES}
do
  rc=1
  while [[ ${rc} -ne 0 ]]
  do
    echo "Syncing: ${files}"
    aws s3 sync "${source}" "${bucket}" --sse --exclude "*" --include "${files}"
    rc=$?
    if [[ ${rc} -ne 0 ]] ; then
      sleep 30
    fi
  done

  (cat "${finished}" ; find "${source}" -name "${files}" -exec ls -ld {} \;) | sort -u > "${finished}.${pid}"
  mv -f "${finished}.${pid}" "${finished}"
  for filenames in $(find "${source}" -name "${files}")
  do
    filename=$(basename "${filenames}")
    content="Uploaded ${filename}"
    echo "${content}" >> "${email}"
  done

done

if [[ -f "${finished}" ]] ; then
  if [[ ! -s "${finished}" ]] ; then
    rm -f "${finished}"
  else
    aws s3 cp "${finished}" "${bucket}" --sse
  fi
fi

find "${source}" -type f -name 'FINISHED\.*' -mtime +3 -delete
exit 0
