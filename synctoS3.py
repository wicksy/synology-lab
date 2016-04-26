#!/usr/bin/env python
#
# Python version of synctoS3.sh (https://github.com/wicksy/synology-lab/blob/master/synctoS3.sh)
#
# Expects a number of environment variables to be set by the caller:
#
# DSM_SECRETS (Secrets defined as variables and set via execfile())
# DSM_MEDIA_SOURCE_DIR (Where to search for files to sync up to S3)
# DSM_MEDIA_S3_BUCKET (What S3 bucket to sync files up to)
# DSM_MEDIA_FILES (The filespecs to search for e.g. Movie*.mp4)
#
# Tested with:
#
# Synology DS415+
# DSM 5.2-5644 Update 3
# Docker 1.6.2-0036 (on DSM)
# Gitlab 8.2.3-0015 (on DSM)
#
# It is recommened that the repository containing secrets is kept private for obvious reasons. For example, hosted
# by Gitlab running on the same NAS.
#

# Imports
#
import boto3
import glob
import math
import os
import shutil
import subprocess
import sys
from filechunkio import FileChunkIO

# Functions
#

# Clean up and exit
#
def die(code):

  print("Cleaning up")
  print("Exit with code " + str(code))
  sys.exit(code)

# Make a directory
#
def ensure_dir(MKDIR):
  DIR = os.path.dirname(MKDIR)
  if not os.path.exists(DIR):
    os.makedirs(DIR)

# Test for debug switch
#
try:
  ARG = sys.argv[1]
except:
  ARG = ""

if ARG == '-d':
  DEBUG=True
else:
  DEBUG=False

# Get and set variables
#
DSM_SECRETS = str(os.environ.get('DSM_SECRETS'))
DSM_MEDIA_SOURCE_DIR = str(os.environ.get('DSM_MEDIA_SOURCE_DIR'))
DSM_MEDIA_S3_BUCKET = str(os.environ.get('DSM_MEDIA_S3_BUCKET'))
DSM_MEDIA_FILES = str(os.environ.get('DSM_MEDIA_FILES'))
CHUNK_SIZE = 10485760

# Exit codes
#
EXIT_ALL_OK = 0
EXIT_NO_SECRETS = 100
EXIT_SECRETS_FAIL = 110
EXIT_BOTO3_CLIENT = 120
EXIT_NO_SOURCE_DIR = 130
EXIT_BAD_SOURCE_DIR = 140
EXIT_NO_MEDIA_FILES = 150
EXIT_CREATE_MP_UPLOAD = 160
EXIT_UPLOAD_PART_FAIL = 170
EXIT_CHUNK_ERROR = 180

# Get involved! Check mandatory variables have values and exit if not.
#
if DSM_SECRETS != 'None' and DSM_SECRETS.strip():
  print("Secrets stored in: " + DSM_SECRETS)
else:
  print("No secrets file specified")
  die(EXIT_NO_SECRETS)

if DSM_MEDIA_SOURCE_DIR != 'None' and DSM_MEDIA_SOURCE_DIR.strip():
  print("Source directory to search: " + DSM_MEDIA_SOURCE_DIR)
else:
  print("No source directory specified")
  die(EXIT_NO_SOURCE_DIR)

if DSM_MEDIA_FILES != 'None' and DSM_MEDIA_FILES.strip():
  print("Media filespecs to search for: " + DSM_MEDIA_FILES)
else:
  print("No media files specified")
  die(EXIT_NO_MEDIA_FILES)

# Set Secrets
#
print("Setting Secrets from " + DSM_SECRETS)
try:
  execfile(DSM_SECRETS)
except:
  print("Error setting Secrets")
  die(EXIT_SECRETS_FAIL)

# Check to see if DSM_MEDIA_SOURCE_DIR exists and exit if not
#
if not os.path.exists(DSM_MEDIA_SOURCE_DIR):
  print("Error cannot find directory " + DSM_MEDIA_SOURCE_DIR)
  die(EXIT_BAD_SOURCE_DIR)

# Try and start an S3 boto3 session
#
print("Starting boto3 session to S3 bucket " + DSM_MEDIA_S3_BUCKET)
try:
  client = boto3.client(
    's3',
    aws_access_key_id=AWS_ACCESS_KEY_ID,
    aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
    region_name=AWS_DEFAULT_REGION
  )
except:
  print("Error starting S3 boto3 session")
  die(EXIT_BOTO3_CLIENT)

try:
  response = client.list_objects(
    Bucket=DSM_MEDIA_S3_BUCKET
  )
except:
  print("Error listing objects in S3 bucket")
  die(EXIT_BOTO3_CLIENT)

# For each filespec
#
print("Chunking files in " + str(CHUNK_SIZE) + " byte parts")
filespecs = DSM_MEDIA_FILES.split()
to_process = []
for filespec in filespecs:

# Search for files to process
#
  for root, directories, filenames in os.walk(DSM_MEDIA_SOURCE_DIR):
    for directory in directories:
      thisdir = os.path.join(root, directory)
      spec = thisdir + "/" + filespec
      to_process += glob.glob(spec)
      if DEBUG:
        print("DEBUG: File spec " + str(spec))
        print("DEBUG: To Process " + str(to_process))
  to_process += glob.glob(DSM_MEDIA_SOURCE_DIR + "/" + filespec)
  if DEBUG:
    print("DEBUG: Full list to process " + str(to_process))

# Process each file
#
for uploadfile in to_process:
  print("Processing file: " + uploadfile)
  source_size = os.stat(uploadfile).st_size
  chunk_count = int(math.ceil(source_size / float(CHUNK_SIZE)))
  uploadkey = os.path.basename(uploadfile)
  parts_info = []
  if DEBUG:
    print("DEBUG: Source size " + str(source_size))
    print("DEBUG: Chunk count " + str(chunk_count))
    print("DEBUG: Uploadkey " + str(uploadkey))

# Create MultiPart Upload
#
  try:
    mpu = client.create_multipart_upload(
      Bucket=DSM_MEDIA_S3_BUCKET,
      Key=uploadkey,
      ServerSideEncryption='AES256'
    )
  except:
    print("Error creating multipart upload for " + uploadfile)
    die(EXIT_CREATE_MP_UPLOAD)

# Process source file in chunks uploading each as a part of
# a multipart upload (and abort on exception)
#
  try:
    for count in range(chunk_count):
      print("Uploading part " + str(count+1))
      offset = CHUNK_SIZE * count
      bytes = min(CHUNK_SIZE, source_size - offset)
      if DEBUG:
        print("DEBUG: Offset " + str(offset))
        print("DEBUG: bytes " + str(bytes))
      with FileChunkIO(uploadfile, 'r', offset=offset, bytes=bytes) as fp:
        try:
          body = fp.read()
          part = client.upload_part(
            Body=body,
            Bucket=DSM_MEDIA_S3_BUCKET,
            Key=uploadkey,
            PartNumber=count+1,
            UploadId=mpu['UploadId']
          )
          if DEBUG:
            print("DEBUG: Part output " + str(part))
        except:
          print("Error uploading part " + str(count+1) + " of file")
          print("Aborting upload")
          client.abort_multipart_upload(
            Bucket=DSM_MEDIA_S3_BUCKET,
            Key=uploadkey,
            UploadId=mpu['UploadId']
          )
          die(EXIT_UPLOAD_PART_FAIL)

        partinfo = {'PartNumber': count+1, 'ETag': part['ETag']}
        if DEBUG:
          print("DEBUG: Part Info " + str(partinfo))
        parts_info.append(partinfo)

# Problems chunking the file so abort the upload
#
  except:
    print("Error Chunking file " + uploadfile)
    print("Aborting upload")
    client.abort_multipart_upload(
      Bucket=DSM_MEDIA_S3_BUCKET,
      Key=uploadkey,
      UploadId=mpu['UploadId']
    )
    die(EXIT_CHUNK_ERROR)

# Set multipart part info and complete upload
#
  part_info = {
    'Parts': parts_info
  }
  if DEBUG:
    print("DEBUG: Parts Info " + str(part_info))

  client.complete_multipart_upload(
    Bucket=DSM_MEDIA_S3_BUCKET,
    Key=uploadkey,
    UploadId=mpu['UploadId'],
    MultipartUpload=part_info
  )

# Fin!
#
die(EXIT_ALL_OK)
