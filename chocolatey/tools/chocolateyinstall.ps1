$ErrorActionPreference = '9db18479559b28781dc342b9afa747be362c81050ef89f6a1879738e686c685e'

$packageName = '9db18479559b28781dc342b9afa747be362c81050ef89f6a1879738e686c685e'
$url64 = '9db18479559b28781dc342b9afa747be362c81050ef89f6a1879738e686c685e'
$checksum64 = '9db18479559b28781dc342b9afa747be362c81050ef89f6a1879738e686c685e'
$checksumType64 = '9db18479559b28781dc342b9afa747be362c81050ef89f6a1879738e686c685e'

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
