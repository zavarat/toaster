#!/bin/bash

OS_NAME="$(uname | awk '{print tolower($0)}')"

_NAME=$1

LIST="/tmp/toaster-helper-ctx-list"

################################################################################

command -v fzf > /dev/null && FZF=true
command -v tput > /dev/null && TPUT=true

_echo() {
    if [ -n ${TPUT} ] && [ -n $2 ]; then
        echo -e "$(tput setaf $2)$1$(tput sgr0)"
    else
        echo -e "$1"
    fi
}

_read() {
    if [ -n ${TPUT} ]; then
        read -p "$(tput setaf 6)$1$(tput sgr0)" ANSWER
    else
        read -p "$1" ANSWER
    fi
}

_result() {
    echo
    _echo "# $@" 4
}

_command() {
    echo
    _echo "$ $@" 3
}

_success() {
    echo
    _echo "+ $@" 2
    echo
    exit 0
}

_error() {
    echo
    _echo "- $@" 1
    echo
    exit 1
}

_select_one() {
    if [ -n ${FZF} ]; then
        SELECTED=$(cat ${LIST} | fzf --reverse --height 10)
    else
        echo

        IDX=0
        while read VAL; do
            IDX=$(( ${IDX} + 1 ))
            printf "%3s. %s\n" "${IDX}" "${VAL}"
        done < ${LIST}

        CNT=$(cat ${LIST} | wc -l | xargs)

        echo
        _read "Please select one. (1-${CNT}) : "

        SELECTED=
        if [ -z ${ANSWER} ]; then
            return
        fi
        TEST='^[0-9]+$'
        if ! [[ ${ANSWER} =~ ${TEST} ]]; then
            return
        fi
        SELECTED=$(sed -n ${ANSWER}p ${LIST})
    fi
}

################################################################################

usage() {
    #figlet ctx
    echo "       _ "
    echo "   ___| |___  __ "
    echo "  / __| __\ \/ / "
    echo " | (__| |_ >  < "
    echo "  \___|\__/_/\_\ "
    echo
    echo "Usage: `basename $0` {NAME}"
    echo

    exit 1
}

prepare() {
    # mkdir -p ${CONFIG_DIR}

    # touch ${CONFIG} && . ${CONFIG}

    rm -rf ${LIST}
}

deploy() {
    if [ -z ${_NAME} ]; then
        echo "$(kubectl config view -o json | jq '.clusters[].name' -r)" > ${LIST}

        _select_one

        _result "${SELECTED}"

        _NAME="${SELECTED}"
    fi

    if [ -z "${_NAME}" ]; then
        usage
    fi

    kubectl config use-context ${_NAME}

    _success "${_NAME}"
}

################################################################################

prepare

deploy
