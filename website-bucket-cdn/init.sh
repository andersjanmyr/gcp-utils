#!/bin/bash

set -o errexit

project=${project:-tapir}
sa=terrraform-sa

gsutil mb gs://tf-state-$project

gcloud iam service-accounts create $sa \
  --display-name $sa

user_id=$(gcloud iam service-accounts list | grep $sa | awk '{ print $2 }')
project_id=$(gcloud config get-value project)

gcloud projects add-iam-policy-binding $project_id \
  --member serviceAccount:$user_id \
  --role roles/editor


