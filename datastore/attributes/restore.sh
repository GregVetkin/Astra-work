#!/bin/bash

BACKUP_DIRECTORY="/tmp"



function restore_datastore_template() {
    local DATASTORE="$1"
    local BACKUP_FILE_NAME="${DATASTORE}_attributes"
    local BACKUP_FILE_PATH="${BACKUP_DIRECTORY}/${BACKUP_FILE_NAME}"

    onedatastore update "${DATASTORE}" "${BACKUP_FILE_PATH}"

    echo "Шаблон атрибутов хранилища ${DATASTORE} восстановлен"
}




if [ -z $1 ]
then
    DATASTORE_NAMES=($(onedatastore list -x | xmlstarlet sel -t -v "//DATASTORE/NAME"))

    for DATASTORE_NAME in "${DATASTORE_NAMES[@]}"; do
        restore_datastore_template $DATASTORE_NAME
    done
else
    restore_datastore_template $1
fi

