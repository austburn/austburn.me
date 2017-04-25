#!/bin/bash
if [ -n $PULL_S3 ]; then
    aws s3api get-object --bucket austburn.secrets --key secrets --region us-east-2 secrets
    source secrets
fi

exec "$@"
