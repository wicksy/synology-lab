### Tools for my Synology NAS (DS415+)

Usually run inside my wicksy/synology Docker container (based on Alpine Linux), which contains some tooling:

- git
- vim
- curl
- wget
- bash
- python
- pip
- awscli
- boto
- boto3

##### filebotme.sh

Script that runs a docker container [(wicksy/synology)](https://github.com/wicksy/docker-lab/tree/master/synology) that fires off a task wrapper to run synctoS3.py (see below) to upload selected media to an AWS S3 bucket. It then cleans up old docker exited containers and dangling images before running the [filebot](http://www.filebot.net/) package (on the NAS) to rename media files and move into folders with appropriate names (based on filebot rules). Finally it cleans up the source area of any unprocessed files (usually duplicates so ignored by filebot). Task runs hourly via DSM task scheduler on the NAS.

##### synctoS3.sh

<p align="justify">
Simple bash script (in lieu of a decent Python version) to sync media to an S3 bucket using AWS CLI. Eventually re-written in python to use boto (see below). Run via docker with a volume mount.
</p>

##### synctoS3.py

<p align="justify">
Python version of synctoS3.sh using boto3, multipart upload, etc. Designed to be pulled in automatically from this repository by a [task wrapper](https://github.com/wicksy/docker-lab/blob/master/synology/docker/py/synology-task-wrapper.py) running inside of a [docker container](https://github.com/wicksy/docker-lab/tree/master/synology) designed to run on the (Synology) NAS.
</p>

