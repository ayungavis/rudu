$ErrorActionPreference = 'Stop'

$packageName = 'rudu'
$url64 = 'https://github.com/ayungavis/rudu/releases/download/v0.1.0/rudu-windows-x86_64.zip'
$checksum64 = '0000000000000000000000000000000000000000000000000000000000000000'
$checksumType64 = 'sha256'

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
