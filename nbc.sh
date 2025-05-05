#!/bin/bash

set -xeuo pipefail

# system packages
dnf install -y gcc libxml2-devel libxslt-devel libffi-devel libpq-devel openssl-devel redhat-rpm-config

# postgresql
dnf install -y postgresql17-server
postgresql-setup --initdb
sed -i 's/^host\s\+all\s\+all\s\+\(.*\)\sident/host\tall\t\tall\t\t\1 md5/' /var/lib/pgsql/data/pg_hba.conf 
systemctl enable --now postgresql
sudo -u postgres psql -U postgres -c "CREATE DATABASE netbox;"
sudo -u postgres psql -U postgres -c "CREATE USER netbox WITH PASSWORD 'box_of_nets';"
sudo -u postgres psql -U postgres -c "ALTER DATABASE netbox OWNER TO netbox;"
sudo -u postgres psql -U postgres -d netbox -c "GRANT CREATE ON SCHEMA public TO netbox;"

# redis
dnf install -y redis6
systemctl enable --now redis6

# python > 3.10
dnf install -y python3.12 python3.12-devel

# netbox
mkdir -p /opt/netbox/
cd /opt/netbox/
dnf install -y git
git clone https://github.com/netbox-community/netbox.git .
git checkout v4.2.7
groupadd --system netbox
adduser --system -g netbox netbox
chown --recursive netbox /opt/netbox/netbox/media/
chown --recursive netbox /opt/netbox/netbox/reports/
chown --recursive netbox /opt/netbox/netbox/scripts/
cd /opt/netbox/netbox/netbox/
cp configuration_example.py configuration.py
sed -i "s/^ALLOWED_HOSTS = \[\]/ALLOWED_HOSTS = \['\*'\]/" configuration.py
sed -i "s/'USER': '',\s*# PostgreSQL username/'USER': 'netbox',\t      # PostgreSQL username/" configuration.py
sed -i "s/'PASSWORD': '',\s*# PostgreSQL password/'PASSWORD': 'box_of_nets',# PostgreSQL username/" configuration.py
sed -i "s/^SECRET_KEY = ''/SECRET_KEY = '12345678901234567890123456789012345678901234567890'/" configuration.py
PYTHON=/usr/bin/python3.12 /opt/netbox/upgrade.sh
source /opt/netbox/venv/bin/activate
cd /opt/netbox/netbox
python3 manage.py createsuperuser --noinput --username admin --email ''
python3 manage.py shell -c "from users.models import User; u = User.objects.get(username='admin'); u.set_password('admin'); u.save()"
sudo ln -s /opt/netbox/contrib/netbox-housekeeping.sh /etc/cron.daily/netbox-housekeeping

# gunicorn
cp /opt/netbox/contrib/gunicorn.py /opt/netbox/gunicorn.py
cp /opt/netbox/contrib/*.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now netbox netbox-rq

# nginx
mkdir /etc/ssl/private
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/netbox.key -out /etc/ssl/certs/netbox.crt -subj "/C=US/ST=State/L=City/O=Organization/CN=netbox"
dnf install -y nginx
head -n -7 /opt/netbox/contrib/nginx.conf > /etc/nginx/conf.d/netbox.conf
TOKEN="$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" -s)"
PUBIP="$(curl -H "X-aws-ec2-metadata-token: ${TOKEN}" 'http://169.254.169.254/latest/meta-data/public-ipv4' -s)"
sed -i "s/netbox.example.com/${PUBIP}/" /etc/nginx/conf.d/netbox.conf
systemctl restart nginx

# demo data
systemctl stop netbox
sudo -u postgres psql -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'netbox';"
sudo -u postgres psql -c "DROP database netbox;"
sudo -u postgres psql -c "CREATE database netbox;"
wget https://raw.githubusercontent.com/netbox-community/netbox-demo-data/refs/heads/master/sql/netbox-demo-v4.2.sql
sudo -u postgres psql netbox < netbox-demo-v4.2.sql
systemctl start netbox
