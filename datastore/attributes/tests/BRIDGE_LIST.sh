#!/bin/bash

check_only_image_and_file_type "${DATASTORE_TYPE}"

DATASTORE=$(get_datastore_name_by_type "${DATASTORE_TYPE}")
IMAGE_TYPE=$([ "$DATASTORE_TYPE" == "IMAGE" ] && echo "OS" || echo "CONTEXT")




function test_all_hosts_err_dsbl_off() {
    #  Тест на корректную работу атрибута при всех недоступых узлах в списке
    #  Необходимые атрибуты BRIDGE_LIST="bun2.brest.local bun3.brest.local bun4.brest.local"
    
    check_storage_attributes_before_test "${DATASTORE}" "BRIDGE_LIST=\"bun2.brest.local bun3.brest.local bun4.brest.local\""
    dd if=/dev/urandom of=/var/tmp/test_image bs=1MiB count=10
    
    sshpass -p '1' ssh u@bun4 "sudo chmod 000 /var/tmp/one"

    local HOST_TO_DSBL="bun2.brest.local"
    local HOST_TO_OFF="bun3.brest.local"
    local HOST_TO_ERR="bun4.brest.local"

    onehost disable "$HOST_TO_DSBL"
    onehost offline "$HOST_TO_OFF"

    while [[ "$(host_state_code ${HOST_TO_DSBL})" -ne 4 ]] || [[ "$(host_state_code ${HOST_TO_OFF})" -ne 8 ]] || [[ "$(host_state_code ${HOST_TO_ERR})" -ne 3 ]]
    do
        sleep 1
    done


    oneimage create --name "test_image" -d "${DATASTORE}" --type "${IMAGE_TYPE}" --path "/var/tmp/test_image"
    sleep 10
    IMAGE_STATE_CODE=$(oneimage show "test_image" -x | xmlstarlet sel -t -v "/IMAGE/STATE")


    if [[ ${IMAGE_STATE_CODE} -eq 5 ]]
    then
        CODE=0
    else
        CODE=1
    fi

    onehost enable "bun2.brest.local"
    onehost enable "bun3.brest.local"
    oneimage delete test_image

    sshpass -p '1' ssh u@bun4  "sudo chmod 755 /var/tmp/one"
    
    rm -f /var/tmp/test_image

    return $CODE
}



function test_host_list() {
    

    check_storage_attributes_before_test "${DATASTORE}" "BRIDGE_LIST=\"badhost bufn1.brest.local\""
    
    dd if=/dev/urandom of=/var/tmp/test_image bs=1MiB count=10

    $RUN_AS_BRESTADM oneimage create --name "test_image" -d "${DATASTORE}" --type "${IMAGE_TYPE}" --path "/var/tmp/test_image"
    sleep 10
    IMAGE_STATUS=$($RUN_AS_BRESTADM oneimage list | grep test_image | awk '{print $9}')


    if [ "$IMAGE_STATUS" == "rdy" ]
    then
        CODE=0
    else
        CODE=1
    fi


    $RUN_AS_BRESTADM oneimage delete test_image
    sudo rm -f /var/tmp/test_image

    return $CODE
}
