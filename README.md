# linux-practice

Practice files for the Linux track on [kwamib.dev](https://kwamib.dev/resources/linux).
Everything here is made up: the logs, the settings and the people. IP addresses
come from the ranges reserved for documentation (203.0.113.0/24 and
198.51.100.0/24), so none of them belong to anyone.

Run the lessons in a container with this folder inside it:

    docker run -it --rm -v "$PWD":/practice -w /practice ubuntu:24.04 bash
