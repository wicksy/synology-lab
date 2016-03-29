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

Quick and dirty script to run synctoS3.sh via docker and then run filebot (Synology package) to move any downloaded media to another location on another volume. They are renamed and stored in folders with appropaite names (based on filebot rules). Task run hourly via DSM task scheduler on the NAS.

##### synctoS3.sh

Short bash script (in lieu of a decent Python version) to sync media to an S3 bucket using AWS CLI. Will be re-written to use boto, etc when I get time. Run via docker with a volume mount so stored on a NAS volume for now. Will eventually be pulled down from a github repo by a stub script, which will effectively be told what to do (where to pull from, what to run, etc) via docker environment variables.

##### synctoS3.py.WIP

Work in Progress version of synctoS3.sh written in Python. Effectively does exactly the same as the bash script execpt using boto3 et al.
