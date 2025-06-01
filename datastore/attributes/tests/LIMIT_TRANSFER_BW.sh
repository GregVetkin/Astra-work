#!/bin/bash

check_only_image_and_file_type "${DATASTORE_TYPE}"

DATASTORE=$(get_datastore_name_by_type "${DATASTORE_TYPE}")
IMAGE_TYPE=$([ "$DATASTORE_TYPE" == "IMAGE" ] && echo "OS" || echo "CONTEXT")





function test_suffix_m() {
    # Тест атрибута с суффиксом М
    # Атрибуты: LIMIT_TRANSFER_BW="25M"

    check_storage_attributes_before_test "${DATASTORE}" "LIMIT_TRANSFER_BW=\"25M\""

    ssh buarm "cd ~/brest && ./apache_with_image.sh"


    $RUN_AS_BRESTADM oneimage create -d "${DATASTORE}" --name test_image --path http://buarm/mini.qcow2 --type "${IMAGE_TYPE}"
    ssh buarm "cd ~/brest && timeout 10 ./transmit_speed.sh >> ~/testfile"
    AVG_UPLOAD=$(ssh buarm "cat -e ~/testfile | grep MB/s | grep -o '[0-9]*\.[0-9]*' | awk '{ sum += \$1; count ++ } END { if (count > 0) print int(sum / count) }'")


    CODE=1
    if [ "${AVG_UPLOAD}" -gt 23 ] && [ "${AVG_UPLOAD}" -lt 27 ]
    then
        CODE=0
    fi


    $RUN_AS_BRESTADM oneimage delete test_image
    ssh buarm "sudo rm -f ~/testfile"
    ssh buarm "sudo apt purge apache2 -y"

    return $CODE
}


function test_no_suffix() {
    # Тест атрибута без суффиксов
    # Атрибуты: LIMIT_TRANSFER_BW="31457280"
    
    check_storage_attributes_before_test "${DATASTORE}" "LIMIT_TRANSFER_BW=\"31457280\""

    ssh buarm "cd ~/brest && ./apache_with_image.sh"
    
    
    $RUN_AS_BRESTADM oneimage create -d "${DATASTORE}" --name test_image --path http://buarm/mini.qcow2 --type "${IMAGE_TYPE}"
    ssh buarm "cd ~/brest && timeout 10 ./transmit_speed.sh >> ~/testfile"
    AVG_UPLOAD=$(ssh buarm "cat -e ~/testfile | grep MB/s | grep -o '[0-9]*\.[0-9]*' | awk '{ sum += \$1; count ++ } END { if (count > 0) print int(sum / count) }'")
    

    CODE=1
    if [ "${AVG_UPLOAD}" -gt 27 ] && [ "${AVG_UPLOAD}" -lt 33 ]
    then
        CODE=0
    fi


    $RUN_AS_BRESTADM oneimage delete test_image
    ssh buarm "sudo rm -f ~/testfile"
    ssh buarm "sudo apt purge apache2 -y"

    return $CODE
}
    
