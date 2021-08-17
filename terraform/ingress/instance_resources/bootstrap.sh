#!/bin/sh

# Sets up Traefik in a new standalone VM, written based on the works from the following:
# https://gist.github.com/ubergesundheit/7c9d875befc2d7bfd0bf43d8b3862d85
# https://github.com/traefik/traefik/blob/master/contrib/systemd/traefik.service

# Installs traefik binary
curl https://github.com/traefik/traefik/releases/download/${traefik_version}/traefik_${traefik_version}_linux_amd64.tar.gz -L -o traefik_${traefik_version}_linux_amd64.tar.gz
tar zxvf traefik_${traefik_version}_linux_amd64.tar.gz

sudo cp traefik /usr/local/bin
sudo chown root:root /usr/local/bin/traefik
sudo chmod 755 /usr/local/bin/traefik

# Give traefik privilege to bind on lower ports
sudo setcap 'cap_net_bind_service=+ep' /usr/local/bin/traefik

# Creat otherwise-unprivileged users for traefik
sudo groupadd -g 321 traefik
sudo useradd \
  -g traefik --no-user-group \
  --home-dir /var/www --no-create-home \
  --shell /usr/sbin/nologin \
  --system --uid 321 traefik

# Sets up required directories for traefik to log and perform ACME verifications
sudo mkdir /etc/traefik
sudo mkdir /etc/traefik/acme
sudo mkdir /etc/traefik/logs
sudo chown -R root:root /etc/traefik
sudo chown -R traefik:traefik /etc/traefik/acme
sudo chown -R traefik:traefik /etc/traefik/logs
sudo touch /etc/traefik/acme/acme.json
sudo chown traefik:traefik /etc/traefik/acme/acme.json
sudo chmod 600 /etc/traefik/acme/acme.json

# Sets up traefik's config and middleware files
sudo echo "${traefik_config_file}" | base64 --decode > /etc/traefik/traefik.yaml
sudo chown root:root /etc/traefik/traefik.yaml
sudo chmod 644 /etc/traefik/traefik.yaml

sudo echo "${traefik_middlewares_file}" | base64 --decode > /etc/traefik/middlewares.yaml
sudo chown root:root /etc/traefik/middlewares.yaml
sudo chmod 644 /etc/traefik/middlewares.yaml

# Loads the cluster's CA certificate into the ingress instance's truststore
sudo echo "${gke_control_plane_ca}" | base64 --decode > /etc/ssl/certs/k8s.crt
sudo chown root:root /etc/ssl/certs/k8s.crt
sudo chmod 644 /etc/ssl/certs/k8s.crt
sudo update-ca-certificates

# Sets up traefik's log files
sudo touch /etc/traefik/logs/traefik.log
sudo chown traefik:traefik /etc/traefik/logs/traefik.log
sudo chmod 644 /etc/traefik/logs/traefik.log
sudo ln -s /etc/traefik/logs/traefik.log /var/log/traefik.log
sudo touch /etc/traefik/logs/access.log
sudo chown traefik:traefik /etc/traefik/logs/access.log
sudo chmod 644 /etc/traefik/logs/access.log
sudo ln -s /etc/traefik/logs/access.log /var/log/access.log

# Sets up Traefik's systemd service config and starts it
sudo echo "${traefik_service_file}" | base64 --decode > /etc/systemd/system/traefik.service
sudo chown root:root /etc/systemd/system/traefik.service
sudo chmod 644 /etc/systemd/system/traefik.service
sudo systemctl daemon-reload
sudo systemctl start traefik.service
sudo systemctl enable traefik.service