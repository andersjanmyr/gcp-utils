#!/bin/bash

set -o errexit

name=${NAME:-anders-ingka}
domain=${DNS:-ingka.janmyr.com}
dns_zone=${ZONE:-${domain//./-}}
echo "Name: $name"
echo "Domain: $domain"
echo "Zone: $dns_zone"

main() {
  delete_frontend
  delete_backend_bucket
  delete_bucket
}

delete_frontend() {
  # Delete forwarding rule
  gcloud compute forwarding-rules delete ${name}-forwarding-rule --global

  # Delete https proxy
  gcloud compute target-https-proxies delete ${name}-proxy

  # Delete url-map
  gcloud compute url-maps delete ${name}-map

  # Delete Managed SSL Cert
  gcloud beta compute ssl-certificates delete ${name}-cert --global

  # Delete DNS Records
  ip=$(gcloud compute addresses describe ${name}-ip --global | grep 'address:' | awk '{ print $2}')

  gcloud dns record-sets transaction start --zone=$dns_zone
  gcloud dns record-sets transaction remove $ip \
    --ttl=300 --type=A \
    --name="${name}.${domain}." \
    --zone=$dns_zone

  # CAA record needs to be on the root domain, subdomain doesn't work.
  read -p "Delete CAA record? (Y/N): " confirm
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    gcloud dns record-sets transaction remove \
      '0 issue "letsencrypt.org"' \
      '0 issue "pki.goog"' \
      --ttl=300 --type=CAA \
      --name="${domain}." \
      --zone=$dns_zone
  fi
  gcloud dns record-sets transaction execute --zone=$dns_zone

  # Delete IP
  gcloud compute addresses delete ${name}-ip --global
}

delete_backend_bucket() {
  gcloud compute backend-buckets delete ${name}-bb
}

delete_bucket() {
  gsutil rm -r gs://$name/
}

main
