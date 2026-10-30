#!/bin/bash
# Build the bookshop server from nothing: everything Lessons 5 to 13 did by hand.
# Safe to run again: each step checks first, and only changes what's different.
set -euo pipefail

FILES=/setup/files
LOG=/var/log/bookshop-setup.log
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a

[ "$(id -u)" -eq 0 ] || { echo "setup.sh: run me as root" >&2; exit 1; }

step() { echo; echo "==> $*"; }

die() { echo "setup.sh: $*" >&2; exit 1; }

# put SRC DEST MODE OWNER:GROUP
# Installs a file only if it's missing or different.
# Returns 0 if it changed the file, 1 if it was already right. On any error it
# stops the whole script with exit, not return: put is always called inside a
# condition (if, &&, ||), where set -e is switched off, so a failure inside it
# would otherwise be ignored and reported as "installed".
put() {
	local src=$1 dest=$2 mode=$3 owner=$4
	[[ $mode =~ ^0?[0-7]{3}$ ]] || die "put: mode must look like 640 or 0640, not '$mode'"
	mode=${mode#0}  # stat -c %a prints 640, never 0640
	[[ $owner == *:* ]] || die "put: owner must be USER:GROUP, not '$owner'"
	[ -r "$src" ] || die "put: can't read $src"
	if [ -f "$dest" ] && cmp -s -- "$src" "$dest" \
		&& [ "$(stat -c %a -- "$dest")" = "$mode" ] \
		&& [ "$(stat -c %U:%G -- "$dest")" = "$owner" ]; then
		echo "    unchanged: $dest"
		return 1
	fi
	install -m "$mode" -o "${owner%:*}" -g "${owner#*:}" -- "$src" "$dest" \
		|| die "put: couldn't install $dest"
	echo "    installed: $dest"
	return 0
}

# Runs a noisy command with its output in $LOG; shows the end of it if it fails.
quietly() { "$@" >> "$LOG" 2>&1 || { echo "    FAILED: $*"; tail -20 "$LOG"; exit 1; }; }

step "Packages (Lesson 8)"
quietly apt-get update
quietly apt-get install -y nginx postgresql unattended-upgrades shellcheck
quietly apt-get upgrade -y
echo "    nginx, postgresql, unattended-upgrades and shellcheck installed; system up to date"

step "Automatic security updates (Lesson 8)"
printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' > /tmp/20auto-upgrades
put /tmp/20auto-upgrades /etc/apt/apt.conf.d/20auto-upgrades 644 root:root || true

step "Users (Lessons 5 and 11)"
id bookshop > /dev/null 2>&1 || { useradd --system --no-create-home --shell /usr/sbin/nologin bookshop; echo "    created: bookshop"; }
id sam > /dev/null 2>&1 || { useradd --create-home --shell /bin/bash --groups sudo sam; echo "    created: sam"; }
chmod 750 /home/sam
install -d -m 700 -o sam -g sam /home/sam/.ssh
put "$FILES/sam.pub" /home/sam/.ssh/authorized_keys 600 sam:sam || true

step "sudo needs a password (Lesson 11)"
echo 'Defaults !exempt_group' > /tmp/10-bookshop
visudo -cqf /tmp/10-bookshop
put /tmp/10-bookshop /etc/sudoers.d/10-bookshop 440 root:root || true
[ -f /etc/sudoers.d/vagrant ] && chmod 440 /etc/sudoers.d/vagrant
visudo -cq && echo "    sudo rules check out"

step "SSH: keys only, no root (Lesson 11)"
printf 'PasswordAuthentication no\nPermitRootLogin no\n' > /tmp/10-bookshop.conf
if put /tmp/10-bookshop.conf /etc/ssh/sshd_config.d/10-bookshop.conf 644 root:root; then
	# sshd -t needs /run/sshd, which only exists while ssh is running. On Ubuntu 24.04
	# ssh can start on demand, so it may not be there yet on a fresh server.
	mkdir -p /run/sshd
	sshd -t
	systemctl try-reload-or-restart ssh
	echo "    sshd settings tested and applied"
fi

step "Firewall: SSH and web only (Lesson 9)"
ufw allow OpenSSH > /dev/null
ufw allow 80/tcp > /dev/null
ufw --force enable > /dev/null
echo "    ufw active: OpenSSH, 80/tcp"

step "Data disk at /srv/books-data (Lesson 10)"
img=/var/tmp/books-data.img
if [ ! -f "$img" ]; then
	fallocate -l 90M "$img"
	mkfs.ext4 -q "$img"
	echo "    created: $img"
fi
mkdir -p /srv/books-data
if ! grep -q " /srv/books-data " /etc/fstab; then
	echo "$img /srv/books-data ext4 loop,nofail 0 2" >> /etc/fstab
	systemctl daemon-reload
	echo "    added to /etc/fstab"
fi
mountpoint -q /srv/books-data || mount /srv/books-data
chown bookshop:bookshop /srv/books-data
echo "    mounted: $(findmnt -n -o SOURCE,SIZE /srv/books-data)"

step "Database (Lessons 8 and 13)"
psql_q() { runuser -u postgres -- env PGOPTIONS=--client-min-messages=warning psql -tAq "$@"; }
if [ "$(psql_q -c "SELECT 1 FROM pg_database WHERE datname = 'books'")" != "1" ]; then
	runuser -u postgres -- createdb books
	echo "    created: database books"
fi
psql_q -d books -c "CREATE TABLE IF NOT EXISTS books (id serial PRIMARY KEY, title text NOT NULL, stock int NOT NULL DEFAULT 0);"
if [ "$(psql_q -d books -c "SELECT count(*) FROM books")" = "0" ]; then
	psql_q -d books -c "INSERT INTO books (title, stock) VALUES ('The Linux Command Line', 4), ('Designing Data-Intensive Applications', 2), ('The Phoenix Project', 7);"
	echo "    added: 3 books"
fi
echo "    books table: $(psql_q -d books -c "SELECT count(*) FROM books") rows"

step "The app (Lessons 7 and 9)"
grep -q "db.internal" /etc/hosts || echo "127.0.0.1 db.internal" >> /etc/hosts
install -d -m 755 /etc/books-api
app_changed=0
put "$FILES/books-api" /usr/local/bin/books-api 755 root:root && app_changed=1
put "$FILES/app.conf" /etc/books-api/app.conf 640 root:bookshop && app_changed=1
put "$FILES/override.conf" /etc/books-api/override.conf 640 root:bookshop && app_changed=1
put "$FILES/books-api.service" /etc/systemd/system/books-api.service 644 root:root && app_changed=1
systemctl daemon-reload
systemctl enable --quiet books-api
if [ "$app_changed" = 1 ] || ! systemctl is-active --quiet books-api; then
	systemctl restart books-api
	echo "    books-api restarted"
fi

step "Web server (Lessons 8 and 14)"
install -d -m 755 /srv/books/static
web_changed=0
put "$FILES/nginx-books" /etc/nginx/sites-available/books 644 root:root && web_changed=1
ln -sfn /etc/nginx/sites-available/books /etc/nginx/sites-enabled/books
if [ -e /etc/nginx/sites-enabled/default ]; then
	rm -f /etc/nginx/sites-enabled/default
	web_changed=1
fi
if [ "$web_changed" = 1 ]; then
	nginx -t -q
	systemctl reload nginx
	echo "    nginx settings tested and reloaded"
fi

step "Nightly backup (Lesson 13)"
put "$FILES/books-backup" /usr/local/bin/books-backup 755 root:root || true
put "$FILES/books-backup.service" /etc/systemd/system/books-backup.service 644 root:root || true
put "$FILES/books-backup.timer" /etc/systemd/system/books-backup.timer 644 root:root || true
systemctl daemon-reload
systemctl enable --now --quiet books-backup.timer
echo "    next backup: $(systemctl list-timers books-backup.timer --no-legend | awk '{print $1, $2, $3}')"

step "Done"
echo "    Now run: sudo /setup/audit.sh"
