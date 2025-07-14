$ErrorActionPreference = 'e4c09bf09d31aee6b92cca518a1d33ce37ff7608fdedefa9967a72e00c4e84b8'

$packageName = 'e4c09bf09d31aee6b92cca518a1d33ce37ff7608fdedefa9967a72e00c4e84b8'
$url64 = 'e4c09bf09d31aee6b92cca518a1d33ce37ff7608fdedefa9967a72e00c4e84b8'
$checksum64 = 'e4c09bf09d31aee6b92cca518a1d33ce37ff7608fdedefa9967a72e00c4e84b8'
$checksumType64 = 'e4c09bf09d31aee6b92cca518a1d33ce37ff7608fdedefa9967a72e00c4e84b8'

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
