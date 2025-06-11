#!/bin/bash

LOCAL_ADMIN_NAME="u"
LOCAL_ADMIN_PASS="1"



function print_fail() {
    echo -e "[\e[31mFAILED\e[0m]"
}

function print_pass() {
    echo -e "[\e[32mPASSED\e[0m]"
}


echo 'Qwe!2345' | kinit > /dev/null


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



# Brest datastore IDs
BREST_IMAGE_DATASTORE_ID=$(   onedatastore list --filter "NAME~image"   | awk 'NR > 1 && $1 >= 100'  | awk '/lvm_brest/{print $1}')
BREST_SYSTEM_DATASTORE_ID=$(  onedatastore list --filter "NAME~system"  | awk 'NR > 1 && $1 >= 100'  | awk '/lvm_brest/{print $1}')


# Other datastore IDs
OTHER_IMAGE_DATASTORE_ID=$(   onedatastore list --filter "NAME~image"   | awk 'NR > 1 && $1 >= 100'  | awk '!/lvm_brest/{print $1}')
OTHER_SYSTEM_DATASTORE_ID=$(  onedatastore list --filter "NAME~system"  | awk 'NR > 1 && $1 >= 100'  | awk '!/lvm_brest/{print $1}')


# Type of other datastore
OTHER_DATASTORE_TYPE=$(onedatastore show $OTHER_IMAGE_DATASTORE_ID | grep "^NAME " | awk -F '_' '{print $NF}' | tr -d '[:space:]')





# ======================================================================================================================================================================================
# Images creation
echo -n "Создание образов ... "

OS_IMAGE_ID=$(        oneimage create -d $OTHER_IMAGE_DATASTORE_ID --name "OS"        --type "OS"        --path "/var/tmp/mini.qcow2" $PERSISTENT_FLAG | awk '{print $NF}')
CDROM_IMAGE_ID=$(     oneimage create -d $OTHER_IMAGE_DATASTORE_ID --name "CDROM"     --type "CDROM"     --path "/var/tmp/mini.qcow2"                  | awk '{print $NF}')
DATABLOCK_IMAGE_ID=$( oneimage create -d $OTHER_IMAGE_DATASTORE_ID --name "DATABLOCK" --type "DATABLOCK" --size 1024                  $PERSISTENT_FLAG | awk '{print $NF}')

while [ $(oneimage show $OS_IMAGE_ID        --xml | xmlstarlet sel -t -v "/IMAGE/STATE") -ne 1 ]; do sleep 1; done
while [ $(oneimage show $CDROM_IMAGE_ID     --xml | xmlstarlet sel -t -v "/IMAGE/STATE") -ne 1 ]; do sleep 1; done
while [ $(oneimage show $DATABLOCK_IMAGE_ID --xml | xmlstarlet sel -t -v "/IMAGE/STATE") -ne 1 ]; do sleep 1; done

echo "Образы готовы"





# ======================================================================================================================================================================================
# VM template preparation

echo -n "Подготовка шаблона ВМ ... "

TEMPLATE_ID=$(onetemplate show "test_vm" -x | xmlstarlet sel -t -v "/VMTEMPLATE/ID")
TEMPLATE_FILE_PATH="/var/tmp/vm.tmpl"
TEMPLATE_BODY=$(onetemplate show $TEMPLATE_ID --xml | xmlstarlet sel -t -c "//TEMPLATE" -n)
TEMPLATE_BODY_WITHOUT_DISKS=$(echo $TEMPLATE_BODY | xmlstarlet ed -d "//DISK")
TEMPLATE_BODY_UPDATED=$(echo $TEMPLATE_BODY_WITHOUT_DISKS | xmlstarlet ed \
    -s "/TEMPLATE"          -t elem -n "DISK"       -v "" \
    -s "TEMPLATE/DISK[1]"   -t elem -n "IMAGE_ID"   -v "$OS_IMAGE_ID" \
    \
    -s "/TEMPLATE"          -t elem -n "DISK"       -v "" \
    -s "TEMPLATE/DISK[2]"   -t elem -n "IMAGE_ID"   -v "$CDROM_IMAGE_ID" \
    \
    -s "/TEMPLATE"          -t elem -n "DISK"       -v "" \
    -s "TEMPLATE/DISK[3]"   -t elem -n "IMAGE_ID"   -v "$DATABLOCK_IMAGE_ID" \
    \
    -s "/TEMPLATE"          -t elem -n "DISK"       -v "" \
    -s "TEMPLATE/DISK[4]"   -t elem -n "FORMAT"     -v "raw" \
    -s "TEMPLATE/DISK[4]"   -t elem -n "FS"         -v "ext4" \
    -s "TEMPLATE/DISK[4]"   -t elem -n "SIZE"       -v "1024" \
    -s "TEMPLATE/DISK[4]"   -t elem -n "TYPE"       -v "fs" \
)
echo $TEMPLATE_BODY_UPDATED > $TEMPLATE_FILE_PATH
onetemplate update $TEMPLATE_ID $TEMPLATE_FILE_PATH

echo "Шаблон готов"




# ======================================================================================================================================================================================
# VM creation
echo -n "Создание ВМ из шаблона ... "



# for HOST_ID in $(onehost list --no-header --filter "NAME!=bufn1.brest.local" -l "ID"); do
#     onehost disable $HOST_ID
# done

VM_ID=$(onetemplate instantiate $TEMPLATE_ID --name "vm_changeds" --hold | awk '{print $NF}')


UPDATE_FILE=$(mktemp -p /tmp)
HOST_ID=$(onehost list -x | xmlstarlet sel -t -m "//HOST[NAME='bufn1.brest.local']" -v "ID")

echo 'SCHED_REQUIREMENTS="ID=\"'"$HOST_ID"'\""' >> $UPDATE_FILE
echo 'SCHED_DS_REQUIREMENTS="ID=\"'"$OTHER_SYSTEM_DATASTORE_ID"'\""' >> $UPDATE_FILE

onevm update  $VM_ID $UPDATE_FILE -a
onevm release $VM_ID

sleep 5
while [ $(onevm show $VM_ID -x | xmlstarlet sel -t -v "/VM/STATE") -ne 8 ]; do sleep 1; done

# for HOST_ID in $(onehost list --no-header --filter "NAME!=bufn1.brest.local" -l "ID"); do
#     onehost enable $HOST_ID
# done

echo "ВМ готова"



# ======================================================================================================================================================================================
# Onevm changeds




if [ "$1" == "hot" ]; then

    echo -n "Горячий режим, запуск ВМ ... "
    onevm resume $VM_ID; sleep 10
    while [[ $(onevm show $VM_ID -x | xmlstarlet sel -t -v "/VM/LCM_STATE") -ne 3 ]]; do sleep 1; done
    echo "ВМ запущена"

    echo -n "Перенос ВМ (onevm changeds $VM_ID $BREST_SYSTEM_DATASTORE_ID $BREST_IMAGE_DATASTORE_ID) ... "
    onevm changeds $VM_ID $BREST_SYSTEM_DATASTORE_ID $BREST_IMAGE_DATASTORE_ID
    sleep 5
    while [[ $(onevm show $VM_ID -x | xmlstarlet sel -t -v "/VM/LCM_STATE") -ne 3 ]]; do sleep 1; done
    echo "Выполнено"

else

    echo -n "Перенос ВМ (onevm changeds $VM_ID $BREST_SYSTEM_DATASTORE_ID $BREST_IMAGE_DATASTORE_ID) ... "
    onevm changeds $VM_ID $BREST_SYSTEM_DATASTORE_ID $BREST_IMAGE_DATASTORE_ID
    sleep 5
    while [[ $(onevm show $VM_ID -x | xmlstarlet sel -t -v "/VM/STATE") -ne 8 ]]; do sleep 1; done
    echo "Выполнено"

fi


echo
echo






# ======================================================================================================================================================================================
# Check 


for OLD_IMAGE_ID in $OS_IMAGE_ID $CDROM_IMAGE_ID $DATABLOCK_IMAGE_ID; do
    OLD_IMAGE_NAME=$(oneimage show $OLD_IMAGE_ID -x | xmlstarlet sel -t -v "/IMAGE/NAME")
    NEW_IMAGE_NAME="${OLD_IMAGE_NAME}_$OLD_IMAGE_ID"
    NEW_IMAGE_ID=$(oneimage show $NEW_IMAGE_NAME -x | xmlstarlet sel -t -v "/IMAGE/ID")
    
    echo "Image ${OLD_IMAGE_NAME}:"

    echo -n "Образ $NEW_IMAGE_NAME в хранилище lvm_brest " 
    if [ $(oneimage show $NEW_IMAGE_ID -x | xmlstarlet sel -t -v "//DATASTORE_ID") -eq $BREST_IMAGE_DATASTORE_ID ]; then
        print_pass
    else
        print_fail
    fi


    echo -n "Наследование персистентности " 
    if [ $(oneimage show $NEW_IMAGE_ID -x | xmlstarlet sel -t -v "//PERSISTENT") -eq $(oneimage show $NEW_IMAGE_ID -x | xmlstarlet sel -t -v "/IMAGE/PERSISTENT") ]; then
        print_pass
    else
        print_fail
    fi


    echo -n "Счетчик ВМ образа $OLD_IMAGE_NAME равен 0 " 
    if [ $(oneimage show $OLD_IMAGE_ID -x | xmlstarlet sel -t -v "//RUNNING_VMS") -eq 0 ]; then
        print_pass
    else
        print_fail
    fi


    echo -n "Счетчик ВМ образа $NEW_IMAGE_NAME равен 1 " 
    if [ $(oneimage show $NEW_IMAGE_ID -x | xmlstarlet sel -t -v "//RUNNING_VMS") -eq 1 ]; then
        print_pass
    else
        print_fail
    fi

    echo
done



# Проверка информации о размещении в новом системном хранилище по шаблону HISTORY_RECORDS
echo -n "ВМ размещена в новом системном хранилище (по шаблону) " 
if [ $(onevm show $VM_ID -x | xmlstarlet sel -t -v "/VM/HISTORY_RECORDS/HISTORY[last()]/DS_ID") -eq $BREST_SYSTEM_DATASTORE_ID ]; then
    print_pass
else
    print_fail
fi


# Проверка существования директории ВМ в новом системном хранилище на узле размещения
echo -n "ВМ размещена в новом системном хранилище /var/lib/one/datastores/$BREST_SYSTEM_DATASTORE_ID/$VM_ID " 
if [ -d "/var/lib/one/datastores/$BREST_SYSTEM_DATASTORE_ID/$VM_ID" ]; then
    print_pass
else
    print_fail
fi


# Проверка удаления директории ВМ в старом системном хранилище на узле размещения
echo -n "ВМ отсутствует в старом системном хранилище /var/lib/one/datastores/$OTHER_SYSTEM_DATASTORE_ID/$VM_ID "
if [ ! -d "/var/lib/one/datastores/$OTHER_SYSTEM_DATASTORE_ID/$VM_ID" ]; then
    print_pass
else
    print_fail
fi

echo


# ================================================================================================================================================
# Проверка временного диска
TEMP_DISK_ID=$(onevm show $VM_ID -x | xmlstarlet sel -t -m "//DISK[TYPE='fs']" -v "DISK_ID" -n)
TEMP_DISK_LINK_PATH="/var/lib/one/datastores/$BREST_SYSTEM_DATASTORE_ID/$VM_ID/disk.$TEMP_DISK_ID"
TEMP_DISK_CORRECT_LINK_POINTER="/dev/vg-one-$BREST_SYSTEM_DATASTORE_ID/lv-one-vm-$VM_ID-$TEMP_DISK_ID"
TEMP_DISK_CURRENT_LINK_POINTER=$(sshpass -p "$LOCAL_ADMIN_PASS" ssh $LOCAL_ADMIN_NAME@bufn1 "sudo readlink $TEMP_DISK_LINK_PATH")



echo -n "Временный диск: Симлинк присутствует в /var/lib/one/datastores/$BREST_SYSTEM_DATASTORE_ID/$VM_ID "
if [ -L "$TEMP_DISK_LINK_PATH" ]; then
    print_pass
else
    print_fail
fi


echo -n "Временный диск: Корректный симлинк "
if [ "$TEMP_DISK_CURRENT_LINK_POINTER" == "$TEMP_DISK_CORRECT_LINK_POINTER" ]; then
    print_pass
else
    print_fail
fi


echo -n "Временный диск: Новый LVM-том создан "
if [ $(sshpass -p "$LOCAL_ADMIN_PASS" ssh $LOCAL_ADMIN_NAME@bufn1 "sudo lvscan | grep $TEMP_DISK_CORRECT_LINK_POINTER > /dev/null"; echo $?) -eq 0 ]; then
    print_pass
else
    print_fail
fi

echo
# ================================================================================================================================================
# CDROM DISK CHECK

NEW_CDROM_IMAGE_ID=$(oneimage show "CDROM_$CDROM_IMAGE_ID" -x | xmlstarlet sel -t -v "/IMAGE/ID")
CDROM_DISK_ID=$(onevm show $VM_ID -x | xmlstarlet sel -t -m "//DISK[TYPE='CDROM']" -v "DISK_ID" -n)
CDROM_DISK_LINK_PATH="/var/lib/one/datastores/$BREST_SYSTEM_DATASTORE_ID/$VM_ID/disk.$CDROM_DISK_ID"
CDROM_DISK_CORRECT_LINK_POINTER="/dev/vg-one-$BREST_IMAGE_DATASTORE_ID/lv-one-image-$NEW_CDROM_IMAGE_ID"
CDROM_DISK_CURRENT_LINK_POINTER=$(sshpass -p "$LOCAL_ADMIN_PASS" ssh $LOCAL_ADMIN_NAME@bufn1 "sudo readlink $CDROM_DISK_LINK_PATH")



echo -n "CDROM: Симлинк присутствует в /var/lib/one/datastores/$BREST_SYSTEM_DATASTORE_ID/$VM_ID "
if [ -L "$CDROM_DISK_LINK_PATH" ]; then
    print_pass
else
    print_fail
fi


echo -n "CDROM: Корректный симлинк "
if [ "$CDROM_DISK_CURRENT_LINK_POINTER" == "$CDROM_DISK_CORRECT_LINK_POINTER" ]; then
    print_pass
else
    print_fail
fi


echo -n "CDROM: Новый LVM-том создан "
if [ $(sshpass -p "$LOCAL_ADMIN_PASS" ssh $LOCAL_ADMIN_NAME@bufn1 "sudo lvscan | grep '$CDROM_DISK_CORRECT_LINK_POINTER' > /dev/null"; echo $?) -eq 0 ]; then
    print_pass
else
    print_fail
fi



echo
# ================================================================================================================================================
# OS DISK CHECK

NEW_OS_IMAGE_ID=$(oneimage show "OS_$OS_IMAGE_ID" -x | xmlstarlet sel -t -v "/IMAGE/ID")
OS_DISK_ID=$(onevm show $VM_ID -x | xmlstarlet sel -t -m "//DISK[IMAGE_ID='$NEW_OS_IMAGE_ID']" -v "DISK_ID" -n)
OS_DISK_LINK_PATH="/var/lib/one/datastores/$BREST_SYSTEM_DATASTORE_ID/$VM_ID/disk.$OS_DISK_ID"

if [ "$PERSISTENT" == "true" ]; then
    OS_DISK_CORRECT_LINK_POINTER="/dev/vg-one-$BREST_IMAGE_DATASTORE_ID/lv-one-image-$NEW_OS_IMAGE_ID"
else
    OS_DISK_CORRECT_LINK_POINTER="/dev/vg-one-$BREST_SYSTEM_DATASTORE_ID/lv-one-vm-$VM_ID-$OS_DISK_ID"
fi

OS_DISK_CURRENT_LINK_POINTER=$(sshpass -p "$LOCAL_ADMIN_PASS" ssh $LOCAL_ADMIN_NAME@bufn1 "sudo readlink $OS_DISK_LINK_PATH")




echo -n "OS: Симлинк присутствует в /var/lib/one/datastores/$BREST_SYSTEM_DATASTORE_ID/$VM_ID "
if [ -L "$OS_DISK_LINK_PATH" ]; then
    print_pass
else
    print_fail
fi


echo -n "OS: Корректный симлинк "
if [ "$OS_DISK_CURRENT_LINK_POINTER" == "$OS_DISK_CORRECT_LINK_POINTER" ]; then
    print_pass
else
    print_fail
fi


echo -n "OS: Новый LVM-том создан "
if [ $(sshpass -p "$LOCAL_ADMIN_PASS" ssh $LOCAL_ADMIN_NAME@bufn1 "sudo lvscan | grep '$OS_DISK_CORRECT_LINK_POINTER' > /dev/null"; echo $?) -eq 0 ]; then
    print_pass
else
    print_fail
fi




echo
# ================================================================================================================================================
# DATABLOCK DISK CHECK

NEW_DATABLOCK_IMAGE_ID=$(oneimage show "DATABLOCK_$DATABLOCK_IMAGE_ID" -x | xmlstarlet sel -t -v "/IMAGE/ID")
DATABLOCK_DISK_ID=$(onevm show $VM_ID -x | xmlstarlet sel -t -m "//DISK[IMAGE_ID='$NEW_DATABLOCK_IMAGE_ID']" -v "DISK_ID" -n)
DATABLOCK_DISK_LINK_PATH="/var/lib/one/datastores/$BREST_SYSTEM_DATASTORE_ID/$VM_ID/disk.$DATABLOCK_DISK_ID"

if [ "$PERSISTENT" == "true" ]; then
    DATABLOCK_DISK_CORRECT_LINK_POINTER="/dev/vg-one-$BREST_IMAGE_DATASTORE_ID/lv-one-image-$NEW_DATABLOCK_IMAGE_ID"
else
    DATABLOCK_DISK_CORRECT_LINK_POINTER="/dev/vg-one-$BREST_SYSTEM_DATASTORE_ID/lv-one-vm-$VM_ID-$DATABLOCK_DISK_ID"
fi

DATABLOCK_DISK_CURRENT_LINK_POINTER=$(sshpass -p "$LOCAL_ADMIN_PASS" ssh $LOCAL_ADMIN_NAME@bufn1 "sudo readlink $DATABLOCK_DISK_LINK_PATH")




echo -n "DATABLOCK: Симлинк присутствует в /var/lib/one/datastores/$BREST_SYSTEM_DATASTORE_ID/$VM_ID "
if [ -L "$DATABLOCK_DISK_LINK_PATH" ]; then
    print_pass
else
    print_fail
fi


echo -n "DATABLOCK: Корректный симлинк "
if [ "$DATABLOCK_DISK_CURRENT_LINK_POINTER" == "$DATABLOCK_DISK_CORRECT_LINK_POINTER" ]; then
    print_pass
else
    print_fail
fi


echo -n "DATABLOCK: Новый LVM-том создан "
if [ $(sshpass -p "$LOCAL_ADMIN_PASS" ssh $LOCAL_ADMIN_NAME@bufn1 "sudo lvscan | grep '$DATABLOCK_DISK_CORRECT_LINK_POINTER' > /dev/null"; echo $?) -eq 0 ]; then
    print_pass
else
    print_fail
fi

echo
# ================================================================================================================================================







case "$OTHER_DATASTORE_TYPE" in 
    lvm*)
        echo -n "LVM's: Старые LVM-тома ВМ и дисков удалены "
        OLD_VM_LVM_TOM="/dev/vg-one-$OTHER_SYSTEM_DATASTORE_ID/lv-one-vm-$VM_ID"
        if [ $(sshpass -p "$LOCAL_ADMIN_PASS" ssh $LOCAL_ADMIN_NAME@bufn1 "sudo lvscan | grep '$OLD_VM_LVM_TOM' > /dev/null"; echo $?) -ne 0 ]; then
            print_pass
        else
            print_fail
        fi
        ;;

esac
