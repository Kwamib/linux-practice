#!/bin/bash
# Check the bookshop server is set up and locked down. Changes nothing.
# Prints PASS or FAIL for each check, and exits 1 if anything failed.
set -uo pipefail

[ "$(id -u)" -eq 0 ] || { echo "audit.sh: run me with sudo" >&2; exit 1; }

fails=0
check() {
	local name=$1; shift
	if "$@" > /dev/null 2>&1; then
		echo "PASS  $name"
	else
		echo "FAIL  $name"
		fails=$((fails + 1))
	fi
}

# grep without -q reads all its input. With pipefail, grep -q can stop reading early,
# the command writing to it gets SIGPIPE, and the whole pipe counts as failed.
sshd_says() { sshd -T 2>/dev/null | grep -x "$1" > /dev/null; }
mode_is() { [ "$(stat -c '%a %U:%G' "$1")" = "$2" ]; }
only_public_ports() {
	local extra
	extra=$(ss -tlnH | awk '{print $4}' | grep -vE '^(127\.|\[::1\])' | sed 's/.*://' | sort -u | grep -vxE '22|80')
	[ -z "$extra" ]
}
no_world_writable_etc() { [ -z "$(find /etc -xdev -type f -perm -0002)" ]; }
api_answers() { [ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/api/)" = "200" ]; }

echo "== SSH"
check "password logins off" sshd_says "passwordauthentication no"
check "root logins off" sshd_says "permitrootlogin no"
check "~sam/.ssh is 700 sam:sam" mode_is /home/sam/.ssh "700 sam:sam"
check "authorized_keys is 600 sam:sam" mode_is /home/sam/.ssh/authorized_keys "600 sam:sam"
check "/home/sam not writable by others" mode_is /home/sam "750 sam:sam"

echo "== sudo"
check "sudo group needs a password" grep -qx 'Defaults !exempt_group' /etc/sudoers.d/10-bookshop
check "all sudo rules check out" visudo -cq

echo "== Network"
check "firewall active" sh -c 'ufw status | grep "Status: active"'
check "only SSH and web open to the network" only_public_ports

echo "== Updates"
check "automatic security updates on" sh -c 'apt-config dump APT::Periodic::Unattended-Upgrade | grep "\"1\""'

echo "== Services"
for s in nginx books-api postgresql books-backup.timer; do
	check "$s active" systemctl is-active --quiet "$s"
done
check "API answers 200" api_answers

echo "== Files"
check "app settings 640 root:bookshop" mode_is /etc/books-api/override.conf "640 root:bookshop"
check "data disk mounted" mountpoint -q /srv/books-data
check "no world-writable files in /etc" no_world_writable_etc

echo
if [ "$fails" -eq 0 ]; then
	echo "All checks passed."
else
	echo "$fails check(s) failed."
	exit 1
fi
