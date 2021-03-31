provider "google" {
  project     = "korniienkoproject"
  region      = "europe-west1"
}

resource "google_compute_network" "nat-example" {
  name = "nat-example"
  mtu = 1460
  routing_mode = "REGIONAL"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "some-subnet" {
  name          = "test-subnetwork"
  ip_cidr_range = "10.0.1.0/24"
  region        = "europe-west1"
  network       = google_compute_network.nat-example.name
}

resource "google_compute_firewall" "allow-internal-example" {
  name    = "test-firewall1"
  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["1-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["1-65535"]
  }
  source_ranges = ["10.0.1.0/24"]
  network = google_compute_network.nat-example.name
  priority = "65534"
}

resource "google_compute_firewall" "allow-ssh-iap" {
  name    = "test-firewall2"
  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
  target_tags = ["allow-ssh"]
  network = google_compute_network.nat-example.name
}

resource "google_compute_instance" "example-instance" {
  name         = "test-instance1"
  machine_type = "f1-micro"
  zone         = "europe-west1-d"
  tags = ["no-ip", "allow-ssh"]

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.some-subnet.name
    access_config {
      // Ephemeral IP
    }
  }
}

resource "google_compute_instance" "nat-gateway" {
  name         = "test-instance2"
  machine_type = "f1-micro"
  zone         = "europe-west1-d"
  tags = ["nat", "allow-ssh"]

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.some-subnet.name
    access_config {
      // Ephemeral IP
    }
  }
  metadata_startup_script = file("data.sh")
  can_ip_forward = true
}

resource "google_compute_route" "no-ip-internet-route" {
  name        = "network-route"
  dest_range  = "0.0.0.0/0"
  network = google_compute_network.nat-example.name
  next_hop_instance = "test-instance2"
  next_hop_instance_zone = "europe-west1-d" 
  tags = ["no-ip"]
  priority    = 800
}
