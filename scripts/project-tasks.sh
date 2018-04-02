#!/bin/bash

# #############################################################################
# Settings
#
imageName="ngs-nff-autostore-integration"
nugetFeedUri="https://www.myget.org/F/envoice/api/v2"
nugetKey=$MYGET_KEY_ENVOICE
nugetVersion="1.0.0"
nugetVersionSuffix=""
projectName="envoice"

BLUE="\033[00;94m"
GREEN="\033[00;92m"
RED="\033[00;31m"
RESTORE="\033[0m"
YELLOW="\033[00;93m"


# #############################################################################
# Welcome message
#
welcome () {

  echo -en "${BLUE}\n"
  echo -en "                         _          \n"
  echo -en "  ___  ____ _   ______  (_)_______  \n"
  echo -en " / _ \/ __ \ | / / __ \/ / ___/ _ \ \n"
  echo -en "/  __/ / / / |/ / /_/ / / /__/  __/ \n"
  echo -en "\___/_/ /_/|___/\____/_/\___/\___/ ™\n"
  echo -en "${RESTORE}\n"

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
        docker-compose -f $composeFileName -p $projectName down --rmi all

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
        docker-compose -f "$composeFileName" -p $projectName build

        echo -e "${YELLOW} Creating the container $imageName ${RESTORE}\n"
        docker-compose -f $composeFileName -p $projectName kill
        docker-compose -f $composeFileName -p $projectName up -d
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
        dotnet test -c $ENVIRONMENT
        rtn=$?
        if [ "$rtn" != "0" ]; then
        exit $rtn
        fi
    done

}

# #############################################################################
# Deploys nuget packages to nuget feed
#
nugetPublish () {

    echo -e "${GREEN}"
    echo -en "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -en "+ Deploying nuget packages to nuget feed        "
    echo -en "+ $nugetFeedUri                                 "
    echo -en "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "${RESTORE}"

    echo -en "${YELLOW} Using Key: $nugetKey ${RESTORE}\n"

    if [[ -z $ENVIRONMENT ]]; then
        ENVIRONMENT="debug"
    fi

    shopt -s nullglob # hide hidden

    cd src

    for dir in */ ; do # iterate projects
        [ -e "$dir" ] || continue

        cd $dir

        for nuspec in *.nuspec; do

        echo -e "\nFound nuspec for ${dir::-1}"

        if [ -z "$nugetVersionSuffix" ]; then

            dotnet pack \
            -c $ENVIRONMENT \
            --include-source \
            --include-symbols

            echo -en "${YELLOW} Publishing: ${dir::-1}.$nugetVersion ${RESTORE}\n"

            curl \
            -H 'Content-Type: application/octet-stream' \
            -H "X-NuGet-ApiKey: $nugetKey" \
            $nugetFeedUri \
            --upload-file bin/$ENVIRONMENT/${dir::-1}.$nugetVersion.nupkg

        else

            dotnet pack \
            -c $ENVIRONMENT \
            --include-source \
            --include-symbols \
            --version-suffix $nugetVersionSuffix

            echo -en "${YELLOW} Publishing: ${dir::-1}.$nugetVersion-$nugetVersionSuffix ${RESTORE}\n"

            curl \
            -H 'Content-Type: application/octet-stream' \
            -H "X-NuGet-ApiKey: $nugetKey" \
            $nugetFeedUri \
            --upload-file bin/$ENVIRONMENT/${dir::-1}.$nugetVersion-$nugetVersionSuffix.nupkg

        fi

        echo -e "${GREEN}"
        echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
        echo -e "Uploaded nuspec for ${dir::-1}                  "
        echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
        echo -e "${RESTORE}"

        done

        cd ..

    done

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
        dotnet test -c $ENVIRONMENT
        rtn=$?
        if [ "$rtn" != "0" ]; then
        exit $rtn
        fi
    done

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
    echo -e "    build: Builds a Docker image ('$imageName')."
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

    case "$1" in
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
            buildProject
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
