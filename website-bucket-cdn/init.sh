#!/bin/bash

set -o errexit

project=${project:-tapir}
sa=terrraform-sa
bucket=gs://tf-state-$project
tmp_policy=./tmp-policy.json

project_id=$(gcloud config get-value project)
gcloud projects get-iam-policy $project_id > $tmp_policy
cat <<-EOT >> $tmp_policy
auditConfigs:
- auditLogConfigs:
  - logType: ADMIN_READ
  - logType: DATA_WRITE
  - logType: DATA_READ
  service: allServices
EOT
gcloud projects set-iam-policy $project_id $tmp_policy
rm $tmp_policy

gsutil mb $bucket
gsutil versioning set on $bucket

gcloud iam service-accounts create $sa \
  --display-name $sa

user_id=$(gcloud iam service-accounts list | grep $sa | awk '{ print $2 }')

gcloud projects add-iam-policy-binding $project_id \
  --member serviceAccount:$user_id \
  --role roles/editor

