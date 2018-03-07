#!/bin/bash

aws s3 sync ./ s3://tc2-kubernetes/latest/ --profile=tc2-infra --exclude ".git/*" --exclude "$0" --delete
