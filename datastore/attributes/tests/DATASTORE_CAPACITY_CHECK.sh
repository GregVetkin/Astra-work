#!/bin/bash


check_only_image_and_file_type "${DATASTORE_TYPE}"

DATASTORE=$(get_datastore_name_by_type "${DATASTORE_TYPE}")
IMAGE_TYPE=$([ "$DATASTORE_TYPE" == "IMAGE" ] && echo "OS" || echo "CONTEXT")




function test_capacity_check_yes() {
    #  Тест на проверку работы аттрибута ограничения емкости хранилища
    #  Атрибуты: DATASTORE_CAPACITY_CHECK="YES"

    check_storage_attributes_before_test "${DATASTORE}" "DATASTORE_CAPACITY_CHECK=\"YES\""

    
    if $RUN_AS_BRESTADM oneimage create --name "test_image" --type "${IMAGE_TYPE}" -d "${DATASTORE}" --size "10000000"
    then
        CODE=1
    else
        CODE=0
    fi

    $RUN_AS_BRESTADM oneimage delete test_image

    return $CODE
}


function test_capacity_check_no() {
    #  Тест на проверку работы аттрибута ограничения емкости хранилища
    #  Атрибуты: DATASTORE_CAPACITY_CHECK="NO"

    if [[ "${DATASTORE_TYPE}" != "IMAGE" ]]
    then
        echo "Тест написан только для хранилища типа IMAGE"
        exit 1
    fi
        
    check_storage_attributes_before_test "${DATASTORE}" "DATASTORE_CAPACITY_CHECK=\"NO\""


    if $RUN_AS_BRESTADM oneimage create --name "test_image" --type "${IMAGE_TYPE}" -d "${DATASTORE}" --size "10000000"
    then
        CODE=0
    else
        CODE=1
    fi

    $RUN_AS_BRESTADM oneimage delete test_image

    return $CODE
}
