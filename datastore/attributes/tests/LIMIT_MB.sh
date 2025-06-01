#!/bin/bash


DATASTORE=$(get_datastore_name_by_type "${DATASTORE_TYPE}")
IMAGE_TYPE=$([ "$DATASTORE_TYPE" == "IMAGE" ] && echo "OS" || echo "CONTEXT")




function test_image_or_file_ds() {
    #  Тест на проверку работы аттрибута ограничения емкости хранилища
    #  Атрибуты: LIMIT_MB="5"
    
    check_only_image_and_file_type "${DATASTORE_TYPE}"
    check_storage_attributes_before_test "${DATASTORE}" "LIMIT_MB=\"5\""
    
    dd if=/dev/urandom of=/var/tmp/test_image bs=1MiB count=6 &>/dev/null

    $RUN_AS_BRESTADM oneimage create --name "test_image" --type "${IMAGE_TYPE}" -d "${DATASTORE}" --path "/var/tmp/test_image"


    if [ $? -eq 0 ]; then
        CODE=1
    else
        CODE=0
    fi

    
    $RUN_AS_BRESTADM oneimage delete test_image
    sudo rm -r /var/tmp/test_image

    return $CODE
}


function test_system_ds() {
    #  Тест на проверку работы аттрибута ограничения емкости хранилища у системного хранилища
    #  Атрибут: LIMIT_MB="1"  DATASTORE_CAPACITY_CHECK="YES"

    if [[ "${DATASTORE_TYPE}" != "SYSTEM" ]]
    then
        echo "Тест доступен только для хранилищ типа SYSTEM"
        exit 1
    fi
    
    check_storage_attributes_before_test "${DATASTORE}" "LIMIT_MB=\"1\""

    IMAGE_DS=$(echo "${DATASTORE}" | sed 's/system/image/g')
    $RUN_AS_BRESTADM oneimage create -d "${IMAGE_DS}" --name "test_image" --type "OS" --size "10"
    $RUN_AS_BRESTADM onedatastore list | grep "sys" | awk '{print $1}' | while read ID; do $RUN_AS_BRESTADM onedatastore disable $ID; done
    $RUN_AS_BRESTADM onedatastore enable "${DATASTORE}"


    $RUN_AS_BRESTADM onevm create --name "tested_vm" --memory 128 --cpu 1 --disk "test_image"
    sleep 30
    SCHED_MESSAGE=$($RUN_AS_BRESTADM onevm show "tested_vm" | grep "SCHED_MESSAGE=")
    

    if echo $SCHED_MESSAGE | grep "Not enough capacity"
    then
        CODE=0
    else
        CODE=1
    fi


    $RUN_AS_BRESTADM onedatastore list | grep "sys" | awk '{print $1}' | while read ID; do $RUN_AS_BRESTADM onedatastore enable $ID; done
    $RUN_AS_BRESTADM onevm terminate "tested_vm" --hard
    $RUN_AS_BRESTADM oneimage delete "test_image" 

    return $CODE
}
