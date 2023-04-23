Before creating a Developer ID release, we need to create some Certificates,
Identifiers, and Provisioning Profiles in the [Apple Developer Account
website][].

This needs to be done when we create the first release of the app -- not for
every release.

The Provisioning Profiles should be imported into Xcode to create the Developer
ID release.

[Apple Developer Account website]: https://developer.apple.com/account/

## Certificates

We need to create the certificates we will use to sign the executables and
installers that we want to distribute.

If you have already created these certificates (maybe for distributing other
apps), then this step can be skipped.

 1. Developer ID Application Certificate

      - Click on _Certificates_, then on _+_ to add a certificate. Choose _Developer ID Application_.
      - Choose the latest applicable _Profile Type_ (currently _G2 Sub-CA_)
      - Create a Certificate Signing Request on your Mac as specified in the page and upload it
      - _Download_ the created certificate
      - Open "Keychain Access.app", choose the default keychain, and drag the downloaded certificate file to install it in the default keychain
      - In the Keychain Access app window, double-click on the installed certificate to view it
          - You can make a note of the expiry date to identify this certificate later

 2. Developer ID Installer Certificate

      - Click on _Certificates_, then on _+_ to add a certificate. Choose _Developer ID Installer_.
      - Choose the latest applicable _Profile Type_ (currently _G2 Sub-CA_)
      - Create a Certificate Signing Request on your Mac as specified in the page and upload it
      - _Download_ the certificate
      - Open "Keychain Access.app", choose the default keychain, and drag the downloaded certificate file to install it
      - In the Keychain Access app, double-click on the installed certificate to view it
          - You can make a note of the expiry date to identify this certificate later

Developer ID Application Certificates and Developer ID Installer Certificates
are valid for 5 years from when they were created.

The application should be signed when the Developer ID Application
Certificate is valid -- the installed application will continue to run after the
Developer ID Application certificate expires.

The installer will stop working after the Developer ID Installer Certificate
expires.

## Identifiers

We need to create explicit bundle ids for the bundles we need to distribute,
and declare what capabilities they should be allowed to have.

 1. App

      - Click on _Identifiers_, then on _+_ to add an identifier, choose _App IDs_, click on _Continue_
      - Select _App_ type, click on _Continue_
      - Enter the _Bundle ID_ used as `APP_ID` in Developer.xcconfig, say "com.example.app"
      - Ensure _Explicit_ is checked next to _Bundle ID_
      - Enter a _Description_ (you can use spaces instead of special characters)
      - Under _Capabilities_, choose _Network Extensions_ and _System Extension_
      - Click on _Continue_, then _Register_

 2. Tunnel Extension

      - Click on _Identifiers_, then on _+_ to add an identifier, choose _App IDs_, click on _Continue_
      - Select _App_ type, click on _Continue_
      - Enter the _Bundle ID_ as `APP_ID` with a "TunnelExtension" suffix, say "com.example.app.TunnelExtension"
      - Ensure _Explicit_ is checked next to _Bundle ID_
      - Enter a _Description_ (you can use spaces instead of special characters)
      - Under _Capabilities_, choose _Network Extensions_
      - Click on _Continue_, then _Register_

Sometimes, you might get an error saying:

> An App ID with Identifier 'identifier' is not available. Please enter a different string.

This happens if the identifier is already registered. Xcode might have
registered it on our behalf -- in that case, check if the already registered
identifier has the required capabilities. You can edit the capabilities if required.

## Provisioning Profiles

For each bundle id we created, we need to create a provisioning profile that
ties the bundle id to a Developer ID Application Certificate.

 1. App

      - Click on _Profiles_, then on _+_ to add a profile, choose _Developer ID_ under _Distribution_, then click on _Continue_
      - Ensure Profile Type is _Mac_, choose the _App ID_ created earlier (you can type to search), and click on _Continue_
      - Choose the _Developer ID Application_ certificate created earlier (you will have to choose by expiry date), click on _Continue_
      - Enter a _Provisioning Profile Name_, say "eduVPN Developer ID App 01 Jan 2023"
      - Click on _Generate_, then on _Download_. Save the file somewhere (say "eduVPN_Developer_ID_App_01_Jan_2023.provisionprofile").

 2. Tunnel Extension

      - Click on _Profiles_, then on _+_ to add a profile, choose _Developer ID_ under _Distribution_, then click on _Continue_
      - Ensure Profile Type is _Mac_, choose the _Bundle ID_ with a "TunnelExtension" suffix created earlier (you can type to search), and click on _Continue_
      - Choose the _Developer ID Application_ certificate created earlier (you will have to choose by expiry date), click on _Continue_
      - Enter a _Provisioning Profile Name_, say "eduVPN Developer ID Tunnel 01 Jan 2023"
      - Click on _Generate_, then on _Download_. Save the file somewhere (say "eduVPN_Developer_ID_Tunnel_01_Jan_2023.provisionprofile").

These downloaded provisioning profile files should be imported into Xcode
before we create the Developer ID release.

The provisioning profiles are valid for 18 years from the time they are
generated. The installed app will stop working when the provisioning profile
expires.
