#!/bin/bash

export AWS_ACCESS_KEY_ID="REDACTED"
export AWS_SECRET_ACCESS_KEY="REDACTED"
export AWS_DEFAULT_REGION="eu-west-1"

media="*foo*.mp4 *bar*.mp4"
source="/tmp/Downloads/"
bucket="s3://bucket-name/automated/"
finished="/tmp/Downloads/FINISHED"
rm -f ${finished}

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
  find "${source}" -name "${files}" -exec ls -ld {} \; >> ${finished}
done
if [[ ! -s ${finished} ]] ; then
  rm -f ${finished}
else
  aws s3 cp "${finished}" "${bucket}" --sse
fi
exit 0
