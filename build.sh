#!/bin/bash

OS_NAME="$(uname | awk '{print tolower($0)}')"

SHELL_DIR=$(dirname $0)

CMD=${1:-${CIRCLE_JOB}}

USERNAME=${CIRCLE_PROJECT_USERNAME}
REPONAME=${CIRCLE_PROJECT_REPONAME}

BRANCH=${CIRCLE_BRANCH:-master}

BUCKET="www.toast.sh"

GIT_USERNAME="bot"
GIT_USEREMAIL="bot@nalbam.com"

################################################################################

# command -v tput > /dev/null && TPUT=true
TPUT=

_echo() {
    if [ "${TPUT}" != "" ] && [ "$2" != "" ]; then
        echo -e "$(tput setaf $2)$1$(tput sgr0)"
    else
        echo -e "$1"
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
    exit 0
}

_error() {
    echo
    _echo "- $@" 1
    exit 1
}

_replace() {
    if [ "${OS_NAME}" == "darwin" ]; then
        sed -i "" -e "$1" $2
    else
        sed -i -e "$1" $2
    fi
}

_prepare() {
    # target
    mkdir -p ${SHELL_DIR}/target/dist

    if [ -f ${SHELL_DIR}/target/circleci-stop ]; then
        _success "circleci-stop"
    fi
}

_package() {
    if [ ! -f ${SHELL_DIR}/VERSION ]; then
        _error "not found VERSION"
    fi

    _result "BRANCH=${BRANCH}"
    _result "PR_NUM=${PR_NUM}"
    _result "PR_URL=${PR_URL}"

    # release version
    MAJOR=$(cat ${SHELL_DIR}/VERSION | xargs | cut -d'.' -f1)
    MINOR=$(cat ${SHELL_DIR}/VERSION | xargs | cut -d'.' -f2)

    # latest versions
    GITHUB="https://api.github.com/repos/${USERNAME}/${REPONAME}/releases"
    VERSION=$(curl -s ${GITHUB} | grep "tag_name" | grep "${MAJOR}.${MINOR}." | head -1 | cut -d'"' -f4 | cut -d'-' -f1)

    if [ -z ${VERSION} ]; then
        VERSION="${MAJOR}.${MINOR}.0"
    fi

    _result "VERSION=${VERSION}"

    # new version
    if [ "${BRANCH}" == "master" ]; then
        VERSION=$(echo ${VERSION} | perl -pe 's/^(([v\d]+\.)*)(\d+)(.*)$/$1.($3+1).$4/e')
        printf "${VERSION}" > ${SHELL_DIR}/target/VERSION
    else
        PR=$(echo "${BRANCH}" | cut -d'/' -f1)

        if [ "${PR}" == "pull" ]; then
            printf "${PR}" > ${SHELL_DIR}/target/PR

            if [ "${PR_NUM}" == "" ]; then
                PR_NUM=$(echo "${BRANCH}" | cut -d'/' -f2)
            fi
            if [ "${PR_NUM}" == "" ] && [ "${PR_URL}" != "" ]; then
                PR_NUM=$(echo "${PR_URL}" | cut -d'/' -f7)
            fi
            if [ "${PR_NUM}" == "" ]; then
                PR_NUM=${CIRCLE_BUILD_NUM}
            fi

            if [ "${PR_NUM}" != "" ]; then
                VERSION="${VERSION}-${PR_NUM}"
                printf "${VERSION}" > ${SHELL_DIR}/target/VERSION
            else
                VERSION=
            fi
        else
            VERSION=
        fi
    fi

    _result "VERSION=${VERSION}"
}

_publish() {
    if [ "${BRANCH}" != "master" ]; then
        return
    fi
    if [ -z ${BUCKET} ]; then
        return
    fi
    if [ ! -f ${SHELL_DIR}/target/VERSION ]; then
        return
    fi
    if [ -f ${SHELL_DIR}/target/PR ]; then
        return
    fi

    # aws s3 sync
    _command "aws s3 sync ${SHELL_DIR}/target/ s3://${BUCKET}/${REPONAME}/ --acl public-read"
    aws s3 sync ${SHELL_DIR}/target/ s3://${BUCKET}/${REPONAME}/ --acl public-read

    # aws cf reset
    CFID=$(aws cloudfront list-distributions --query "DistributionList.Items[].{Id:Id, DomainName: DomainName, OriginDomainName: Origins.Items[0].DomainName}[?contains(OriginDomainName, '${BUCKET}')] | [0]" | jq -r '.Id')
    if [ "${CFID}" != "" ]; then
        aws cloudfront create-invalidation --distribution-id ${CFID} --paths "/*"
    fi
}

_release() {
    if [ -z ${GITHUB_TOKEN} ]; then
        return
    fi
    if [ ! -f ${SHELL_DIR}/target/VERSION ]; then
        return
    fi

    VERSION=$(cat ${SHELL_DIR}/target/VERSION | xargs)
    _result "VERSION=${VERSION}"

    printf "${VERSION}" > ${SHELL_DIR}/target/dist/${VERSION}

    if [ -f ${SHELL_DIR}/target/PR ]; then
        GHR_PARAM="-delete -prerelease"
    else
        GHR_PARAM="-delete"
    fi

    _command "go get github.com/tcnksm/ghr"
    go get github.com/tcnksm/ghr

    # github release
    _command "ghr ${VERSION} ${SHELL_DIR}/target/dist/"
    ghr -t ${GITHUB_TOKEN:-EMPTY} \
        -u ${USERNAME} \
        -r ${REPONAME} \
        -c ${CIRCLE_SHA1} \
        ${GHR_PARAM} \
        ${VERSION} ${SHELL_DIR}/target/dist/
}

_slack() {
    if [ -z ${SLACK_TOKEN} ]; then
        return
    fi
    if [ ! -f ${SHELL_DIR}/target/VERSION ]; then
        return
    fi

    VERSION=$(cat ${SHELL_DIR}/target/VERSION | xargs)
    _result "VERSION=${VERSION}"

    # send slack
    curl -sL opspresso.com/tools/slack | bash -s -- \
        --token="${SLACK_TOKEN}" --username="${USERNAME}" \
        --footer="<https://github.com/${USERNAME}/${REPONAME}/releases/tag/${VERSION}|${USERNAME}/${REPONAME}>" \
        --footer_icon="https://repo.opspresso.com/favicon/github.png" \
        --color="good" --title="${REPONAME}" "\`${VERSION}\`"
}

################################################################################

_prepare

case ${CMD} in
    package)
        _package
        ;;
    publish)
        _publish
        ;;
    release)
        _release
        ;;
    slack)
        _slack
        ;;
esac

_success
