#!/bin/bash

check_only_image_and_file_type "${DATASTORE_TYPE}"

DATASTORE=$(get_datastore_name_by_type "${DATASTORE_TYPE}")
IMAGE_TYPE=$([ "$DATASTORE_TYPE" == "IMAGE" ] && echo "OS" || echo "CONTEXT")




function test_not_safe_dir() {
    #  Тест на запрет регистрации образа из небезопасной директории
    #  Необходимые атрибуты SAFE_DIRS="/none"

    check_storage_attributes_before_test "${DATASTORE}" "SAFE_DIRS=\"/none\"" "RESTRICTED_DIRS=\"/\""

    dd if=/dev/urandom of=/var/tmp/test_image bs=1MiB count=10

    $RUN_AS_BRESTADM oneimage create --name "test_image" -d "${DATASTORE}" --path "/var/tmp/test_image" --type "${IMAGE_TYPE}"
    sleep 3
    IMAGE_STATUS=$($RUN_AS_BRESTADM oneimage list | grep test_image | awk '{print $9}')

    CODE=0; if [ "$IMAGE_STATUS" != "err" ]; then CODE=1; fi

    $RUN_AS_BRESTADM oneimage delete test_image
    sudo rm -f /var/tmp/test_image

    return $CODE
}



function test_safe_dir_equals_restricted_dir() {
    #  Тест на корректную регистрацию образа при совпадении RESTRICTED_DIRS и SAFE_DIRS
    #  Необходимые атрибуты SAFE_DIRS="/var/tmp", RESTRICTED_DIRS="/var/tmp"
        
    check_storage_attributes_before_test "${DATASTORE}" "SAFE_DIRS=\"/var/tmp\"" "RESTRICTED_DIRS=\"/var/tmp\""

    dd if=/dev/urandom of=/var/tmp/test_image bs=1MiB count=10

    $RUN_AS_BRESTADM oneimage create --name "test_image" -d "${DATASTORE}" --path "/var/tmp/test_image" --type "${IMAGE_TYPE}"
    sleep 3
    IMAGE_STATUS=$($RUN_AS_BRESTADM oneimage list | grep test_image | awk '{print $9}')

    CODE=0; if [ "$IMAGE_STATUS" != "rdy" ]; then CODE=1; fi

    $RUN_AS_BRESTADM oneimage delete test_image
    sudo rm -f /var/tmp/test_image

    return $CODE
}




function test_dir_list() {
    #  Тест на работу атрибута при списке директорий через пробел
    #  Необходимые атрибуты SAFE_DIRS="/some /some/another /var/tmp"

    check_storage_attributes_before_test "${DATASTORE}" "SAFE_DIRS=\"/some /some/another /var/tmp\"" "RESTRICTED_DIRS=\"/\""

    dd if=/dev/urandom of=/var/tmp/test_image bs=1MiB count=10

    $RUN_AS_BRESTADM oneimage create --name "test_image" -d "${DATASTORE}" --path "/var/tmp/test_image" --type "${IMAGE_TYPE}"
    sleep 3
    IMAGE_STATUS=$($RUN_AS_BRESTADM oneimage list | grep test_image | awk '{print $9}')

    CODE=0; if [ "$IMAGE_STATUS" != "rdy" ]; then CODE=1; fi

    $RUN_AS_BRESTADM oneimage delete test_image
    sudo rm -r /var/tmp/test_image
    
    return $CODE
}


