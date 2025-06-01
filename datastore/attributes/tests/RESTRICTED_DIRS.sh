#!/bin/bash

check_only_image_and_file_type "${DATASTORE_TYPE}"

DATASTORE=$(get_datastore_name_by_type "${DATASTORE_TYPE}")
IMAGE_TYPE=$([ "$DATASTORE_TYPE" == "IMAGE" ] && echo "OS" || echo "CONTEXT")





function test_parent_dir() {
    #  Тест на запрет регистрации образа из небезопасной директории со значением атрибута родительской директории образа
    #  Необходимые атрибуты: RESTRICTED_DIRS="/var/" SAFE_DIRS=""

    check_storage_attributes_before_test "${DATASTORE}" "SAFE_DIRS=\"\"" "RESTRICTED_DIRS=\"/var/\""

    dd if=/dev/urandom of=/var/tmp/test_image bs=1MiB count=10
    $RUN_AS_BRESTADM oneimage create --name "test_image" -d "${DATASTORE}" --path "/var/tmp/test_image" --type "${IMAGE_TYPE}"
    sleep 3
    IMAGE_STATUS=$($RUN_AS_BRESTADM oneimage list | grep test_image | awk '{print $9}')

    CODE=0; if [ "$IMAGE_STATUS" != "err" ]; then CODE=1; fi

    $RUN_AS_BRESTADM oneimage delete test_image
    sudo rm -f /var/tmp/test_image
    
    return $CODE
}


function test_dir_list() {
    #  Тест список директорий
    #  Необходимые атрибуты: RESTRICTED_DIRS="/somedir /some/another /var" SAFE_DIRS=""

    check_storage_attributes_before_test "${DATASTORE}" "SAFE_DIRS=\"\"" "RESTRICTED_DIRS=\"/somedir /some/another /var\""
    
    dd if=/dev/urandom of=/var/tmp/test_image bs=1MiB count=10
    $RUN_AS_BRESTADM oneimage create --name "test_image" -d "${DATASTORE}" --path "/var/tmp/test_image" --type "${IMAGE_TYPE}"
    sleep 3
    IMAGE_STATUS=$($RUN_AS_BRESTADM oneimage list | grep test_image | awk '{print $9}')

    CODE=0; if [ "$IMAGE_STATUS" != "err" ]; then CODE=1; fi

    $RUN_AS_BRESTADM oneimage delete test_image
    sudo rm -f /var/tmp/test_image

    return $CODE
}
