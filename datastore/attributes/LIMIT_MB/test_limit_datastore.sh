#!/bin/bash
#  Тест на проверку работы аттрибута ограничения емкости хранилища
#  Атрибуты: LIMIT_MB="5"


function test_image_and_file_datastore() {
    DUMMY_FILE=$(mktemp -p /var/tmp)
    dd if=/dev/urandom of=${DUMMY_FILE} bs=1MiB count=10 status=none && chmod 777 ${DUMMY_FILE}

    RESULT_CODE=$(oneimage create --name "test_$(date +%s%N)" -d $DATASTORE_ID --path $DUMMY_FILE --type $IMAGE_TYPE &>/dev/null; echo $?)

    rm -f $DUMMY_FILE


    if [[ $RESULT_CODE -ne 0 ]]; then
        echo "PASSED"
        exit 0
    else
        echo "FAILED"
        exit 1
    fi
}


function test_system_datastore() {
    IMAGE_DATASTORE_ID=$(onedatastore list -x | xmlstarlet sel -t -v "//DATASTORE[starts-with(NAME, 'image_')]/ID")
    SYSTEM_DATASTORE_ID=$(onedatastore list -x | xmlstarlet sel -t -v "//DATASTORE[starts-with(NAME, 'system_')]/ID")
    IMAGE_ID=$(oneimage create --name "test_$(date +%s%N)" -d $IMAGE_DATASTORE_ID --size 10 --type "OS" | awk '{print $NF}')
    while [[ $(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "//STATE") -ne 1 ]]; do sleep 1; done

    SYSTEM_DATASTORE_IDS=($(onedatastore list -x | xmlstarlet sel -t -v "//DATASTORE[TYPE=1]/ID"))

    for SYS_DS_ID in  "${SYSTEM_DATASTORE_IDS[@]}"; do
        onedatastore disable $SYS_DS_ID
    done

    onedatastore enable $SYSTEM_DATASTORE_ID
    sleep 2

    VM_ID=$(onevm create --name "test_$(date +%s%N)" --memory 32 --cpu 1 --disk $IMAGE_ID | awk '{print $NF}')
    sleep 10
    SCHED_MESSAGE=$(onevm show $VM_ID -x | xmlstarlet sel -t -v "/VM/USER_TEMPLATE/SCHED_MESSAGE")
    VM_STATE=$(onevm show $VM_ID -x | xmlstarlet sel -t -v "/VM/STATE")


    for SYS_DS_ID in "${SYSTEM_DATASTORE_IDS[@]}"; do
        onedatastore enable $SYS_DS_ID
    done

    onevm    delete $VM_ID
    oneimage delete $IMAGE_ID

    if [ "$VM_STATE" -ne 8 ] && [ -z "$SCHED_MESSAGE" ]; then
        echo "PASSED"
        exit 0
    else
        echo "FAILED"
        exit 1
    fi
}



DATASTORE_TYPE=$1

case ${DATASTORE_TYPE} in
    IMAGE)
        IMAGE_TYPE="OS"
        DATASTORE_ID=$(onedatastore list -x | xmlstarlet sel -t -v "//DATASTORE[starts-with(NAME, 'image_')]/ID")
        test_image_and_file_datastore
        ;;
    FILE)
        IMAGE_TYPE="CONTEXT"
        DATASTORE_ID=$(onedatastore list -x | xmlstarlet sel -t -v "//DATASTORE[starts-with(NAME, 'file_')]/ID")
        test_image_and_file_datastore
        ;;
    SYSTEM)
        ;;
    *)
        echo "Данный тип [${DATASTORE_TYPE}] не поддерживается тестом"
        echo "Доступные типы: IMAGE FILE SYSTEM"
        exit 2
        ;;
esac



