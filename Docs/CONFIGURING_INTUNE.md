# Configuring Intune

The distribute this app through Intune to ensure that the required devices
provisioned through Intune use the VPN tunnel extension packaged in this app.

For doing this, you should have a Microsoft Account that is subscribed to
Intune.

The following steps should be done in the Intune website: [http://endpoint.microsoft.com/][].

Each step involves setting up users / group in _Assignments_. The users /
groups should be the same for all the steps.

## Allow System Extension Installation

This would allow the app to install the system extension without
requiring user approval.

  - Go to _Devices_ > _macOS_ > _Configuration profiles_
  - Click on the _Create profile_ button
  - In the _Profile type_ dropdown menu, select _Templates_
  - Select _Template name_ as _Extensions_
  - Click on the _Create_ button
  - In the _Basics_ tab
      - Type _Name_ (say "eduVPNProvisioning: Allow system extensions") and _Description_
      - Click on _Next_ button
  - In the _Configuration settings_ tab
      - Expand the _System extensions_ section
      - Under _Allowed team identifiers_, specify the team identifier used to distribute the app
      - Under _Allowed system extension types_, specify the same team identifier, and select only _Network extensions_ as allowed
      - Click on _Next_ button
  - In the _Assignments_ tab
      - Assign this profile to the required users / groups
      - Click on _Next_ button
  - In the _Review + Create_ tab
      - Check if the entries are correct
      - Click on the _Create_ button

## Install the App

  - Go to _Apps_ > _macOS apps_
  - Click on the _Add_ button
  - In the _App type_ dropdown menu, select _Line-of-business app_
  - Click on the _Select_ button
  - In the _App information_ tab
      - Click on _Select app package file_, then on _Select a file_
      - Choose the installer package file (.pkg) in your filesystem
      - Click on the _OK_ button
      - In _Publisher_ enter the publisher name
      - In _Included apps_, ensure that the app id of our app is present, and nothing else is present
      - Enter Information URL / Privacy URL / Developer / Owner, if applicable
      - Click on the _Next_ button
  - In the _Assignments_ tab
      - Assign this app to the required users / groups
      - Click on _Next_ button
  - In the _Review + Create_ tab
      - Check if the entries are correct
      - Click on the _Create_ button

## Summary

The idea is that when a device enrolls in Intune, the following things should happen:

  - Intune configures the device to:
      - Allow system extensions to be installed by the app
      - Add a tunnel configuration with information on the intermediate server
        and the profile id
  - Intune installs the app on the device
  - The installation package includes a post-install script that runs the app
    to setup the tunnel, i.e.:
      - to install the tunnel extension
      - to enable on-demand on the tunnel configuration

