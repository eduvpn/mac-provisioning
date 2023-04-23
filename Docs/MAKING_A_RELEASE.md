# Making a Release

This macOS app is meant to be distributed as a package using Developer ID Distribution.

It cannot be distributed through the Mac App Store.

## Before a Release

### Install Command-Line Dependencies

SwiftLint and Go need to be installed. The build setup looks for these in the paths that HomeBrew installs into.

To install, run:
~~~
brew install swiftlint go
~~~

Go version 1.19 is required.

### Setup the xcconfig

The app name, app id, and development team should be specified in the xcconfig.

~~~
cd eduVPNProvisioning/Config/
cp Developer.xcconfig.template Developer.xcconfig
vim Developer.xcconfig # Edit as required
~~~

### Get Provisioning Profiles

See [CREATING_PROVISIONING_PROFILES.md][] for information on how to create the
provisioning profiles in the Apple Developer Account website.

This needs to be done when we create the first release of the app -- not for
every release.

## Creating the Release

### Bump version

Ensure that the app version is correctly bumped up in:

  - `eduVPNProvisioning/Config/AppVersion.xcconfig`
  - `Scripts/create_installer.sh`

### Import provisioning profiles

See [CREATING_PROVISIONING_PROFILES.md][] for information on how to create the
provisioning profiles in the Apple Developer Account website.

If the provisioning profiles are available, use the following instructions to
import it into Xcode:

 1. Open _eduVPNProvisioning/eduVPNProvisioning.xcodeproj_ in Xcode
 2. In Xcode, open the Projects and Targets pane
    - In the Project Navigator (keyboard shortcut: Cmd+1), select "EduVPN" at the top left
 3. Setup the app's provisioning profile
    - Select the _eduVPNProvisioning_ target
    - Select the _Signing & Capabilities_ tab, and under that, the _Release_ tab
    - Ensure _Automatically manage signing_ is not checked
    - Under _macOS_, choose a _Provisioning Profile_. You can use _Import Profile..._ to import the downloaded profile (say "eduVPN_dev_id_app.provisionprofile"), or choose an already imported profile
 4. Setup the tunnel extension's provisioning profile
    - Select the _TunnelExtension_ target
    - Select the _Signing & Capabilities_ tab, and under that, the _Release_ tab
    - Ensure _Automatically manage signing_ is not checked
    - Under _macOS_, choose a _Provisioning Profile_. You can use _Import Profile..._ to import the downloaded profile (say "eduVPN_dev_id_tunnelextension.provisionprofile"), or choose an already imported profile.

Xcode keeps the imported provisioning profiles at
`~/Library/MobileDevice/Provisioning Profiles`. In case you want to clear out
all imported profiles and start over, you can quit Xcode, delete everything in
that location, and open Xcode again.

### Create the archive

  - Select the _eduVPNProvisioning_ target for building
      - In the middle of the top of the Xcode window, select _eduVPNProvisioning_ > _My Mac_
  - In the Xcode menu, choose _Product_ > _Clean Build Folder_
  - In the Xcode menu, choose _Product_ > _Archive_ (Ignore the popup "ad" about Xcode Cloud)
  - Once the archive is created, Xcode will open its Organizer window, with the created archive selected

In case you see build errors like "Missing package product", please do "File > Packages > Reset Package Caches", and
then try archiving.

### Create the notarized app bundle

  - Ensure that the created archive is selected in the Organizer window
  - Click on _Distribute App_
     - Select _Developer ID_, click _Next_
     - Select _Upload_, click _Next_
     - Set the _Distribution certificate_ as the _Developer ID Application Certificate_ we created
     - Choose the appropriate provisioning profiles for the app and the tunnel extension. You will see the already imported profiles in the dropdown menu. Click _Next_.
     - Click _Upload_. Wait for Apple to notarize it (it generally takes less than 5 mins, but can take a maximum of 15 mins).
  - Export the notarized app bundle
     - If the "Distribute App" modal window (that you used to upload the app for notarization) is still open, click on _Export_ to export the app. Else, select the archive in the Organizer window (status should be "Ready to Distribute"), and click on _Export Notarized App_ in the right-side inspector pane.
     - Save the app bundle somewhere (say "release/eduVPNProvisioning.app")

### Create the installer package

  - Edit the installer creation script

    ~~~
    vim Scripts/create_eduvpn_installer_macos.sh
    ~~~

  - Ensure that the variables at the top are all correct:
      - APP_VERSION: The app version
      - MIN_MACOS_VERSION: The min macOS version
      - APP_NAME: The app name -- the name used for the dot-app file
      - APP_ID: The app id
      - DEVELOPMENT_TEAM: The development team that controls the app distribution
      - INSTALLER_CERTIFICATE_CN: The Common Name of the Developer ID Installer Certificates installed in the Keychain

  - Run the installer creation script

    `cd` to the directory containing the notarized app file (say "release/")

    ~~
    cd release
    ~~

    &lt;username&gt; should be the Apple ID that controls the developer
    account for this app.

    &lt;password&gt; should be the password for that Apple ID. If 2FA is
    enabled for this Apple ID, you will need to generate an app-specific password
    at [appleid.apple.com](https://appleid.apple.com) (Sign In > App-specific
    Passwords > + > &lt;enter some name&gt;) and specify that password.

    ~~~
    bash path-to-source-code/Scripts/create_installer.sh -u <username> -p <password>
    ~~~

    The notarized installer package will be created in the same directory.

	The script requires a working internet connection to work, and can take
	a few minutes to complete.

## Distributing the Release

The installer package file we created can be distributed to provisioned devices
using the MDM solution used for provisioning.

For distributing through Intune, see [CONFIGURING_INTUNE.md][].
