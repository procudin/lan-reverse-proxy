$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
docker build -t lan-reverse-proxy-builder $root
if ($LASTEXITCODE) { throw 'Failed to build the package builder image' }

docker run --rm --user root `
    -v owrt-cache:/cache -e CACHE_DIR=/cache `
    -v "${root}:/work" `
    lan-reverse-proxy-builder bash /work/scripts/build-apk.sh
exit $LASTEXITCODE
