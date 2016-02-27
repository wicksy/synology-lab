#!/bin/bash

export AWS_ACCESS_KEY_ID="REDACTED"
export AWS_SECRET_ACCESS_KEY="REDACTED"
export AWS_DEFAULT_REGION="eu-west-1"

media="*foo*.mp4 *bar*.mp4"
source="/tmp/Downloads/"
bucket="s3://bucket-name/automated/"

finished="/tmp/Downloads/FINISHED.$(date '+%A')"
pid=$$
email="/tmp/Downloads/EMAIL"

for files in ${media}
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
