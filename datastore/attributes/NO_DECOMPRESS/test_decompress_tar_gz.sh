#!/bin/bash
#  Тест проверки корректной распаковки образа .tar.gz
#  Необходимые атрибуты NO_DECOMPRESS="NO"

DATASTORE_TYPE=$1

case ${DATASTORE_TYPE} in
    IMAGE)
        IMAGE_TYPE="OS"
        DATASTORE_ID=$(onedatastore list -x | xmlstarlet sel -t -v "//DATASTORE[starts-with(NAME, 'image_')]/ID")
        ;;
    *)
        echo "Данный тип [${DATASTORE_TYPE}] не поддерживается тестом"
        echo "Доступный тип: IMAGE"
        exit 2
        ;;
esac



echo 'Qwe\!2345' | kinit >/dev/null

wget -P /var/tmp/ ftp://10.190.14.11/guest/mini/latest/archive.tar.gz &>/dev/null
IMAGE_TAR_GZ="/var/tmp/archive.tar.gz"

IMAGE_ID=$(oneimage create -d $DATASTORE_ID --name "test_$(date +%s%N)" --path $IMAGE_TAR_GZ --type $IMAGE_TYPE | awk '{print $NF}')
while [[ $(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "//STATE") -eq 4 ]]; do sleep 1; done
            

if [[ $(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "//STATE") -eq 5 ]]
then
    echo "Образ загруженного архива в статусе ОШИБКА"
    exit 2
fi



VNET_TEMPLATE=$(mktemp -p /var/tmp)
echo '
    NAME = "test_NO_DECOMPRESS"
    AR = [
    IP = "10.0.70.250",
    SIZE = "1",
    TYPE = "IP4" ]
    BRIDGE = "br0"
    GATEWAY = "10.0.70.254"
    DNS = "8.8.8.8 10.0.70.10"
    SEARCH_DOMAIN = "brest.local"
    VN_MAD = "bridge"
' > $VNET_TEMPLATE

VNET_ID=$(onevnet create $VNET_TEMPLATE | awk '{print $NF}' ) 
rm -f $VNET_TEMPLATE



VM_ID=$(onevm create --name "test_$(date +%s%N)" --nic $VNET_ID --cpu 1 --memory 1024 --disk $IMAGE_ID --spice --context NETWORK="YES" | awk '{print $NF}')

while [[ $(onevm show $VM_ID -x | xmlstarlet sel -t -v "//STATE") -eq 8 ]]; do sleep 1; done

onevm resume $VM_ID

sleep 60

if ping -c 10 "10.0.70.250"; then
    ALIVE=true
else
    ALIVE=false
fi


onevm terminate --hard $VM_ID
while [[ $(onevm show $VM_ID -x | xmlstarlet sel -t -v "//STATE") -eq 6 ]]; do sleep 1; done
oneimage delete $IMAGE_ID
onevnet  delete $VNET_ID
rm -f /var/tmp/archive.tar.gz


if [ "$ALIVE" = "true" ]; then
    echo "PASSED"
    exit 0
else
    echo "FAILED"
    exit 1
fi