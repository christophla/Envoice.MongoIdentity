<#
.SYNOPSIS
	Project tasks
.PARAMETER Build
	Builds a Docker image.
.PARAMETER Clean
	Removes the image test_image and kills all containers based on that image.
.PARAMETER Compose
	Runs docker-compose.
.PARAMETER ComposeForDebug
    Builds the image and runs docker-compose.
.PARAMETER IntegrationTests
    Builds the image and runs docker-compose and executes the integration tests.
.PARAMETER NuGetPublish
	Deploys the NuGet projects.
.PARAMETER UnitTests
	Builds the image and runs the unit tests.
.PARAMETER Environment
	The environment to build for (Debug or Release), defaults to Debug
.PARAMETER Quiet
	Hides the welcome message
.EXAMPLE
	C:\PS> .\project-tasks.ps1 -Build (Build a Docker image named test_image)
#>

# #############################################################################
# Params
#
[CmdletBinding(PositionalBinding = $false)]
Param(
    [switch]$Build,
    [switch]$Clean,
    [switch]$Compose,
    [switch]$ComposeForDebug,
    [switch]$IntegrationTests,
    [switch]$NuGetPublish,
    [switch]$TestAll,
    [switch]$UnitTests,
    [switch]$Quiet,
    [ValidateNotNullOrEmpty()]
    [String]$Environment = "Debug"
)


# #############################################################################
# Settings
#
$Environment = $Environment.ToLowerInvariant()
$Framework = "netstandard2.0"
$NugetFeedUri = "https://www.myget.org/F/envoice/api/v3/index.json"
$NugetKey = $Env:MYGET_KEY_ENVOICE
$NugetVersionSuffix = ""
$ROOT_DIR = (Get-Item -Path ".\" -Verbose).FullName


# #############################################################################
# Welcome message
#
Function Welcome () {

    Write-Host "                     _         " -ForegroundColor "Blue"
    Write-Host "  ___ ___ _  _____  (_)______  " -ForegroundColor "Blue"
    Write-Host " / -_) _ \ |/ / _ \/ / __/ -_) " -ForegroundColor "Blue"
    Write-Host " \__/_//_/___/\___/_/\__/\__/  " -ForegroundColor "Blue"
    Write-Host ""

}


# #############################################################################
# Builds the project
#
Function BuildProject () {

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"
    Write-Host "+ Building $ProjectName                         " -ForegroundColor "Green"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"

    $pubFolder = "bin\$Environment\$Framework\publish"
    Write-Host "Building the project ($Environment) into $pubFolder." -ForegroundColor "Yellow"

    dotnet restore
    dotnet publish -c $Environment -o $pubFolder -v quiet
}


# #############################################################################
# Builds the Docker image
#
Function BuildImage () {

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"
    Write-Host "+ Building docker image                         " -ForegroundColor "Green"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"

    $composeFileName = "docker-compose.yml"
    if ($Environment -ne "Debug") {
        $composeFileName = "docker-compose.$Environment.yml"
    }

    if (Test-Path $composeFileName) {
        Write-Host "Building the image $ImageName ($Environment)." -ForegroundColor "Yellow"
        docker-compose -f "$composeFileName" build
    }
    else {
        Write-Error -Message "$Environment is not a valid parameter. File '$composeFileName' does not exist." -Category InvalidArgument
    }
}


# #############################################################################
# Kills all running containers of an image and then removes them
#
Function CleanAll () {

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"
    Write-Host "+ Cleaning projects and docker images           " -ForegroundColor "Green"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"

    dotnet clean

    $composeFileName = "docker-compose.yml"
    if ($Environment -ne "Debug") {
        $composeFileName = "docker-compose.$Environment.yml"
    }

    if (Test-Path $composeFileName) {
        docker-compose -f "$composeFileName" down --rmi all

        $danglingImages = $(docker images -q --filter 'dangling=true')
        if (-not [String]::IsNullOrWhiteSpace($danglingImages)) {
            docker rmi -f $danglingImages
        }
        Write-Host "Removed docker images" -ForegroundColor "Yellow"
    }
    else {
        Write-Error -Message "$Environment is not a valid parameter. File '$composeFileName' does not exist." -Category InvalidArgument
    }
}


# #############################################################################
# Runs docker-compose
#
Function Compose () {

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"
    Write-Host "+ Composing docker images                       " -ForegroundColor "Green"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"

    $composeFileName = "docker-compose.yml"
    if ($Environment -ne "Debug") {
        $composeFileName = "docker-compose.$Environment.yml"
    }

    if (Test-Path $composeFileName) {
        Write-Host "Running compose file $composeFileName" -ForegroundColor "Yellow"
        docker-compose -f $composeFileName kill
        docker-compose -f $composeFileName up -d
    }
    else {
        Write-Error -Message "$Environment is not a valid parameter. File '$dockerFileName' does not exist." -Category InvalidArgument
    }
}


# #############################################################################
# Runs the integration tests
#
Function IntegrationTests () {

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"
    Write-Host "+ Running integration tests                     " -ForegroundColor "Green"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"

    Set-Location test

    Get-ChildItem -Directory -Filter "*.IntegrationTests*" |
        ForEach-Object {
        Set-Location $_.FullName
        dotnet test -c $Environment /p:CollectCoverage=true /p:CoverletOutputFormat=opencover
        Set-Location ..
    }

}


# #############################################################################
# Deploys Nuget packages to myget feed
#
Function NuGetPublish () {

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"
    Write-Host "+ Deploying Nuget packages to myget feed        " -ForegroundColor "Green"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"

    Write-Host "Using Key: $NugetKey" -ForegroundColor "Yellow"

    Set-Location src

    Get-ChildItem -Filter "*.nuspec" -Recurse -Depth 1 |
        ForEach-Object {

        $packageName = $_.BaseName
        Set-Location $_.BaseName

        if ($NugetVersionSuffix) {

            dotnet pack -c $Environment --include-source --include-symbols --version-suffix $NugetVersionSuffix

            Write-Host "Publishing: $packageName.$NugetVersion-$NugetVersionSuffix" -ForegroundColor "Yellow"

            Invoke-WebRequest `
                -uri $NugetFeedUri `
                -InFile "bin/$Environment/$packageName.$NugetVersion-$NugetVersionSuffix.nupkg" `
                -Headers @{"X-NuGet-ApiKey" = "$NugetKey"} `
                -Method "PUT" `
                -ContentType "multipart/form-data"

        }
        else {

            dotnet pack -c $Environment --include-source --include-symbols

            Write-Host "Publishing: $packageName.$NugetVersion" -ForegroundColor "Yellow"

            Invoke-WebRequest `
                -uri $NugetFeedUri `
                -InFile "bin/$Environment/$packageName.$NugetVersion.nupkg" `
                -Headers @{"X-Nuget-ApiKey" = "$NugetKey"} `
                -Method "PUT" `
                -ContentType "multipart/form-data"

        }

        Set-Location ..
    }

}


# #############################################################################
# Runs the unit tests
#
Function UnitTests () {

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"
    Write-Host "+ Running unit tests                            " -ForegroundColor "Green"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"

    Set-Location test

    Get-ChildItem -Directory -Filter "*.UnitTests*" |
        ForEach-Object {
        Set-Location $_.FullName # or whatever
        dotnet test -c $Environment /p:CollectCoverage=true /p:CoverletOutputFormat=opencover
        Set-Location ..
    }

}


# #############################################################################
# Call the correct Function for the parameter that was used
#

If(!$Quiet) { Welcome }

if ($Build) {
    BuildProject
    BuildImage
}
elseif ($Clean) {
    CleanAll
}
elseif ($Compose) {
    Compose
}
elseif ($ComposeForDebug) {
    $env:REMOTE_DEBUGGING = "enabled"
    BuildProject
    #BuildImage
    Compose
}
elseif ($IntegrationTests) {
    #BuildProject
    #Compose
    IntegrationTests
}
elseif ($NuGetPublish) {
    NuGetPublish
}
elseif ($UnitTests) {
    BuildProject
    UnitTests
}


# #############################################################################
