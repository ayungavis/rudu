$ErrorActionPreference = 'ade7ffb128f4aa1d5a0d6b04aa597d1f2e9d7444f01889341d37b5da2a2c3910'

$packageName = 'ade7ffb128f4aa1d5a0d6b04aa597d1f2e9d7444f01889341d37b5da2a2c3910'
$url64 = 'ade7ffb128f4aa1d5a0d6b04aa597d1f2e9d7444f01889341d37b5da2a2c3910'
$checksum64 = 'ade7ffb128f4aa1d5a0d6b04aa597d1f2e9d7444f01889341d37b5da2a2c3910'
$checksumType64 = 'ade7ffb128f4aa1d5a0d6b04aa597d1f2e9d7444f01889341d37b5da2a2c3910'

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
