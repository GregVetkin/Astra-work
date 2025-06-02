#!/bin/bash
# Проверка при загрузке через http
# Атрибуты: BRIDGE_LIST="bufn1.brest.local" STAGING_DIR="/testdir"

DATASTORE_TYPE=$1
LOCAL_ADMIN_NAME="u"
LOCAL_ADMIN_PASS="1"
BUARM="buarm"



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


sshpass -p ${LOCAL_ADMIN_PASS} ssh $LOCAL_ADMIN_NAME@$BUARM "/media/sf_git/skts-test/testlink/brest/apache_with_image.sh > /dev/null"


IMAGE_URL="http://buarm/mini.qcow2"
STAGE_DIRECTORY="/testdir"
CONTROL_FILE=$(mktemp)


mkdir -m 777 $STAGE_DIRECTORY

IMAGE_ID=$(oneimage create -d $DATASTORE_ID --name "test_$(date +%s%N)" --path $IMAGE_URL --type $IMAGE_TYPE | awk '{print $NF}')


while [[ $(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "//STATE") -ne 1 ]]
do 
    ls $STAGE_DIRECTORY >> $CONTROL_FILE
    sleep 1
done


oneimage delete $IMAGE_ID
rm -fr $STAGE_DIRECTORY
sshpass -p ${LOCAL_ADMIN_PASS} ssh $LOCAL_ADMIN_NAME@$BUARM "sudo apt purge apache2 -y > /dev/null"

if [ -s $CONTROL_FILE ] then 
    echo "PASSED"
    exit 0
else
    echo "FAILED"
    exit 1
fi