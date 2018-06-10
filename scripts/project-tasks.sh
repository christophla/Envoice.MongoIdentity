#!/bin/bash

# #############################################################################
# Settings
#
branch=$(if [ "$TRAVIS_PULL_REQUEST" == "false" ]; then echo $TRAVIS_BRANCH; else echo $TRAVIS_PULL_REQUEST_BRANCH; fi)
nugetFeedUri="https://www.myget.org/F/envoice/api/v3/index.json"
nugetKey=$MYGET_KEY_ENVOICE
revision=${TRAVIS_BUILD_NUMBER:=1}


# #############################################################################
# Constants
#
BLUE="\033[00;94m"
GREEN="\033[00;92m"
RED="\033[00;31m"
RESTORE="\033[0m"
YELLOW="\033[00;93m"
ROOT_DIR=$(pwd)


# #############################################################################
# Welcome message
#
welcome () {

    echo -e "${BLUE}"
    echo -e "                     _         "
    echo -e "  ___ ___ _  _____  (_)______  "
    echo -e " / -_) _ \ |/ / _ \/ / __/ -_) "
    echo -e " \__/_//_/___/\___/_/\__/\__/  "
    echo -e ""
    echo -e "${RESTORE}"

}


# #############################################################################
# Builds the project
#
buildProject () {

    echo -e "${GREEN}"
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "+ Building project                              "
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "${RESTORE}"

    dotnet build -c $ENVIRONMENT
}


# #############################################################################
# Kills all running containers of an image
#
clean() {

    echo -e "${GREEN}"
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "+ Cleaning projects and docker images           "
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "${RESTORE}"

    if [[ -z $ENVIRONMENT ]]; then
        ENVIRONMENT="debug"
    fi

    composeFileName="docker-compose.yml"
    if [[ $ENVIRONMENT != "debug" ]]; then
        composeFileName="docker-compose.$ENVIRONMENT.yml"
    fi

    if [[ ! -f $composeFileName ]]; then
        echo -e "${RED} $ENVIRONMENT is not a valid parameter. File '$composeFileName' does not exist. ${RESTORE}\n"
    else
        docker-compose -f $composeFileName down --rmi all

        # Remove any dangling images (from previous builds)
        danglingImages=$(docker images -q --filter 'dangling=true')
        if [[ ! -z $danglingImages ]]; then
        docker rmi -f $danglingImages
        fi

        echo -en "${YELLOW} Removed docker images ${RESTORE}\n"
    fi
}


# #############################################################################
# Runs docker-compose.
#
compose () {

    echo -e "${GREEN}"
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "+ Composing docker images                       "
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "${RESTORE}"

    if [[ -z $ENVIRONMENT ]]; then
        ENVIRONMENT="debug"
    fi

    composeFileName="docker-compose.yml"
    if [[ $ENVIRONMENT != "debug" ]]; then
        composeFileName="docker-compose.$ENVIRONMENT.yml"
    fi

    if [[ ! -f $composeFileName ]]; then
        echo -e "${RED} $ENVIRONMENT is not a valid parameter. File '$composeFileName' does not exist. ${RESTORE}\n"
    else

        echo -e "${YELLOW} Building the image $imageName ($ENVIRONMENT). ${RESTORE}\n"
        docker-compose -f "$composeFileName" build

        echo -e "${YELLOW} Creating the container $imageName ${RESTORE}\n"
        docker-compose -f $composeFileName kill
        docker-compose -f $composeFileName up -d
    fi
}


# #############################################################################
# Runs the integration tests.
#
integrationTests () {

    echo -e "${GREEN}"
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "+ Running integration tests                     "
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "${RESTORE}"

    for dir in test/*.IntegrationTests*/ ; do
        [ -e "$dir" ] || continue
        dir=${dir%*/}
        echo -e ${dir##*/}
        cd $dir
        dotnet test -c $ENVIRONMENT /p:CollectCoverage=true /p:CoverletOutputFormat=opencover
        rtn=$?
        if [ "$rtn" != "0" ]; then
        exit $rtn
        fi
    done

    cd $ROOT_DIR
}


# #############################################################################
# Deploys nuget packages to nuget feed
#
nugetPublish () {

    echo -e "${GREEN}"
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "+ Deploying nuget packages to nuget feed        "
    echo -e "+ ${branch}                                     "
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "${RESTORE}"

    if [ -z "$nugetKey" ]; then
        echo "${RED}You must set the MYGET_KEY_ENVOICE environment variable${RESTORE}"
        exit 1
    fi

    suffix=$(if [ "$branch" != "master" ]; then echo "ci-$revision"; fi)

    shopt -s nullglob # hide hidden
    cd src

    for dir in */ ; do # iterate projects
        [ -e "$dir" ] || continue

        cd $dir

        for nuspec in *.nuspec; do

            echo -e "${GREEN}Found nuspec for ${dir::-1}${RESTORE}"

            if ([ "$branch" == "master" ]); then
                dotnet pack \
                    -c $ENVIRONMENT \
                    -o ../../.artifacts/nuget \
                    --include-source \
                    --include-symbols
            else
                dotnet pack \
                    -c $ENVIRONMENT \
                    -o ../../.artifacts/nuget \
                    --include-source \
                    --include-symbols \
                    --version-suffix $suffix
            fi

        done

        cd ..

    done

    echo -e "${GREEN}"
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "Publishing packages to ${nugetFeedUri}          "
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "${RESTORE}"

    cd $ROOT_DIR
    cd ./.artifacts/nuget

    dotnet nuget push *.nupkg \
        -k $nugetKey \
        -s $nugetFeedUri

    cd $ROOT_DIR

    rm -rf ./artifacts/nuget

}


# #############################################################################
# Sets up the project
#
setup () {

    echo -e "${GREEN}"
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "+ Setting up project                            "
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "${RESTORE}"

    echo -e "${YELLOW} Done ${RESTORE}"
}


# #############################################################################
# Runs the unit tests.
#
unitTests () {

    echo -e "${GREEN}"
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "+ Running unit tests                            "
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "${RESTORE}"

    for dir in test/*.UnitTests*/ ; do
        [ -e "$dir" ] || continue
        dir=${dir%*/}
        echo -e ${dir##*/}
        cd $dir
        dotnet test -c $ENVIRONMENT /p:CollectCoverage=true /p:CoverletOutputFormat=opencover
        rtn=$?
        if [ "$rtn" != "0" ]; then
        exit $rtn
        fi
    done

    cd $ROOT_DIR
}


# #############################################################################
# Shows the usage for the script.
#
showUsage () {

    echo -e "${YELLOW}"
    echo -e "Usage: project-tasks.sh [COMMAND] (ENVIRONMENT)"
    echo -e "    Runs build or compose using specific environment (if not provided, debug environment is used)"
    echo -e ""
    echo -e "Commands:"
    echo -e "    build: Builds the project."
    echo -e "    build: Builds the project for ci."
    echo -e "    compose: Runs docker-compose."
    echo -e "    clean: Removes the image '$imageName' and kills all containers based on that image."
    echo -e "    composeForDebug: Builds the image and runs docker-compose."
    echo -e "    integrationTests: Composes the project and runs all integration test projects with *IntegrationTests* in the project name."
    echo -e "    nugetPublish: Builds and packs the project and publishes to nuget feed."
    echo -e "    setup: Setup the project."
    echo -e "    testAll: Runs all tests for the project"
    echo -e "    unitTests: Runs all unit test projects with *UnitTests* in the project name."
    echo -e ""
    echo -e "Environments:"
    echo -e "    debug: Uses debug environment."
    echo -e "    release: Uses release environment."
    echo -e ""
    echo -e "Quiet Mode:"
    echo -e "    quiet: Turns off welcome message"
    echo -e ""
    echo -e "Example:"
    echo -e "    ./project-tasks.sh build debug quiet"
    echo -e ""

    echo -e "${RESTORE}"

}


# #############################################################################
# Switch arguments
#
if [ $# -eq 0 ]; then
    welcome
    showUsage
else
    # quiet mode
    if [ -z "$3" ]; then
        welcome
    fi

    ENVIRONMENT=$(echo -e $2 | tr "[:upper:]" "[:lower:]")
    if [[ -z $ENVIRONMENT ]]; then ENVIRONMENT="debug"; fi

    case "$1" in
        "build")
            buildProject
            ;;
        "build-ci")
            compose
            unitTests
            integrationTests
            nugetPublish
            ;;
        "clean")
            clean
            ;;
        "compose")
            compose
            ;;
        "composeForDebug")
            export REMOTE_DEBUGGING="enabled"
            compose
            ;;
        "integrationTests")
            compose
            integrationTests
            ;;
        "nugetPublish")
            nugetPublish
            ;;
        "unitTests")
            unitTests
            ;;
        "setup")
            setup
            ;;
        "testAll")
            unitTests
            integrationTests
            ;;
        "unitTests")
            unitTests
            ;;
        *)
            showUsage
            ;;
    esac
fi

# #############################################################################
