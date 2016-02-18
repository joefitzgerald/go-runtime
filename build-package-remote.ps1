Set-StrictMode -Version Latest
$script:ATOM_CHANNEL = "stable"
$script:ATOM_DIRECTORY_NAME = "Atom"
if ($env:ATOM_CHANNEL) {
    $script:ATOM_CHANNEL = "$env:ATOM_CHANNEL"
    $script:ATOM_DIRECTORY_NAME = "$script:ATOM_DIRECTORY_NAME "
    $script:ATOM_DIRECTORY_NAME += "$script:ATOM_CHANNEL.substring(0,1).toupper()"
    $script:ATOM_DIRECTORY_NAME += "$script:ATOM_CHANNEL.substring(1).tolower()"
}
$script:ATOM_SCRIPT_PATH = "$PSScriptRoot\$script:ATOM_DIRECTORY_NAME\resources\cli\atom.cmd"
$script:APM_SCRIPT_PATH = "$PSScriptRoot\$script:ATOM_DIRECTORY_NAME\resources\app\apm\bin\apm.cmd"


function DownloadAtom() {
    Write-Host "Downloading latest Atom release..."
    $source = "https://atom.io/download/windows_zip?channel=$ATOM_CHANNEL"
    $destination = "$PSScriptRoot\atom.zip"
    Start-BitsTransfer -Source $source -Description "Downloading Atom" -Destination $destination -DisplayName $source -ErrorAction Stop
}

function ExtractAtom() {
    Remove-Item "$PSScriptRoot\$script:ATOM_DIRECTORY_NAME" -Recurse -ErrorAction Ignore
    Unzip "$PSScriptRoot\atom.zip" "$PSScriptRoot"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

function PrintVersions() {
    Write-Host -NoNewLine "Using Atom version: "
    & "$ATOM_SCRIPT_PATH" -v
    if ($LASTEXITCODE -ne 0) {
        ExitWithCode -exitcode $LASTEXITCODE
    }
    Write-Host "Using APM version: "
    & "$APM_SCRIPT_PATH" -v
    if ($LASTEXITCODE -ne 0) {
        ExitWithCode -exitcode $LASTEXITCODE
    }
}

function InstallPackage() {
    Write-Host "Downloading package dependencies..."
    & "$APM_SCRIPT_PATH" clean
    if ($LASTEXITCODE -ne 0) {
        ExitWithCode -exitcode $LASTEXITCODE
    }
    & "$APM_SCRIPT_PATH" install
    if ($LASTEXITCODE -ne 0) {
        ExitWithCode -exitcode $LASTEXITCODE
    }
    InstallDependencies
}

function InstallDependencies() {
    if ($env:APM_TEST_PACKAGES) {
        Write-Host "Installing atom package dependencies..."
        $APM_TEST_PACKAGES = $env:APM_TEST_PACKAGES -split "\s+"
        $APM_TEST_PACKAGES | foreach {
            Write-Host "$_"
            & "$APM_SCRIPT_PATH" install $_
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }
    }
}

function RunLinters() {
    $libpath = "$PSScriptRoot\lib"
    $libpathexists = Test-Path $libpath
    $srcpath = "$PSScriptRoot\src"
    $srcpathexists = Test-Path $srcpath
    $specpath = "$PSScriptRoot\spec"
    $specpathexists = Test-Path $specpath
    $coffeelintpath = "$PSScriptRoot\node_modules\.bin\coffeelint.cmd"
    $coffeelintpathexists = Test-Path $coffeelintpath
    $eslintpath = "$PSScriptRoot\node_modules\.bin\eslint.cmd"
    $eslintpathexists = Test-Path $eslintpath
    $standardpath = "$PSScriptRoot\node_modules\.bin\standard.cmd"
    $standardpathexists = Test-Path $standardpath
    if (($libpathexists -or $srcpathexists) -and ($coffeelintpathexists -or $eslintpathexists -or $standardpathexists)) {
        Write-Host "Linting package..."
    }

    if ($libpathexists) {
        if ($coffeelintpathexists) {
            & "$coffeelintpath" lib
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }

        if ($eslintpathexists) {
            & "$eslintpath" lib
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }

        if ($standardpathexists) {
            & "$standardpath" lib/**/*.js
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }
    }

    if ($srcpathexists) {
        if ($coffeelintpathexists) {
            & "$coffeelintpath" src
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }

        if ($eslintpathexists) {
            & "$eslintpath" src
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }

        if ($standardpathexists) {
            & "$standardpath" src/**/*.js
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }
    }

    if ($specpathexists -and ($coffeelintpathexists -or $eslintpathexists -or $standardpathexists)) {
        Write-Host "Linting package specs..."
        if ($coffeelintpathexists) {
            & "$coffeelintpath" spec
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }

        if ($eslintpathexists) {
            & "$eslintpath" spec
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }

        if ($standardpathexists) {
            & "$standardpath" spec/**/*.js
            if ($LASTEXITCODE -ne 0) {
                ExitWithCode -exitcode $LASTEXITCODE
            }
        }
    }
}

function RunSpecs() {
    $specpath = "$PSScriptRoot\spec"
    $specpathexists = Test-Path $specpath
    if (!$specpath) {
        Write-Host "Missing spec folder! Please consider adding a test suite in '.\spec'"
        ExitWithCode -exitcode 1
    }
    Write-Host "Running specs..."
    & "$ATOM_SCRIPT_PATH" --test spec
    if ($LASTEXITCODE -ne 0) {
        ExitWithCode -exitcode $LASTEXITCODE
    }
}

function ExitWithCode
{
    param
    (
        $exitcode
    )

    $host.SetShouldExit($exitcode)
    exit
}

DownloadAtom
ExtractAtom
PrintVersions
InstallPackage
RunLinters
RunSpecs
