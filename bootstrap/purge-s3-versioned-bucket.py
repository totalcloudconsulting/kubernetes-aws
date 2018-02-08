#!/usr/bin/env python2.7

import boto3
import os
import sys
import time

bucket=sys.argv[1]
region=sys.argv[2]

print "DELETE BUCKET: "+bucket
print time.ctime()

session = boto3.Session(region_name=region)
s3 = session.resource(service_name='s3')
bucket = s3.Bucket(bucket)
bucket.object_versions.delete()
bucket.delete()

print time.ctime()
print "DONE."

sys.exit(0)
