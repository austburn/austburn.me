#!/bin/bash
if [ -n "$USE_S3" ]; then
    aws s3api get-object --bucket austburn.secrets --key secrets --region us-east-2 secrets
    source secrets
fi

if [ -n "$USE_RDS" ]; then
    export POSTGRES_ENDPOINT=$(aws rds describe-db-instances --region us-east-2 |  awk '/"Address":/ {split($0, x, ":"); print gensub(/ |\"/, "", "g",  x[2])}')
fi

exec "$@"
