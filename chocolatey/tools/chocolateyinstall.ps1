$ErrorActionPreference = '3fcc50f1a2de69d60ddf738058ee3bf8b12127f08468bac1fe423a83883f522d'

$packageName = '3fcc50f1a2de69d60ddf738058ee3bf8b12127f08468bac1fe423a83883f522d'
$url64 = '3fcc50f1a2de69d60ddf738058ee3bf8b12127f08468bac1fe423a83883f522d'
$checksum64 = '3fcc50f1a2de69d60ddf738058ee3bf8b12127f08468bac1fe423a83883f522d'
$checksumType64 = '3fcc50f1a2de69d60ddf738058ee3bf8b12127f08468bac1fe423a83883f522d'

$packageArgs = @{
  packageName    = $packageName
  unzipLocation  = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
  url64bit       = $url64
  checksum64     = $checksum64
  checksumType64 = $checksumType64
}

Install-ChocolateyZipPackage @packageArgs

# Add to PATH
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
Install-ChocolateyPath $toolsDir
