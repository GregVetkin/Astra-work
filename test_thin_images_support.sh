#!/bin/bash


function by_ssh() {
    local username=${1}
    local password=${2}
    local host=${3}
    local command=${4}

    sshpass -p $password ssh $username@$host -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "${command}"
}


function get_image_size() {
    local source="$1"
    by_ssh "u" "1" "localhost" "
        sudo qemu-img check --force-share $source | grep 'Image end offset:' | awk '{print \$NF}'
    "
}


IMAGE_DATASTORE_ID=$(onedatastore list -x | xmlstarlet sel -t -v "//DATASTORE[starts-with(NAME, 'image_')]/ID")
FILE_PATH="/var/tmp/10gb.qcow2"

PREALLOCATION="" # -o preallocation=full"

by_ssh "u" "1" "localhost" "
    sudo qemu-img create -f qcow2 $PREALLOCATION $FILE_PATH 10G
    sudo modprobe nbd max_part=16
    sudo qemu-nbd --connect=/dev/nbd0 $FILE_PATH
    sudo mkfs.ext4 /dev/nbd0
    sudo mkdir -p /mnt/10gb
    sudo mount /dev/nbd0 /mnt/10gb
    sudo dd if=/dev/urandom of=/mnt/10gb/3gb bs=1G count=3
    sudo umount /mnt/10gb
    sudo qemu-nbd --disconnect /dev/nbd0
    sudo rmmod nbd
    sudo chmod 777 $FILE_PATH
" &>/dev/null


IMAGE_ID=$(oneimage create --name "test_$(date +%s%N)" -d $IMAGE_DATASTORE_ID --type "OS" --path $FILE_PATH | awk '{print $NF}')

while [[ $(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "//STATE") -ne 1 ]]; do sleep 1; done



IMAGE_SOURCE=$(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "//SOURCE")




by_ssh "u" "1" "localhost" "
    sudo lvchange -ay $IMAGE_SOURCE
"

echo $(get_image_size $IMAGE_SOURCE)


by_ssh "u" "1" "localhost" "
    sudo lvchange -an $IMAGE_SOURCE
"