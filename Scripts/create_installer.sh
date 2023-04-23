#!/usr/bin/env bash

# This script is to help create the macOS installation package for distribtuing
# this macOS app using Developer ID Distribution.
#
# To run:
#   Scripts/create_installer.sh -u <apple-id> -p <password>
#
# If you've enabled 2FA for your Apple ID, you will need to get an app-specific password
# from appleid.apple.com and pass that as the argument for the -p switch.

APP_VERSION="0.0.1"
MIN_MACOS_VERSION="10.15.0"

APP_NAME="eduVPNProvisioning"
APP_ID="org.eduvpn.app.eduvpn-provisioning"
DEVELOPMENT_TEAM="ZYJ4TZX4UU"
INSTALLER_CERTIFICATE_CN="Developer ID Installer: SURF B.V. (ZYJ4TZX4UU)"

usage() { echo "Usage: $0 -u <apple-id> -p <apple-id-password>" 1>&2; exit 1; }

while getopts ":n:u:p:" o; do
    case "${o}" in
        u)
            u=${OPTARG}
            ;;
        p)
            p=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "${u}" ] || [ -z "${p}" ]; then
    usage
fi

echo "Creating installation package with:"
echo "  APP_NAME = ${APP_NAME}"
echo "  APP_ID = ${APP_ID}"
echo "  DEVELOPMENT_TEAM = ${DEVELOPMENT_TEAM}"
echo "  CERTIFICATE_CN=${CERTIFICATE_CN}"


APP_FILENAME="${APP_NAME}.app"

echo ""
echo -n "-> Checking app \"${APP_FILENAME}\"..."
date "+ (at %H:%M:%S)"

if [ -e "${APP_FILENAME}" ]; then
    spctl -vvv --assess -t exec "${APP_FILENAME}" 2>&1 | tee /tmp/spctl_app.log
    if grep -q accepted /tmp/spctl_app.log; then
        echo "App \"${APP_FILENAME}\" appears to be notarized."
    else
        echo "Error: App \"${APP_FILENAME}\" is not notarized. Not creating installer." 1>&2; exit 1;
    fi
    rm -rf /tmp/spctl_app.log
else
    echo "Error: App \"${APP_FILENAME}\" not found. Not creating installer." 1>&2; exit 1;
fi

PACKAGE_FILENAME="./${APP_NAME}_${APP_VERSION}.pkg"
echo ""
echo -n "-> Creating installer package \"${PACKAGE_FILENAME}\"..."
date "+ (at %H:%M:%S)"

mkdir -p ./tmp_scripts
echo -e "#!/usr/bin/env bash\nopen -n /Applications/${APP_NAME}.app --args -setup\nexit 0\n" > tmp_scripts/postinstall
chmod +x tmp_scripts/postinstall

pkgbuild --root "${APP_FILENAME}" --identifier ${APP_ID} --version ${APP_VERSION} --install-location "/Applications/${APP_NAME}.app" --min-os-version ${MIN_MACOS_VERSION} --sign "${CERTIFICATE_CN}" --scripts ./tmp_scripts ${PACKAGE_FILENAME}

rm -rf ./tmp_scripts

if [ $? -ne 0 ]; then
    exit 1
fi

echo ""
echo -n "-> Notarizing installer package \"${PACKAGE_FILENAME}\"..."
date "+ (at %H:%M:%S)"

xcrun notarytool submit ${PACKAGE_FILENAME} --apple-id "${u}" --password "${p}" --team-id ${DEVELOPMENT_TEAM} --wait

if [ $? -ne 0 ]; then
    exit 1
fi

echo ""
echo -n "-> Adding notarization information to package \"${PACKAGE_FILENAME}\"..."
date "+ (at %H:%M:%S)"

xcrun stapler staple ${PACKAGE_FILENAME}

if [ $? -ne 0 ]; then
    exit 1
fi

echo ""
echo -n "-> Checking installer package \"${PACKAGE_FILENAME}\"..."
date "+ (at %H:%M:%S)"

if [ -e "${PACKAGE_FILENAME}" ]; then
    spctl -vvv --assess -t install "${PACKAGE_FILENAME}" 2>&1 | tee /tmp/spctl_installer.log
    if grep -q accepted /tmp/spctl_installer.log; then
        echo "Looks good."
    else
        echo "Error: \"${PACKAGE_FILENAME}\" is not notarized." 1>&2; exit 1;
    fi
    rm -rf /tmp/spctl_installer.log
else
    echo "Error: \"${PACKAGE_FILENAME}\" is not found." 1>&2; exit 1;
fi

if [ $? -ne 0 ]; then
    exit 1
fi

echo ""
echo -n "-> Done"
date "+ (at %H:%M:%S)"

echo ""
echo "Notarized installation package is at: \"${PACKAGE_FILENAME}\""
