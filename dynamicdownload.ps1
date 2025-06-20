param(
    [Parameter(Mandatory = $true)]
    [string]$TYPE,  # e.g., zips, exes, files...

    [Parameter(Mandatory = $true)]
    [string]$NAME   # e.g., myfile
)


# === CONFIGURATION ===
$Host = ""
$TOKEN = "" # Whatever token.. 
$BaseURL = "http://$Host"
$BasePath = "" # The path for downloads

# === EXTENSION MAP ===
$ExtensionMap = @{
    "zips"       = "zip"
    "exes"       = "exe"
    "files"      = "txt"
    "images"     = "bmp"
    "installers" = "msi"
    "regedits"   = "reg"
}

if (-not $ExtensionMap.ContainsKey($TYPE)) {
    Write-Host "!> ERROR: Unknown TYPE '$TYPE'. Valid types: $($ExtensionMap.Keys -join ', ')"
    exit 1
}

$EXT = $ExtensionMap[$TYPE]
$URL = "$BaseURL/$TYPE/$NAME.$EXT"
$Destination = Join-Path $BasePath "$NAME.$EXT"
$ExtractPath = Join-Path $BasePath "$NAME"

# === PREPARE FOLDER ===
if (-not (Test-Path $BasePath)) {
    New-Item -ItemType Directory -Path $BasePath | Out-Null
}

if ($EXT -eq "zip" -and (Test-Path -Path $ExtractPath -PathType Container)) {
    Write-Host "!> '$ExtractPath' exists. Deleting it..."
    Remove-Item -Path $ExtractPath -Recurse -Force
}

# === STREAMED DOWNLOAD ===
Write-Host "> Downloading $TYPE from $URL"

$req = [System.Net.HttpWebRequest]::Create($URL)
$req.Method = "GET"
$req.Headers.Add("X-Auth-Token", $TOKEN)
$req.Timeout = 300000              # you can and probably should change the timeouts.
$req.ReadWriteTimeout = 300000     # you can and probably should change the timeouts.

try {
    $resp = $req.GetResponse()
    $stream = $resp.GetResponseStream()
    $target = [System.IO.File]::Create($Destination)

    $buffer = New-Object byte[] 8192
    while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $target.Write($buffer, 0, $read)
    }

    $target.Close()
    $stream.Close()
    $resp.Close()

    Write-Host "> Download complete: $Destination"
}
catch {
    Write-Error "!> Failed to download $URL"
    exit 1
}

# === OPTIONAL: Extract if ZIP ===
if ($EXT -eq "zip") {
    Write-Host "> Extracting ZIP..."
    Expand-Archive -Path $Destination -DestinationPath $ExtractPath -Force

    Write-Host "> Cleaning up ZIP file..."
    Remove-Item -Path $Destination -Force
}

Write-Host ">>> Done! $NAME.$EXT has been processed."
