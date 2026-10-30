# linux-practice

Practice files for the Linux track on [kwamib.dev](https://kwamib.dev/resources/linux).
Everything here is made up: the logs, the settings and the people. IP addresses
come from the ranges reserved for documentation (203.0.113.0/24 and
198.51.100.0/24), so none of them belong to anyone.

Lessons 1 to 6 run in a container with this folder inside it:

    docker run -it --rm -v "$PWD":/practice -w /practice ubuntu:24.04 bash

From Lesson 7 on, the lessons run on a small Ubuntu server, a virtual machine
made by [Vagrant](https://developer.hashicorp.com/vagrant) from the `Vagrantfile`
here. This folder appears inside it at `/practice`:

    vagrant up
    vagrant ssh

Lesson 15 builds a second server, from nothing, with one script. In `fresh/`:

    cd fresh
    vagrant up                  # builds it: runs setup.sh
    vagrant ssh -c 'sudo /setup/audit.sh'
    vagrant provision           # runs setup.sh again: changes nothing

- `setup.sh` does everything Lessons 5 to 13 did by hand, and is safe to run again.
- `audit.sh` checks the server is set up and locked down, and changes nothing.
- `files/` holds the bookshop's own files, copied from the first server.
  `sam.pub` is the public key Sam logs in with. Put your own there before
  `vagrant up`: `cp ~/.ssh/bookshop_ed25519.pub fresh/files/sam.pub` (Lesson 11).
  A public key is safe to share; the private key never leaves your computer.
