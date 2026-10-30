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
