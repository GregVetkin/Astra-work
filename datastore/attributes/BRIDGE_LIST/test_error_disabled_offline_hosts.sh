#!/bin/bash
#  Тест на корректную работу атрибута при всех недоступых узлах в списке
#  Необходимые атрибуты хранилища BRIDGE_LIST="bun2.brest.local bun3.brest.local bun4.brest.local"

DATASTORE_TYPE=$1

LOCAL_ADMIN_NAME="u"
LOCAL_ADMIN_PASS="1"
BUN4="bun4"


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






DUMMY_FILE=$(mktemp -p /var/tmp)
dd if=/dev/urandom of=${DUMMY_FILE} bs=1MiB count=10 status=none && chmod 777 ${DUMMY_FILE}


HOST_TO_DSBL="bun2.brest.local"
HOST_TO_OFF="bun3.brest.local"
HOST_TO_ERR="bun4.brest.local"



onehost disable ${HOST_TO_DSBL}
onehost offline ${HOST_TO_OFF}
sshpass -p ${LOCAL_ADMIN_PASS} ssh $LOCAL_ADMIN_NAME@$BUN4 "sudo chmod 000 /var/tmp/one"



while [[ $(onehost show ${HOST_TO_DSBL} -x | xmlstarlet sel -t -v "//STATE") -ne 4 ]];  do sleep 1; done
while [[ $(onehost show ${HOST_TO_OFF}  -x | xmlstarlet sel -t -v "//STATE") -ne 8 ]];  do sleep 1; done
while [[ $(onehost show ${HOST_TO_ERR}  -x | xmlstarlet sel -t -v "//STATE") -ne 3 ]];  do sleep 1; done



IMAGE_ID=$(oneimage create --name "test_$(date +%s%N)" -d $DATASTORE_ID --type $IMAGE_TYPE --path $DUMMY_FILE | awk '{print $NF}')
sleep 5
IMAGE_STATE_CODE=$(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "/IMAGE/STATE")



onehost  enable ${HOST_TO_DSBL}
onehost  enable ${HOST_TO_OFF}
oneimage delete ${IMAGE_ID}
sshpass -p ${LOCAL_ADMIN_PASS} ssh $LOCAL_ADMIN_NAME@$BUN4 "sudo chmod 755 /var/tmp/one"
rm -f $DUMMY_FILE



if [[ $IMAGE_STATE_CODE -eq 5 ]]; then
    echo "PASSED"
    exit 0
else
    echo "FAILED"
    exit 1
fi