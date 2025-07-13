$ErrorActionPreference = 'b869fe313a5233e65c4003cddeaadc80f7147147300c6b808f1a32ae2c63a440'

$packageName = 'b869fe313a5233e65c4003cddeaadc80f7147147300c6b808f1a32ae2c63a440'
$url64 = 'b869fe313a5233e65c4003cddeaadc80f7147147300c6b808f1a32ae2c63a440'
$checksum64 = 'b869fe313a5233e65c4003cddeaadc80f7147147300c6b808f1a32ae2c63a440'
$checksumType64 = 'b869fe313a5233e65c4003cddeaadc80f7147147300c6b808f1a32ae2c63a440'

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
