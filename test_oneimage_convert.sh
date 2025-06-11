#!/bin/bash

function print_fail() {
    echo -e "[\e[31mFAILED\e[0m]"
}

function print_pass() {
    echo -e "[\e[32mPASSED\e[0m]"
}


echo 'Qwe!2345' | kinit > /dev/null

LOCAL_ADMIN_NAME="u"
LOCAL_ADMIN_PASS="1"


# Brest datastore IDs
BREST_IMAGE_DATASTORE_ID=$(   onedatastore list --filter "NAME~image"   | awk 'NR > 1 && $1 >= 100'  | awk '/lvm_brest/{print $1}')
BREST_SYSTEM_DATASTORE_ID=$(  onedatastore list --filter "NAME~system"  | awk 'NR > 1 && $1 >= 100'  | awk '/lvm_brest/{print $1}')
# Other datastore IDs
OTHER_IMAGE_DATASTORE_ID=$(   onedatastore list --filter "NAME~image"   | awk 'NR > 1 && $1 >= 100'  | awk '!/lvm_brest/{print $1}')
OTHER_SYSTEM_DATASTORE_ID=$(  onedatastore list --filter "NAME~system"  | awk 'NR > 1 && $1 >= 100'  | awk '!/lvm_brest/{print $1}')
# Type of other datastore
OTHER_DATASTORE_TYPE=$(onedatastore show $OTHER_IMAGE_DATASTORE_ID | grep "^NAME " | awk -F '_' '{print $NF}' | tr -d '[:space:]')




# Persistence check
echo -n "Персистентный прогон ... "
if [ $(oneimage show HDD --xml | xmlstarlet sel -t -v "/IMAGE/PERSISTENT") -eq 1 ]; then
    PERSISTENT=true
    PERSISTENT_FLAG="--persistent"
    echo "Да"
else
    PERSISTENT=false
    PERSISTENT_FLAG=""
    echo "Нет"
fi




CREATED_IMAGES_IDS=()

# ======================================================================================================================================================================================
# Image conversion

for IMAGE_TYPE in "OS" "CDROM" "DATABLOCK"; do
    echo
    echo -n "Создание образа $IMAGE_TYPE ... "
    
    case "$IMAGE_TYPE" in 
        OS)
            IMAGE_ID=$(oneimage create -d $OTHER_IMAGE_DATASTORE_ID --name "$IMAGE_TYPE" --type "$IMAGE_TYPE" --path "/var/tmp/mini.qcow2" $PERSISTENT_FLAG | awk '{print $NF}')
            ;;
        CDROM)
            IMAGE_ID=$(oneimage create -d $OTHER_IMAGE_DATASTORE_ID --name "$IMAGE_TYPE" --type "$IMAGE_TYPE" --path "/var/tmp/mini.qcow2"                  | awk '{print $NF}')
            ;;
        DATABLOCK)
            IMAGE_ID=$(oneimage create -d $OTHER_IMAGE_DATASTORE_ID --name "$IMAGE_TYPE" --type "$IMAGE_TYPE" --size 1024                  $PERSISTENT_FLAG | awk '{print $NF}')
            ;;
        *)
            echo "Неожиданный тип образа [$IMAGE_TYPE]"
            exit 1
    esac

    while [ $(oneimage show $IMAGE_ID --xml | xmlstarlet sel -t -v "/IMAGE/STATE") -ne 1 ]; do sleep 1; done
    CREATED_IMAGES_IDS+=(${IMAGE_ID})
    echo "Готово"


    INIT_SOURCE=$(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "/IMAGE/SOURCE")


    echo -n "Успешное выполнение команды (oneimage convert $IMAGE_ID $BREST_IMAGE_DATASTORE_ID) "
    if [[ $(oneimage convert $IMAGE_ID $BREST_IMAGE_DATASTORE_ID; echo $?) -eq 0 ]]; then
        print_pass
    else
        print_fail
    fi

    
    echo -n "Ожидание окончания конвертации ... "
    sleep 2
    while [ $(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "/IMAGE/STATE") -ne 1 ]; do sleep 1; done
    echo "Готово"



    echo -n "Проверка DATASTORE_ID образа "
    if [[ $(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "/IMAGE/DATASTORE_ID") -eq $BREST_IMAGE_DATASTORE_ID ]]; then
        print_pass
    else
        print_fail
    fi


    CORRECT_IMAGE_LVM_BLOCK="/dev/vg-one-$BREST_IMAGE_DATASTORE_ID/lv-one-image-$IMAGE_ID"
    CURRENT_IMAGE_LVM_BLOCK=$(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "/IMAGE/SOURCE")
    echo -n "Проверка SOURCE образа "
    if [ "$CURRENT_IMAGE_LVM_BLOCK" == "$CORRECT_IMAGE_LVM_BLOCK" ]; then
        print_pass
    else
        print_fail
    fi


    echo -n "Новый LVM-том создан ($CORRECT_IMAGE_LVM_BLOCK) "
    if [ $(sshpass -p "$LOCAL_ADMIN_PASS" ssh $LOCAL_ADMIN_NAME@bufn1 "sudo lvscan | grep '$CORRECT_IMAGE_LVM_BLOCK' > /dev/null"; echo $?) -eq 0 ]; then
        print_pass
    else
        print_fail
    fi


    case "$OTHER_DATASTORE_TYPE" in 
        lvm*)
            OLD_IMAGE_LVM_BLOCK="/dev/vg-one-$OTHER_IMAGE_DATASTORE_ID/lv-one-image-$IMAGE_ID"
            echo -n "Старый LVM-том удален ($OLD_IMAGE_LVM_BLOCK)"
            if [ $(sshpass -p "$LOCAL_ADMIN_PASS" ssh $LOCAL_ADMIN_NAME@bufn1 "sudo lvscan | grep '$OLD_IMAGE_LVM_BLOCK' > /dev/null"; echo $?) -ne 0 ]; then
                print_pass
            else
                print_fail
            fi
            ;;


        ocfs)
            echo -n "Старый файл образа удален ($INIT_SOURCE)"
            if [ ! -f ${INIT_SOURCE} ]; then
                print_pass
            else
                print_fail
            fi
            ;;
    esac

done


echo; echo
echo -n "Создание ВМ ... "
VM_ID=$(onevm create --name "oneimage_convert_vm" --cpu 2 --memory 2048 --spice --disk "$(IFS=,; echo "${CREATED_IMAGES_IDS[*]}")" | awk '{print $NF}')
sleep 5
while [[ $(onevm show $VM_ID -x | xmlstarlet sel -t -v "/VM/STATE") -ne 8 ]]; do sleep 1; done
echo "Готово"



