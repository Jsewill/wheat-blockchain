#!/bin/bash

if [ ! "$1" ]; then
  echo "This script requires either amd64 of arm64 as an argument"
	exit 1
elif [ "$1" = "amd64" ]; then
	#PLATFORM="$1"
	REDHAT_PLATFORM="x86_64"
	DIR_NAME="wheat-blockchain-linux-x64"
else
	#PLATFORM="$1"
	DIR_NAME="wheat-blockchain-linux-arm64"
fi

pip install setuptools_scm
# The environment variable WHEAT_INSTALLER_VERSION needs to be defined
# If the env variable NOTARIZE and the username and password variables are
# set, this will attempt to Notarize the signed DMG
WHEAT_INSTALLER_VERSION=$(python installer-version.py)

if [ ! "$WHEAT_INSTALLER_VERSION" ]; then
	echo "WARNING: No environment variable WHEAT_INSTALLER_VERSION set. Using 0.0.0."
	WHEAT_INSTALLER_VERSION="0.0.0"
fi
echo "Wheat Installer Version is: $WHEAT_INSTALLER_VERSION"

echo "Installing npm and electron packagers"
npm install electron-packager -g
npm install electron-installer-redhat -g

echo "Create dist/"
rm -rf dist
mkdir dist

echo "Create executables with pyinstaller"
pip install pyinstaller==4.2
SPEC_FILE=$(python -c 'import wheat; print(wheat.PYINSTALLER_SPEC_PATH)')
pyinstaller --log-level=INFO "$SPEC_FILE"
LAST_EXIT_CODE=$?
if [ "$LAST_EXIT_CODE" -ne 0 ]; then
	echo >&2 "pyinstaller failed!"
	exit $LAST_EXIT_CODE
fi

cp -r dist/daemon ../wheat-blockchain-gui
cd .. || exit
cd wheat-blockchain-gui || exit

echo "npm build"
npm install
npm audit fix
npm run build
LAST_EXIT_CODE=$?
if [ "$LAST_EXIT_CODE" -ne 0 ]; then
	echo >&2 "npm run build failed!"
	exit $LAST_EXIT_CODE
fi

electron-packager . wheat-blockchain --asar.unpack="**/daemon/**" --platform=linux \
--icon=src/assets/img/Wheat.icns --overwrite --app-bundle-id=net.wheat.blockchain \
--appVersion=$WHEAT_INSTALLER_VERSION
LAST_EXIT_CODE=$?
if [ "$LAST_EXIT_CODE" -ne 0 ]; then
	echo >&2 "electron-packager failed!"
	exit $LAST_EXIT_CODE
fi

mv $DIR_NAME ../build_scripts/dist/
cd ../build_scripts || exit

if [ "$REDHAT_PLATFORM" = "x86_64" ]; then
	echo "Create wheat-blockchain-$WHEAT_INSTALLER_VERSION.rpm"
  electron-installer-redhat --src dist/$DIR_NAME/ --dest final_installer/ \
  --arch "$REDHAT_PLATFORM" --options.version $WHEAT_INSTALLER_VERSION \
  --license ../LICENSE
  LAST_EXIT_CODE=$?
  if [ "$LAST_EXIT_CODE" -ne 0 ]; then
	  echo >&2 "electron-installer-redhat failed!"
	  exit $LAST_EXIT_CODE
  fi
fi

ls final_installer/
