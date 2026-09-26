<h1 align="center">SteamOS Samba Server</h1>
<p align="center">
  <i>This is a simple script that sets up a Samba server on your SteamOS device, allowing you to easily transfer files to and from your device.</i>
  <br/>
  <br/>
  <br/>
  <br/>
  <a name="download button" href="https://github.com/xanderfrangos/steamdeck-samba-server/releases/download/latest/samba.download"><img src="./docs/download_button.svg"  alt="Download steam-deck-samba-server" width="350px" style="padding-top: 15px;"></a>
  <br/>
  <br/>
  <a href="./LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-0aa8d2?logo=opensourceinitiative&logoColor=fff" alt="License MIT">
  </a>
</p>

This is based on the excellent script by malordin: [steamdeck-samba-server](https://github.com/malordin/steamdeck-samba-server)

## Installation

To run the script, simply insert the following command in your SteamOS terminal:

 
`sh -c "$(curl -fsSL https://raw.githubusercontent.com/xanderfrangos/steamdeck-samba-server/main/script.sh)"`


This will automatically download and run the script.sh file from the GitHub repository, which will install and configure the Samba server on your SteamOS device.

### Choosing a network name

During installation, the script asks what name your SteamOS device should use on your network. This is the name other computers will use to find it. Press Enter to keep the default, `steamdeck`, or type your own.

The name can be up to 15 characters long and can use letters, numbers and hyphens. It can't be only numbers, and it can't start or end with a hyphen. For example, `steam-os` or `SteamMachine` both work.

## SteamOS 3.9 support

SteamOS 3.9 changed a few things that stopped this script from working. They're now fixed:

- **Unlocking the system:** SteamOS 3.9 renamed the tool that makes the system writable so software can be installed. The script now finds the right tool on both old and new versions of SteamOS.
- **Downloading Samba:** SteamOS 3.9 comes with a newer version of pacman (the package installer) that is stricter about signatures. It refused to download anything from Valve's servers and showed `missing required signature` errors. The script now sets pacman up so it can download from Valve again.
- **Mismatched Samba parts:** SteamOS already includes some Samba libraries. The script now installs Samba together with matching versions of them, which avoids `version SAMBA_... not found` errors.
- **Clearer failures:** if something goes wrong, the script now stops and tells you what failed, instead of carrying on and reporting success. It also always locks the system again before it exits, even if you cancel partway through.

> **Note:** SteamOS updates remove software installed this way, so you may need to run the script again after a system update.

## Usage

Once the Samba server is installed, you can connect to it from any device on the same network. Simply open a file explorer window on your computer, and type the following in the address bar:

`\\steamdeck`

If you chose a different network name during installation, use that instead (for example `\\my-deck`). The script shows the exact address to use when it finishes.

You should then be prompted to enter your SteamOS username and password. Once you do so, you'll be able to access the files on your device just like any other shared folder.

## License

This script is licensed under the [MIT License](https://github.com/xanderfrangos/steamdeck-samba-server/blob/main/LICENSE). Feel free to use, modify, and distribute it as you see fit.