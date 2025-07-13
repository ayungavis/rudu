$ErrorActionPreference = '711d5bdecd6f3e6b4eb80e7ea1c8eec8ba0cf54a085218d34af16473ba9381f1'

$packageName = '711d5bdecd6f3e6b4eb80e7ea1c8eec8ba0cf54a085218d34af16473ba9381f1'
$url64 = '711d5bdecd6f3e6b4eb80e7ea1c8eec8ba0cf54a085218d34af16473ba9381f1'
$checksum64 = '711d5bdecd6f3e6b4eb80e7ea1c8eec8ba0cf54a085218d34af16473ba9381f1'
$checksumType64 = '711d5bdecd6f3e6b4eb80e7ea1c8eec8ba0cf54a085218d34af16473ba9381f1'

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
