#!/bin/bash

DATASTORE=$(get_datastore_name_by_type "${DATASTORE_TYPE}")
IMAGE_TYPE=$([ "$DATASTORE_TYPE" == "IMAGE" ] && echo "OS" || echo "CONTEXT")





function test_no_awailable_storage_id_in_list() {
    #  Тест на проверку корректности работы атрибута при значении в виде списка id хранилищ
    #  Атрибут: COMPATIBLE_SYS_DS="42"
    

    if [[ "${DATASTORE_TYPE}" != "IMAGE" ]]
    then
        echo "Тест доступен только для хранилищ типа IMAGE"
        exit 1
    fi

    check_storage_attributes_before_test "${DATASTORE}" "COMPATIBLE_SYS_DS=\"42\""

    $RUN_AS_BRESTADM oneimage create -d "${DATASTORE}" --name "test_image" --type "OS" --size "10"


    $RUN_AS_BRESTADM onevm create --name "tested_vm" --memory 128 --cpu 1 --disk "test_image"
    sleep 20
    SCHED_MESSAGE=$($RUN_AS_BRESTADM onevm show "tested_vm" | grep "SCHED_MESSAGE=")
    

    if echo $SCHED_MESSAGE | grep "Cannot dispatch VM"
    then 
        CODE=0
    else 
        CODE=1
    fi


    $RUN_AS_BRESTADM onevm terminate "tested_vm" --hard
    $RUN_AS_BRESTADM oneimage delete "test_image"

    return $CODE
}



function test_id_list_with_comma() {
    #  Тест на проверку работы аттрибута при нахождении доступного хранилище в списке в конце
    #  Атрибут: COMPATIBLE_SYS_DS="42, {system_ds_id}"

    if [[ "${DATASTORE_TYPE}" != "IMAGE" ]]
    then
        echo "Тест доступен только для хранилищ типа IMAGE"
        exit 1
    fi

    SYSTEM_DS_NAME=$(echo "${DATASTORE}" | sed 's/image_/system_/g')
    SYSTEM_DS_ID=$($RUN_AS_BRESTADM onedatastore list | grep "${SYSTEM_DS_NAME}" | awk '{print $1}')
    check_storage_attributes_before_test "${DATASTORE}" "COMPATIBLE_SYS_DS=\"42, ${SYSTEM_DS_ID}\""
    $RUN_AS_BRESTADM oneimage create -d "${DATASTORE}" --name "test_image" --type "OS" --size "10"


    $RUN_AS_BRESTADM onevm create --name "tested_vm" --memory 128 --cpu 1 --disk "test_image"
    sleep 30
    VM_STATE=$($RUN_AS_BRESTADM onevm show "tested_vm" | grep "^STATE " | awk '{print $3}')
    STORAGE_ID=$(sudo onevm show "tested_vm" | grep -A 2 "VIRTUAL MACHINE HISTORY" | sed '1d' | sed '1d' | awk '{print $6}')
    SYSTEM_DS_NAME=$(echo "${DATASTORE}" | sed 's/image_/system_/g')
    SYSTEM_DS_ID=$($RUN_AS_BRESTADM onedatastore list | grep "${SYSTEM_DS_NAME}" | awk '{print $1}')


    if [[ "${VM_STATE}" == "POWEROFF" && "${STORAGE_ID}" == "${SYSTEM_DS_ID}" ]]
    then 
        CODE=0
    else 
        CODE=1 
    fi


    $RUN_AS_BRESTADM onevm terminate "tested_vm" --hard
    $RUN_AS_BRESTADM oneimage delete "test_image"

    return $CODE
}
