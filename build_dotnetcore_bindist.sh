#!/bin/bash
set -euo pipefail
cd `dirname $0`
# --------------------------------------------------------------------
# A simple script that builds the core Ambrosia binary distribution.

# This script is REDUNDANT with the steps in `Dockerfile`.  The
# Dockerfile *could* just call this script, but then it would have one
# big build step instead of granular ones.
# --------------------------------------------------------------------

# Should be "net46" or "netcoreapp2.2".  Set a default if not set:
export AMBROSIA_DOTNET_FRAMEWORK="${AMBROSIA_DOTNET_FRAMEWORK:-netcoreapp2.2}"
# Release or Debug:
export AMBROSIA_DOTNET_CONF="${AMBROSIA_DOTNET_CONF:-Release}"

UNAME=`uname`
if [ $AMBROSIA_DOTNET_FRAMEWORK == "net46" ]; then
    PLAT=x64
    OS=Windows_NT
else
    # netcore gives an error on Ambrosia.csproj with x64...
    if [ "$UNAME" == Linux ];
    then PLAT=linux-x64
    elif [ "$UNAME" == Darwin ];
    then PLAT=osx-x64
    else PLAT=win10-x64
         OS=Windows_NT
    fi
fi

OUTDIR=`pwd`/bin
# Shorthands:
FMWK="${AMBROSIA_DOTNET_FRAMEWORK}"
CONF="${AMBROSIA_DOTNET_CONF}"
function buildit() {
    dir=$1
    shift
    dotnet publish --self-contained -o $dir -c $CONF -f $FMWK -r $PLAT $*
}


echo "Cleaning publish directory."
rm -rf $OUTDIR
mkdir -p $OUTDIR

echo "Output of 'dotnet --info':"
dotnet --info

# echo "Building with command: $BUILDIT"

echo
echo "Building AMBROSIA libraries/binaries"
echo "------------------------------------"
set -x
buildit $OUTDIR/runtime Ambrosia/Ambrosia/Ambrosia.csproj
buildit $OUTDIR/coord ImmortalCoordinator/ImmortalCoordinator.csproj
buildit $OUTDIR/unsafedereg DevTools/UnsafeDeregisterInstance/UnsafeDeregisterInstance.csproj
pushd $OUTDIR
ln -s runtime/Ambrosia Ambrosia
ln -s coord/ImmortalCoordinator
ln -s unsafedereg/UnsafeDeregisterInstance
popd
set +x

echo
echo "Building C# client tools"
echo "----------------------------------------"
set -x
buildit $OUTDIR/codegen Clients/CSharp/AmbrosiaCS/AmbrosiaCS.csproj
pushd $OUTDIR
ln -s codegen/AmbrosiaCS
popd
set +x

echo
echo "Copying deployment script and other included resources."
cp -a Scripts/runAmbrosiaService.sh bin/
# (cd bin; ln -s Ambrosia ambrosia || echo ok)
# We currently use this as a baseline source of dependencies for generated code:
cp -a Clients/CSharp/AmbrosiaCS/AmbrosiaCS.csproj bin/AmbrosiaCS.csproj

echo
echo "Building Native-code client library"
echo "----------------------------------------"
if [ "$UNAME" == Linux ]; then
    pushd Clients/C
    make publish || \
        echo "WARNING: Non-fatal error." && \
        echo "Successfully built a dotnet core distribution, but the native code wrapper failed to build."
    popd
elif [ "$UNAME" == Darwin ]; then
    echo "WARNING: not building native client for Mac OS."
else
    echo "WARNING: this script doesn't build the native client for Windows yet (FINISHME)"
fi

# echo
# echo "Removing unnecessary execute permissions"
# echo "----------------------------------------"
# chmod -x ./bin/*.dll ./bin/*.so ./bin/*.dylib ./bin/*.a 2>/dev/null || echo

echo
echo "Deduplicating output produced by separate dotnet publish calls"
echo "--------------------------------------------------------------"
if [ ${OS:+defined} ] && [ "$OS" == "Windows_NT" ];
then ./Scripts/dedup_bindist.sh squish
elif [ "$UNAME" == Darwin ];
then ./Scripts/dedup_bindist.sh symlink
else ./Scripts/dedup_bindist.sh symlink
fi

echo "$0 Finished"
