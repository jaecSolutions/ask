#!/usr/bin/env bash
 
CMD=$1
ENV=$2
AWS_KEY=$3
AWS_SECRET=$4
CLOUDFLARE_TOKEN=$5

aws configure set aws_access_key_id $3
aws configure set aws_secret_access_key $4
aws configure set region ca-central-1

if [ "$1" == "init" ]; then
    terraform init -backend-config=./configs/${ENV}/backend.tfvars --reconfigure
else
    export TF_VAR_cloudflare_token=$5
    terraform $CMD -var-file=./configs/${ENV}/input.tfvars
fi