#!/bin/bash

set -o errexit

name=${NAME:-anders-ingka}
domain=${DNS:-ingka.janmyr.com}
dns_zone=${ZONE:-${domain//./-}}
echo "Name: $name"
echo "Domain: $domain"
echo "Zone: $dns_zone"

main() {
  create_bucket
  upload_file
  create_backend_bucket
  create_frontend
}

create_bucket() {
  gsutil mb  -l eu gs://$name/
  gsutil acl set public-read gs://$name
  gsutil acl get gs://$name/
}

upload_file() {
  gsutil cp -a public-read index.html gs://$name/index.html
  gsutil setmeta -h "Cache-Control:public, max-age=60, s-maxage=300" \
    gs://$name/index.html

}

create_backend_bucket() {
  gcloud compute backend-buckets create ${name}-bb \
    --gcs-bucket-name $name \
    --enable-cdn
}

create_frontend() {
  # Create IP
  gcloud compute addresses create ${name}-ip --global
  ip=$(gcloud compute addresses describe ${name}-ip --global | grep 'address:' | awk '{ print $2}')

  # Create DNS Records
  gcloud dns record-sets transaction start --zone=$dns_zone
  gcloud dns record-sets transaction add $ip \
    --ttl=300 --type=A \
    --name="${name}.${domain}." \
    --zone=$dns_zone

  # CAA record needs to be on the root domain, subdomain doesn't work.
  read -p "Create CAA record? (Y/N): " confirm
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    gcloud dns record-sets transaction add \
      '0 issue "letsencrypt.org"' \
      '0 issue "pki.goog"' \
      --ttl=300 --type=CAA \
      --name="${domain}." \
      --zone=$dns_zone
  fi
  gcloud dns record-sets transaction execute --zone=$dns_zone

  # Create Managed SSL Cert
  gcloud beta compute ssl-certificates create ${name}-cert \
    --global --domains ${name}.${domain}

  # Map url to backend-bucket by default
  gcloud compute url-maps create ${name}-map \
    --default-backend-bucket=${name}-bb

  # Create https proxy and associate it with map and ssl cert
  gcloud compute target-https-proxies create ${name}-proxy \
    --url-map ${name}-map \
    --ssl-certificates ${name}-cert

  # Create forwarding rule for the proxy
  gcloud compute forwarding-rules create ${name}-forwarding-rule \
    --address=${name}-ip \
    --global \
    --target-https-proxy=${name}-proxy \
    --ports=443
}

main
