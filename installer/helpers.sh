#!/bin/bash

### helpers.sh

# empty echo means select the default option presented by the fdisk
format_partitions() {
        (
        echo g          # create new empty gpt partition table
        echo n          # new partition
        echo            # partition number: default (1)
        echo            # first sector: default (2048)
        echo +500M      # 500MiB for the EFI partition
        echo n          # new partition
        echo            # partition number: default(1)
        echo            # first sector: default (1026048 / 500MiB)
        echo            # last sector: default (..whole remaining part)
        echo t          # change the type of
        echo 1          # the first partition
        echo 1          # as efi
        echo t          # set the type of
        echo 2          # the second partition
        echo 30         # as Linux LVM
        echo w          # write changes to the device
        echo q          # quit
        ) | fdisk $1
}

print_line() {
        echo -e "\n******************************"
        echo -e "${1:-<OK>}"
        echo -e "******************************\n"
}
