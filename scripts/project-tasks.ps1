<#
.SYNOPSIS
	Project tasks
.PARAMETER Compose
	Runs docker-compose.
.PARAMETER Build
	Builds a Docker image.
.PARAMETER Clean
	Removes the image test_image and kills all containers based on that image.
.PARAMETER ComposeForDebug
    Builds the image and runs docker-compose.
.PARAMETER IntegrationTests
    Builds the image and runs docker-compose and executes the integration tests.
.PARAMETER NuGetPublish
	Deploys the NuGet projects.
.PARAMETER UnitTests
	Builds the image and runs the unit tests.
.PARAMETER Environment
	The enviorment to build for (Debug or Release), defaults to Debug
.EXAMPLE
	C:\PS> .\project-tasks.ps1 -Build (Build a Docker image named test_image)
#>

[CmdletBinding(PositionalBinding = $false)]
Param(
    [Parameter(Mandatory = $True, ParameterSetName = "Build")]
    [switch]$Build,
    [Parameter(Mandatory = $True, ParameterSetName = "Clean")]
    [switch]$Clean,
    [Parameter(Mandatory = $True, ParameterSetName = "Compose")]
    [switch]$Compose,
    [Parameter(Mandatory = $True, ParameterSetName = "ComposeForDebug")]
    [switch]$ComposeForDebug,
    [Parameter(Mandatory = $True, ParameterSetName = "IntegrationTests")]
    [switch]$IntegrationTests,
    [Parameter(Mandatory = $True, ParameterSetName = "NuGetPublish")]
    [switch]$NuGetPublish,
    [Parameter(Mandatory = $True, ParameterSetName = "UnitTests")]
    [switch]$UnitTests,
    [parameter(ParameterSetName = "Build")]
    [parameter(ParameterSetName = "Clean")]
    [parameter(ParameterSetName = "Compose")]
    [Parameter(ParameterSetName = "ComposeForDebug")]
    [parameter(ParameterSetName = "IntegrationTests")]
    [parameter(ParameterSetName = "NuGetPublish")]
    [parameter(ParameterSetName = "UnitTests")]
    [ValidateNotNullOrEmpty()]
    [String]$Environment = "Debug"
)

$framework = "netcoreapp2.0"
$imageName = "envoice-mongoidentity"
$nugetFeedUri="https://www.myget.org/F/envoice/api/v2"
$nugetKey=$Env:MYGET_KEY_ENVOICE
$nugetVersion = "1.0.0"
$nugetVersionSuffix = "rc3"
$projectName = "envoice-mongoidentity"
$runtimeID = "debian.8-x64"

# Welcome message
function Welcome () {

    Write-Host "                         _          " -ForegroundColor "Blue"
    Write-Host "  ___  ____ _   ______  (_)_______  " -ForegroundColor "Blue"
    Write-Host " / _ \/ __ \ | / / __ \/ / ___/ _ \ " -ForegroundColor "Blue"
    Write-Host "/  __/ / / / |/ / /_/ / / /__/  __/ " -ForegroundColor "Blue"
    Write-Host "\___/_/ /_/|___/\____/_/\___/\___/  " -ForegroundColor "Blue"
    Write-Host ""
}

# Builds the project
function BuildProject () {

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"
    Write-Host "+ Building $projectName                         " -ForegroundColor "Green"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"

    $pubFolder = "bin\$Environment\$framework\publish"
    Write-Host "Building the project ($ENVIRONMENT) into $pubFolder." -ForegroundColor "Yellow"

    dotnet restore
    dotnet publish $solutionName -f $framework -r $runtimeID -c $Environment -o $pubFolder -v quiet
}

# Builds the Docker image.
function BuildImage () {

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"
    Write-Host "+ Building docker image                         " -ForegroundColor "Green"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"

    $composeFileName = "docker-compose.yml"
    if ($Environment -ne "Debug") {
        $composeFileName = "docker-compose.$Environment.yml"
    }

    if (Test-Path $composeFileName) {
        Write-Host "Building the image $imageName ($Environment)." -ForegroundColor "Yellow"
        docker-compose -f "$composeFileName" -p $projectName build
    }
    else {
        Write-Error -Message "$Environment is not a valid parameter. File '$composeFileName' does not exist." -Category InvalidArgument
    }
}

# Kills all running containers of an image and then removes them.
function CleanAll () {

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"
    Write-Host "+ Cleaning projects and docker images           " -ForegroundColor "Green"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"

    dotnet clean

    $composeFileName = "docker-compose.yml"
    if ($Environment -ne "Debug") {
        $composeFileName = "docker-compose.$Environment.yml"
    }

    if (Test-Path $composeFileName) {
        docker-compose -f "$composeFileName" -p $projectName down --rmi all

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

# Runs docker-compose.
function Compose () {

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"
    Write-Host "+ Composing docker images                       " -ForegroundColor "Green"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"

    $composeFileName = "docker-compose.yml"
    if ($Environment -ne "Debug") {
        $composeFileName = "docker-compose.$Environment.yml"
    }

    if (Test-Path $composeFileName) {
        Write-Host "Running compose file $composeFileName" -ForegroundColor "Yellow"
        docker-compose -f $composeFileName -p $projectName kill
        docker-compose -f $composeFileName -p $projectName up -d
    }
    else {
        Write-Error -Message "$Environment is not a valid parameter. File '$dockerFileName' does not exist." -Category InvalidArgument
    }
}

# Runs the integration tests.
function IntegrationTests () {

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"
    Write-Host "+ Running integration tests                     " -ForegroundColor "Green"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"

    Set-Location test

    Get-ChildItem -Directory -Filter "*.IntegrationTests*" |
        ForEach-Object {
        Set-Location $_.FullName # or whatever
        dotnet test
        Set-Location ..
    }

}

# Deploys nuget packages to myget feed
function NuGetPublish () {

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"
    Write-Host "+ Deploying nuget packages to myget feed        " -ForegroundColor "Green"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"

    Write-Host "Using Key: $nugetKey" -ForegroundColor "Yellow"

    Set-Location src

    Get-ChildItem -Filter "*.nuspec" -Recurse -Depth 1 |
        ForEach-Object {

        $packageName = $_.BaseName
        Set-Location $_.BaseName

        if ($nugetVersionSuffix) {

            dotnet pack -c $Environment --include-source --include-symbols --version-suffix $nugetVersionSuffix

            Write-Host "Publishing: $packageName.$nugetVersion-$nugetVersionSuffix" -ForegroundColor "Yellow"

            Invoke-WebRequest `
                -uri $nugetFeedUri `
                -InFile "bin/$Environment/$packageName.$nugetVersion-$nugetVersionSuffix.nupkg" `
                -Headers @{"X-NuGet-ApiKey" = "$nugetKey"} `
                -Method "PUT" `
                -ContentType "multipart/form-data"

        }
        else {

            dotnet pack -c $Environment --include-source --include-symbols

            Write-Host "Publishing: $packageName.$nugetVersion" -ForegroundColor "Yellow"

            Invoke-WebRequest `
                -uri $nugetFeedUri `
                -InFile "bin/$Environment/$packageName.$nugetVersion.nupkg" `
                -Headers @{"X-nuget-ApiKey" = "$nugetKey"} `
                -Method "PUT" `
                -ContentType "multipart/form-data"

        }

        Set-Location ..
    }

}

# Runs the unit tests.
function UnitTests () {

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"
    Write-Host "+ Running unit tests                            " -ForegroundColor "Green"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"

    Set-Location test

    Get-ChildItem -Directory -Filter "*.UnitTests*" |
        ForEach-Object {
        Set-Location $_.FullName # or whatever
        dotnet test
        Set-Location ..
    }

}

$Environment = $Environment.ToLowerInvariant()

# Call the correct function for the parameter that was used

Welcome

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
    BuildImage
    Compose
}
elseif ($IntegrationTests) {
    BuildProject
    BuildImage
    Compose
    IntegrationTests
}
elseif ($NuGetPublish) {
    NuGetPublish
}
elseif ($UnitTests) {
    BuildProject
    UnitTests
}
