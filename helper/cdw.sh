#!/bin/bash

NUM=$1
DIR=

ANSWER=

CDW_DIR=

SHELL_DIR=$(dirname $(dirname "$0"))

################################################################################

question() {
    read -p "$(tput setaf 6)$@$(tput sgr0)" ANSWER
}

success() {
    tput setaf 2
    echo -e "$@"
    tput sgr0
    exit 0
}

error() {
    tput setaf 1
    echo -e "$@"
    tput sgr0
    exit 1
}

usage() {
    if [ -r ${SHELL_DIR}/conf/ver.now ]; then
        VER="$(cat ${SHELL_DIR}/conf/ver.now)"
    else
        VER="v3"
    fi

    #figlet cdw
    echo "================================================================================"
    echo "          _ "
    echo "   ___ __| |_      __ "
    echo "  / __/ _' \ \ /\ / / "
    echo " | (_| (_| |\ V  V /  "
    echo "  \___\__,_| \_/\_/  by nalbam (${VER}) "
    echo "================================================================================"

    exit 1
}

################################################################################

prepare() {
    mkdir -p ${SHELL_DIR}/conf

    CONFIG=${SHELL_DIR}/conf/$(basename $0)
    if [ -f ${CONFIG} ]; then
        . ${CONFIG}
    fi
}

directory() {
    if [ -z "${CDW_DIR}" ] || [ ! -d "${CDW_DIR}" ]; then
        pushd ~
        DEFAULT="$(pwd)/work/src"
        popd

        question "Please input base directory. [${DEFAULT}]: "
        CDW_DIR=${ANSWER:-${DEFAULT}}
    fi

    mkdir -p ${CDW_DIR}

    if [ ! -d "${CDW_DIR}" ]; then
        error "[${CDW_DIR}] is not directory."
    fi

    echo "CDW_DIR=${CDW_DIR}" > "${CONFIG}"
}

dir() {
    TEMP=/tmp/cdr.tmp
    find ${CDW_DIR} -maxdepth 2 -type d -exec ls -d "{}" \; > ${TEMP}

    echo "================================================================================"

    i=0
    while read v; do
        i=$(( ${i} + 1 ))
        printf "%3s %s\n" "$i" "$v";
    done < ${TEMP}

    echo "================================================================================"
}

cdw() {
    TEMP=/tmp/cdr.tmp
    find ${CDW_DIR} -maxdepth 2 -type d -exec ls -d "{}" \; > ${TEMP}

    if [ "${NUM}" == "" ]; then
        echo "================================================================================"

        i=0
        while read v; do
            i=$(( ${i} + 1 ))
            printf "%3s %s\n" "$i" "$v";
        done < ${TEMP}

        echo "================================================================================"

        read NUM
    fi

    if [ "${NUM}" == "" ]; then
        usage
    fi

    i=0
    while read v; do
        i=$(( ${i} + 1 ))
        if [ "${i}" == "${NUM}" ]; then
            DIR="${v}"
        fi
    done < ${TEMP}

    if [ "${DIR}" == "" ] || [ ! -d ${DIR} ]; then
        usage
    fi

    success "cd ${DIR}"

    cd ${DIR}

    exec bash
}

################################################################################

prepare

directory

dir
#cdw
