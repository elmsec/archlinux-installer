#!/bin/bash

# this will not run well in the /mnt directory entered via the arch-chroot,
# as a reboot is required at the time the installation is running/finished
# but leaving it here anyway.

ufw default deny outgoing
ufw default deny incoming
ufw allow out proto udp to any port 53
ufw allow out proto tcp to any port http
ufw allow out proto tcp to any port https
ufw limit out proto tcp to any port ssh
# ufw allow in proto tcp to any port "$PORT" # should work but didnt check

print_line "All UFW rules has been successfully created!"

# enable
ufw enable

print_line "UFW enabled."
