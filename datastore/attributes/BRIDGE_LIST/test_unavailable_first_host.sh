#!/bin/bash
#  Тест работы атрибута при списке узлов, где первый недоступный, а второй - рабочий
#  Необходимые атрибуты BRIDGE_LIST="badhost bufn1.brest.local"

DATASTORE_TYPE=$1




case ${DATASTORE_TYPE} in
    IMAGE)
        IMAGE_TYPE="OS"
        DATASTORE_ID=$(onedatastore list -x | xmlstarlet sel -t -v "//DATASTORE[starts-with(NAME, 'image_')]/ID")
        ;;
    FILE)
        IMAGE_TYPE="CONTEXT"
        DATASTORE_ID=$(onedatastore list -x | xmlstarlet sel -t -v "//DATASTORE[starts-with(NAME, 'file_')]/ID")
        ;;
    *)
        echo "Данный тип [${DATASTORE_TYPE}] не поддерживается тестом"
        exit 2
        ;;
esac





FILE_PATH=$(mktemp -p /var/tmp)
dd if=/dev/urandom of=${FILE_PATH} bs=1MiB count=10 status=none && chmod 777 ${FILE_PATH}


IMAGE_ID=$(oneimage create --name "test_$(date +%s%N)" -d ${DATASTORE_ID} --type ${IMAGE_TYPE} --path ${FILE_PATH} | awk '{print $NF}')

while [[ $(oneimage show ${IMAGE_ID} -x | xmlstarlet sel -t -v "//STATE") -eq 4 ]]; do sleep 1; done

IMAGE_STATE_CODE=$(oneimage show ${IMAGE_ID} -x | xmlstarlet sel -t -v "//STATE")



oneimage delete ${IMAGE_ID}
rm -f ${FILE_PATH}



if [[ ${IMAGE_STATE_CODE} -eq 1 ]]; then
    echo "PASSED"
    exit 0
else
    echo "FAILED"
    exit 1
fi