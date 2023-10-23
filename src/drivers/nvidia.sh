
RED='\033[0;31m'
RESET='\033[0m'

# This function sets up the nvidia hook by copying the nvidia.hook file to /etc/pacman.d/hooks/
function hook() {
    echo "|- Configuration du hook Nvidia."
    local hook_folder="/etc/pacman.d/hooks/"
    local hook_file="nvidia.hook"
    local hook_src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/data/nvidia.hook"

    sudo mkdir -p "${hook_folder}"
    sudo cp "${hook_src}" "${hook_folder}${hook_file}"
}

# This function updates the mkinitcpio configuration file to include the necessary NVIDIA modules.
function mkinitcpio() {
    echo "|- Configuration de mkinitcpio."

    local mkinitcpio_src="/etc/mkinitcpio.conf"

    sudo sed -i '/MODULES=/ s/)/ nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "${mkinitcpio_src}"
}

# This function detects the bootloader used by the system and adds the "nvidia-drm.modeset=1" option to the boot configuration.
# If the bootloader is "grub", it updates the "/etc/default/grub" file and runs "grub-mkconfig" to update the grub configuration.
# If the bootloader is "systemd-boot", it updates all "*.conf" files in "/boot/loader/entries/" directory with the "nvidia-drm.modeset=1" option.
function bootloaders() {
    echo "|- Détection du bootloader."

    if [[ -d "/boot/loader/entries" ]]; then
        local boot_loader="systemd-boot"
    else
        local boot_loader="grub"
    fi

    if [[ "${boot_loader}" == "grub" ]]; then
        local boot_loader_src="/etc/default/grub"

        if grep -q "GRUB_CMDLINE_LINUX_DEFAULT" "${boot_loader_src}"; then
            if ! grep -q "nvidia-drm.modeset=1" "${boot_loader_src}"; then
                echo "   |- Ajout de nvidia-drm.modeset=1 dans les options de boot."
                sudo sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/ s/\"$/ nvidia-drm.modeset=1\"/' "${boot_loader_src}"
            fi
        fi
        echo "|- Mise à jour de grub."
        sudo grub-mkconfig -o /boot/grub/grub.cfg >> /dev/null 2>&1
    else
        local boot_loader_src="/boot/loader/entries/*.conf"

        echo "|- Ajout de nvidia-drm.modeset=1 dans les options de boot."
        sudo sed -i '/^options root/ s/$/ nvidia-drm.modeset=1/' ${boot_loader_src}
    fi
}

# Function to install NVIDIA drivers and related packages
function nvidia_drivers() {
    echo "|- Installation des pilotes Nvidia."

    bootloaders
    mkinitcpio
    hook

    # Initialize an empty choice variable
    local choice=""

    # Use a while loop to keep prompting the user until a valid choice is made
    while [[ "$choice" != "nvidia" && "$choice" != "nvidia-all" ]]; do
        echo "Veuillez choisir entre 'nvidia' ${RED}Recommandé${RESET} ou 'nvidia-all' ${RED}Demande de savoir le maintenir !${RESET} :"
        read -r choice

        case $choice in
            "nvidia")
                echo -e "|- Installation des paquets Nvidia. ${RED}(très long)${RESET}"
                yay -S --needed --noconfirm nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings vulkan-icd-loader lib32-vulkan-icd-loader cuda >> /dev/null 2>&1
                ;;
            "nvidia-all")
                echo -e "|- Installation de nvidia-all. ${RED}(très long)${RESET}"
                git clone https://github.com/Frogging-Family/nvidia-all.git >> /dev/null 2>&1
                cd nvidia-all  || exit
                makepkg -si
                cd .. || exit
                rm -rf nvidia-all >> /dev/null 2>&1
                echo -e "|- Installation de CUDA. ${RED}(très long)${RESET}"
                yay -S --needed --noconfirm cuda
                ;;
            *)
                echo "Option invalide. Veuillez choisir 'nvidia' ou 'nvidia-all'."
                ;;
        esac
    done

    echo "--------------------------------------------------"
}
