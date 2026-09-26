#!/bin/bash


RED="31"
GREEN="32"
BOLDGREEN="\e[1;${GREEN}m"
ITALICRED="\e[3;${RED}m"
ENDCOLOR="\e[0m"



if [ "$1" = "gui" ]; then
  # Script is running with a GUI argument (icon)
  if zenity --question --width=400 --height=100 --text="This script will install Samba server on your system. Did you change the password via passwd?"; then
    # User answered "yes" or "Y" or "y"
    password=$(zenity --password --title="Enter your password")
    echo "$password" | sudo -S echo "Continuing with Samba server installation..."
  else
    # User answered "no" or "N" or "n"
    zenity --error --width=400 --height=100 --text="This script requires your password to work correctly. Please change your password via passwd and try again."
    exit 1
  fi
else
  # Script is running without a GUI argument (console)
  echo "WARNING: This script will install Samba server on your system."
  read -p "Did you change the password via passwd? [Y/N] " password_choice

  case "$password_choice" in
    y|Y ) # User answered "yes" or "Y" or "y"
          read -s -p "Please enter your password: " password
          echo "$password" | sudo -S echo "Continuing with Samba server installation..." ;;
    n|N ) # User answered "no" or "N" or "n"
          echo "This script requires your password to work correctly. Please change your password via passwd and try again."
          exit 1 ;;
    * )   # User provided an invalid choice
          echo "Invalid choice, aborting script." && exit 1 ;;
  esac
fi



# Check if "deck" user's password has been changed
if [ "$(sudo grep '^deck:' /etc/shadow | cut -d':' -f2)" = "*" ] || [ "$(sudo grep '^deck:' /etc/shadow | cut -d':' -f2)" = "!" ]; then
    # Prompt user to change "deck" user's password
    echo "It looks like you haven't changed the password for the 'deck' user yet."
    read -p "Would you like to change it now? (y/n) " choice
    if [ "$choice" = "y" ]; then
        sudo passwd deck
    fi
fi

# Print an error (and show it in a dialog in GUI mode), then exit
fail() {
    echo "ERROR: $1" >&2
    if [ "$GUI_MODE" = "gui" ]; then
        zenity --error --width=400 --height=100 --text="$1"
    fi
    exit 1
}
GUI_MODE="$1"

# SteamOS 3.9 renamed steamos-readonly to holo-readonly; older releases only have steamos-readonly
READONLY_TOOL=$(command -v holo-readonly || command -v steamos-readonly)
if [ -z "$READONLY_TOOL" ]; then
    fail "Could not find holo-readonly or steamos-readonly. Is this SteamOS?"
fi

# Re-enable the read-only filesystem; runs on every exit (success, error, abort or Ctrl+C) once it's been disabled
relock() {
    if [ "$READONLY_DISABLED" = "1" ]; then
        echo "Re-enabling read-only filesystem..."
        sudo "$READONLY_TOOL" enable && echo "Filesystem now read-only"
        READONLY_DISABLED=0
    fi
}
trap relock EXIT

# Disable read-only filesystem
echo "Disabling read-only filesystem..."
sudo "$READONLY_TOOL" disable || fail "Failed to disable the read-only filesystem."
READONLY_DISABLED=1

# Edit pacman.conf file
echo "Editing pacman.conf file..."
sudo sed -i '/^SigLevel[[:space:]]*=[[:space:]]*Required DatabaseOptional/s/^/#/' /etc/pacman.conf
sudo sed -i '/^#SigLevel[[:space:]]*=[[:space:]]*Required DatabaseOptional/a\SigLevel = TrustAll' /etc/pacman.conf

# Initialize pacman keys
echo "Initializing pacman keys..."
sudo pacman-key --init

# Populate pacman keys
echo "Populating pacman keys..."
# No argument loads every keyring on the system: archlinux plus holo, which signs Valve's SteamOS packages
sudo pacman-key --populate

# Install Samba
echo "Installing samba..."
# SteamOS already ships older smbclient/libwbclient/ldb; samba doesn't pin libwbclient or ldb to its own version,
# so install them together to avoid "version SAMBA_x.y.z not found" errors from mismatched libraries
sudo pacman -Sy --noconfirm --needed samba smbclient libwbclient ldb || fail "Failed to install samba. See the terminal output above for details."

# Ask for the network name other devices will see (\\name); NetBIOS names are limited to 15 characters
DEFAULT_NETBIOS_NAME="steamdeck"
while true; do
    if [ "$GUI_MODE" = "gui" ]; then
        # Cancelling the dialog keeps the default name
        netbios_name=$(zenity --entry --width=400 --title="Network name" \
            --text="Enter the name your Steam Deck will appear as on the network:" \
            --entry-text="$DEFAULT_NETBIOS_NAME") || netbios_name="$DEFAULT_NETBIOS_NAME"
    else
        read -p "Enter the network name for your Steam Deck, or press ENTER to use '$DEFAULT_NETBIOS_NAME': " netbios_name
    fi
    netbios_name="${netbios_name:-$DEFAULT_NETBIOS_NAME}"

    if [[ "$netbios_name" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,13}[A-Za-z0-9])?$ && ! "$netbios_name" =~ ^[0-9]+$ ]]; then
        break
    fi
    invalid_name_message="'$netbios_name' is not a valid network name. Use up to 15 letters, numbers or hyphens (not only numbers, and not starting or ending with a hyphen)."
    if [ "$GUI_MODE" = "gui" ]; then
        zenity --error --width=400 --height=100 --text="$invalid_name_message"
    else
        echo "$invalid_name_message"
    fi
done
echo "Network name: $netbios_name"

# Initialize Samba configuration after installed
echo "Initializing new smb.conf file..."
sudo tee /etc/samba/smb.conf > /dev/null <<EOF
[global]
netbios name = $netbios_name
EOF

# Function to add a new share to smb.conf
add_smb_share() {
    echo "Adding share for $1..."
    sudo tee -a /etc/samba/smb.conf > /dev/null <<EOF
[$2]
comment = $2 directory
path = $1
browseable = yes
read only = no
create mask = 0777
directory mask = 0777
force user = deck
force group = deck
EOF
}

# Handle multiple directory inputs
while true; do
    echo "Enter the path of the directory you want to share, or press ENTER to share the entire /home directory:"
    read -p "Path: " custom_path
    # default to /home/
    if [[ -z "$custom_path" ]]; then
        custom_path="/home/"
        share_name="home"
        add_smb_share "$custom_path" "$share_name"
        echo "No path entered. Defaulting to share the entire /home directory."
    elif [[ -d "$custom_path" ]]; then
        share_name=$(basename "$custom_path")
        # create new share
        add_smb_share "$custom_path" "$share_name"
        echo "Directory added: $custom_path"
    else
        echo "The path '$custom_path' does not exist or is not a directory. Please check the path and try again."
    fi

    read -p "Would you like to add another directory? (Y/n): " add_more
    if [[ $add_more =~ ^[Nn] ]]; then
        break
    fi
done

# Confirm sharing setup
while true; do
    read -p "Are you sure you want to proceed with sharing directories? (y/n): " confirmation
    case "$confirmation" in
        [Yy] ) 
            echo "Proceeding with sharing setup..."
            break ;;
        [Nn] ) 
            echo "Setup aborted by user."
            exit 1 ;;
        * ) 
            echo "Invalid input. Please enter 'Y' for Yes or 'N' for No." ;;
    esac
done



echo "Adding 'deck' user to samba user database..."
if [ "$1" = "gui" ]; then
    password=$(zenity --password --title "Set Samba Password" --width=400)
    (echo "$password"; echo "$password") | sudo smbpasswd -s -a deck
else
    sudo smbpasswd -a deck
fi

# Enable and start smb service, plus nmb, which announces the network name so \\name works
# even when it differs from the Deck's hostname
echo "Enabling and starting smb and nmb services..."
sudo systemctl enable smb.service nmb.service
sudo systemctl start smb.service nmb.service

# Open the firewall for Samba, but only if firewalld is installed and running
if command -v firewall-cmd > /dev/null && sudo firewall-cmd --state > /dev/null 2>&1; then
    echo "Allowing samba through the firewall..."
    sudo firewall-cmd --permanent --zone=public --add-service=samba
    sudo firewall-cmd --reload
fi


# Restart smb and nmb services
echo "Restarting smb and nmb services..."
sudo systemctl restart smb.service nmb.service

# re-enable the readonly filesystem
relock

# Final confirmation
# Four backslashes because both zenity --text and echo -e turn \\ into \, leaving \\name
network_path='\\\\'"$netbios_name"
if [ "$1" = "gui" ]; then
    zenity --info --width=400 --height=100 --text="Samba server set up successfully! You can now access the shared directories on your Steam Deck from any device on your local network at $network_path"
else
    echo -e "${BOLDGREEN}Samba server set up successfully!${ENDCOLOR} You can now access the shared directories on your Steam Deck from any device on your local network at $network_path"
    read -p "Press Enter to continue..."
fi
