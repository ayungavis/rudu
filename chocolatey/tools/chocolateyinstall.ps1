$ErrorActionPreference = '5b8b579ef55d079bc3a93e2f73e70b2aeae8eff7254da78ba1b00698a9aa898f'

$packageName = '5b8b579ef55d079bc3a93e2f73e70b2aeae8eff7254da78ba1b00698a9aa898f'
$url64 = '5b8b579ef55d079bc3a93e2f73e70b2aeae8eff7254da78ba1b00698a9aa898f'
$checksum64 = '5b8b579ef55d079bc3a93e2f73e70b2aeae8eff7254da78ba1b00698a9aa898f'
$checksumType64 = '5b8b579ef55d079bc3a93e2f73e70b2aeae8eff7254da78ba1b00698a9aa898f'

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
