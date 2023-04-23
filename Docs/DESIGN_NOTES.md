# Design Notes

Here are some notes about how the app is designed / architected. The app is
currently designed with Intune as the MDM.

## Tunnel Extension

The tunnel extension is a system extension, so that this can be distributed
outside of the Mac App Store. Intune cannot install apps from the Mac App
Store, but can install apps from a .pkg file.

These are the pre-requisites for the tunnel to work:

  - The tunnel's protocol provider configuration should contain:
      - the intermediate server
      - the profile id

    These values should be configured in Intune.

  - The device should have the Intune device certificate installed, from which
    the tunnel extension can figure out the device id.

    The Company Portal app (from Microsoft) shall install the device certificate.

If the pre-requisites are met, the tunnel does the following:

  - The tunnel contacts the intermediate server with the profile id and the
    device id, to get the wg-quick config file. It can then user WireGuardKit
    to start the tunnel.

  - The tunnel saves this wg-quick config to the System keychain, and stores a
    reference to that on disk, so that it can be used the next time the tunnel
    is turned on - it need not contact the server every time.

## App

_In progress_

## Installer

_In progress_

