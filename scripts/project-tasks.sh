#!/bin/bash

# #############################################################################
# Project tasks
#

framework="netcoreapp2.0"
imageName="envoice-mongoidentity"
nugetFeedUri="https://www.myget.org/F/envoice/api/v2"
nugetKey=$MYGET_KEY_ENVOICE
nugetVersion="1.0.0"
nugetVersionSuffix="rc2"
projectName="envoice-mongoidentity"
runtimeID="debian.8-x64"

BLUE="\033[00;34m"
GREEN='\033[00;32m'
RED='\033[00;31m'
RESTORE='\033[0m'
YELLOW='\033[00;33m'

# Welcome message
welcome () {

  echo -en "${BLUE}\n"
  echo -en "                         _          \n"
  echo -en "  ___  ____ _   ______  (_)_______  \n"
  echo -en " / _ \/ __ \ | / / __ \/ / ___/ _ \ \n"
  echo -en "/  __/ / / / |/ / /_/ / / /__/  __/ \n"
  echo -en "\___/_/ /_/|___/\____/_/\___/\___/ ™\n"
  echo -en "${RESTORE}\n"

}

# Builds the project.
buildProject () {

  echo -en "${GREEN}\n"
  echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
  echo -e "+ Building $projectName                         "
  echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
  echo -en "${RESTORE}\n"

  if [[ -z $ENVIRONMENT ]]; then
    ENVIRONMENT="debug"
  fi

  composeFileName="docker-compose.yml"
  if [[ $ENVIRONMENT != "debug" ]]; then
    composeFileName="docker-compose.$ENVIRONMENT.yml"
  fi

  pubFolder="bin/$ENVIRONMENT/$framework/publish"
  echo -e "${YELLOW} Building the project $solutionName ($ENVIRONMENT) into $pubFolder ${RESTORE}\n"

  dotnet restore
  dotnet publish $solutionName -f $framework -r $runtimeID -c $ENVIRONMENT -o $pubFolder -v quiet
}

# Builds the Docker image.
buildImage () {

  echo -en "${GREEN}\n"
  echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
  echo -e "+ Building docker image                         "
  echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
  echo -en "${RESTORE}\n"

  if [[ -z $ENVIRONMENT ]]; then
    ENVIRONMENT="debug"
  fi

  composeFileName="docker-compose.yml"
  if [[ $ENVIRONMENT != "debug" ]]; then
    composeFileName="docker-compose.$ENVIRONMENT.yml"
  fi

  if [[ ! -f $composeFileName ]]; then
    echo -e "${YELLOW} $ENVIRONMENT is not a valid parameter. File '$composeFileName' does not exist. ${RESTORE}\n"
  else
    pubFolder="bin/$ENVIRONMENT/$framework/publish"

    echo -e "${YELLOW} Building the image $imageName ($ENVIRONMENT). ${RESTORE}\n"
    docker-compose -f "$composeFileName" -p $projectName build
  fi
}

# Kills all running containers of an image and then removes them.
cleanAll() {

  echo -en "${GREEN}\n"
  echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
  echo -e "+ Cleaning projects and docker images           "
  echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
  echo -en "${RESTORE}\n"

  dotnet clean

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

# Runs docker-compose.
compose () {

  echo -en "${GREEN}\n"
  echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
  echo -e "+ Composing docker images                       "
  echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
  echo -en "${RESTORE}\n"

  composeFileName="docker-compose.yml"

  if [[ $ENVIRONMENT != "debug" ]]; then
      composeFileName="docker-compose.$ENVIRONMENT.yml"
  fi

  if [[ ! -f $composeFileName ]]; then
    echo -e "${RED} $ENVIRONMENT is not a valid parameter. File '$composeFileName' does not exist. ${RESTORE}\n"
  else
    echo -e "${YELLOW} Running compose file $composeFileName ${RESTORE}\n"
    docker-compose -f $composeFileName -p $projectName kill
    docker-compose -f $composeFileName -p $projectName up -d
  fi
}

# Runs the integration tests.
integrationTests () {

  echo -en "${GREEN}\n"
  echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
  echo -e "+ Running integration tests                     "
  echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
  echo -en "${RESTORE}\n"

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

# Deploys nuget packages to nuget feed
nugetPublish () {

  echo -en "${GREEN}\n"
  echo -e  "++++++++++++++++++++++++++++++++++++++++++++++++"
  echo -e  "+ Deploying nuget packages to nuget feed        "
  echo -e  "+ $nugetFeedUri                                 "
  echo -e  "++++++++++++++++++++++++++++++++++++++++++++++++"
  echo -en "${RESTORE}\n"

  if [ -z "$nugetKey" ]; then
    echo -en "${RED}\n"
    echo "You must set the MYGET_KEY_ENVOICE environment variable"
    echo -en "${RESTORE}\n"
    exit 1
  fi

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

      echo -en "${GREEN}\n"
      echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
      echo -e "Uploaded nuspec for ${dir::-1}                  "
      echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
      echo -en "${RESTORE}\n"

    done

    cd ..

  done

}

# Runs the unit tests.
unitTests () {

  echo -en "${GREEN}\n"
  echo -e  "++++++++++++++++++++++++++++++++++++++++++++++++"
  echo -e  "+ Running unit tests                            "
  echo -e  "++++++++++++++++++++++++++++++++++++++++++++++++"
  echo -en "${RESTORE}\n"

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

# Shows the usage for the script.
showUsage () {
  echo -en "${YELLOW}\n"
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
  echo -e "    unitTests: Runs all unit test projects with *UnitTests* in the project name."
  echo -e ""
  echo -e "Environments:"
  echo -e "    debug: Uses debug environment."
  echo -e "    release: Uses release environment."
  echo -e ""
  echo -e "Example:"
  echo -e "    ./project-tasks.sh build debug"
  echo -e ""
  echo -e "    This will:"
  echo -e "        Build a Docker image named $imageName using debug environment."
  echo -en "${RESTORE}\n"
}

if [ $# -eq 0 ]; then
  showUsage
else
  welcome
  case "$1" in
    "build")
            ENVIRONMENT=$(echo -e $2 | tr "[:upper:]" "[:lower:]")
            buildProject
            buildImage
            ;;
    "clean")
            ENVIRONMENT=$(echo -e $2 | tr "[:upper:]" "[:lower:]")
            cleanAll
            ;;
    "compose")
            ENVIRONMENT=$(echo -e $2 | tr "[:upper:]" "[:lower:]")
            compose
            ;;
    "composeForDebug")
            ENVIRONMENT=$(echo -e $2 | tr "[:upper:]" "[:lower:]")
            export REMOTE_DEBUGGING="enabled"
            buildProject
            buildImage
            compose
            ;;
    "integrationTests")
            ENVIRONMENT=$(echo -e $2 | tr "[:upper:]" "[:lower:]")
            buildProject
            buildImage
            compose
            integrationTests
            ;;
    "nugetPublish")
            ENVIRONMENT=$(echo -e $2 | tr "[:upper:]" "[:lower:]")
            buildProject
            nugetPublish
            ;;
    "unitTests")
            ENVIRONMENT=$(echo -e $2 | tr "[:upper:]" "[:lower:]")
            buildProject
            unitTests
            ;;
    *)
            showUsage
            ;;
  esac
fi
