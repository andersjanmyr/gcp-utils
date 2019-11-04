provider "google" {
  project = "ingka-devops-anderslab-dev"
  region  = "europe-west1"
  zone    = "europe-west1-d"
}

provider "google-beta" {
  project = "ingka-devops-anderslab-dev"
  region  = "europe-west1"
  zone    = "europe-west1-d"
}


variable "name" {
  default = "tapir"
}

variable "domain" {
  default = "ingka.janmyr.com"
}

variable "dns_zone" {
  default = "ingka-janmyr-com"
}

resource "google_storage_bucket" "bucket" {
  name = var.name
  location = "EU"
  bucket_policy_only = true
  force_destroy = true

  website {
    main_page_suffix = "index.html"
    not_found_page = "404.html"
  }
}

resource "google_storage_bucket_object" "index" {
  bucket = "${google_storage_bucket.bucket.name}"
  name   = "index.html"
  source = "./index.html"
}

resource "google_storage_bucket_iam_binding" "binding" {
  bucket = "${google_storage_bucket.bucket.name}"
  role = "roles/storage.objectViewer"

  members = [
    "allUsers",
  ]
}

resource "google_compute_backend_bucket" "backend_bucket" {
  name = "${var.name}-bb"
  bucket_name = "${google_storage_bucket.bucket.name}"
  enable_cdn = true
}

resource "google_compute_global_address" "ga" {
  name = "${var.name}-ip"
}

resource "google_dns_record_set" "dns_record" {
  name = "${var.name}.${var.domain}."
  type = "A"
  ttl = 300
  managed_zone= var.dns_zone
  rrdatas = ["${google_compute_global_address.ga.address}"]
}

resource "google_compute_managed_ssl_certificate" "cert" {
  provider = "google-beta"
  name = "${var.name}-cert"
  managed {
    domains = ["${var.name}.${var.domain}"]
  }
}

resource "google_compute_url_map" "url_map" {
  provider = "google-beta"
  name = "${var.name}-map"
  default_service = "${google_compute_backend_bucket.backend_bucket.self_link}"
}

resource "google_compute_target_https_proxy" "proxy" {
  provider = "google-beta"
  name="${var.name}-proxy"
  url_map = "${google_compute_url_map.url_map.self_link}"
  ssl_certificates = ["${google_compute_managed_ssl_certificate.cert.self_link}"]
}

resource "google_compute_global_forwarding_rule" "rule" {
  provider = "google-beta"
  name = "${var.name}-forwarding-rule"
  ip_address = "${google_compute_global_address.ga.address}"
  target = "${google_compute_target_https_proxy.proxy.self_link}"
  port_range = "443"

}
