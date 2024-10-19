#!/bin/bash

cat <<"EOF"
                                             _____      __            
                                            / ___/___  / /___  ______ 
                                            \__ \/ _ \/ __/ / / / __ \
                                           ___/ /  __/ /_/ /_/ / /_/ /
                                          /____/\___/\__/\__,_/ .___/ 
                                                            /_/      
EOF
# Update the system
echo "Running this script requires root privileges"
echo ""
read -rp "Enter your root password: " password
echo ""
echo "============================ Updating the system ============================"
echo ""
sudo -S apt update
sudo -S apt-get dist-upgrade -y
echo ""
echo "============================ System Update Complete ========================="
echo ""

# Changing the Hostname and FQDN (Fully Qualified Domain Name)
if [ ! -f "script_state.txt" ]; then
    step=1
    echo "=========================== Changing your hostname & Fully Qualified Domain Name ================================"
    echo ""
    echo "Your current hostname is: $(hostname -f)"
    echo ""
    read -rp "Do you want to change the hostname? Enter 'y' to continue: " consent
    if [ "$consent" = "y" ]; then
        read -rp "Enter your hostname (Eg: nutz): " new_hostname
        read -rp "Enter your domain name (Eg: nutz.in): " domain_name
        echo "$new_hostname" | sudo tee /etc/hostname
        echo "Your hostname has been modified successfully."
        echo "Your current hostname is $(cat /etc/hostname)"
        echo ""
        echo "Modifying your hosts file..."
        echo "127.0.1.1 $domain_name $new_hostname" | sudo tee -a /etc/hosts
        echo "Saving script state..."
        echo "step=$step" >"script_state.txt"
        sudo reboot
        echo "=============================== Your hosts file has been changed successfully ====================================="
        echo ""
    else
        echo "Hostname remains unchanged"
    fi
fi

# Webmin & Virtualmin setup
echo "========================================== Virtualmin Setup ========================================="
echo ""
echo "Downloading Virtualmin ..."
wget https://software.virtualmin.com/gpl/scripts/install.sh
echo "Installing Virtualmin ..."
echo "y" | sudo /bin/sh ./install.sh
sudo /usr/share/webmin/changepass.pl /etc/webmin root admin
echo "default password admin"
# echo "Virtualmin setup complete. Go to 'https://$domain_name:10000' to complete the post-installation wizard"
echo ""
echo "========================================== Virutlamin Setup Completed ==============================================="
echo ""

# Node & NPM Setup using NVM
echo "========================================= NVM, Node.js and NPM Setup ==============================================="
read -rp "Do you want to install Node.js and NPM? We will use NVM to set these up (Enter 'y' to proceed): " consent
if [ "$consent" = "y" ]; then
    # NVM Installing and configuration
    echo "Installing NVM ..."
    export NVM_DIR="$HOME/.nvm" && (
        git clone https://github.com/nvm-sh/nvm.git "$NVM_DIR"
        cd "$NVM_DIR"
        git checkout "$(git describe --abbrev=0 --tags --match 'v[0-9]*' "$(git rev-list --tags --max-count=1)")"
    ) && \. "$NVM_DIR/nvm.sh"
    {
        echo ""
        echo "#NVM"
        echo ""
        echo "export NVM_DIR=\"$HOME/.nvm\""
        echo "[ -s \"$NVM_DIR/nvm.sh\" ] && \. \"$NVM_DIR/nvm.sh\""
        echo "[ -s \"$NVM_DIR/bash_completion\" ] && \. \"$NVM_DIR/bash_completion\""
    } >>~/.bashrc
    echo ""

    # Installing Node.js and NPM
    read -rp "Enter the Node.js version to install (Eg: 14.17.0): " node_version
    echo "Installing Node.js v$node_version"
    echo ""
    nvm install "$node_version"
    echo "Successfully installed Node.js v$node_version"
    echo ""
    nvm use "$node_version"
    echo "Current Node.js version is $(node -v)"

    read -rp "Do you want to install PM2? Enter 'y' to proceed: " consent_pm2
    if [ "$consent_pm2" = "y" ]; then
        npm i -g pm2
    fi
    echo ""
    echo "=============================================== NVM, Node.js and NPM Finished =============================================="
    echo ""
else
    echo "Node.js Installation Aborted"
fi

# Installing and configuring Git
echo ""
echo "======================================= Git Installation ============================================"
echo ""
echo "Installing Git ..."
sudo -S apt-get update
sudo -S apt-get install -y git-all
echo "Your current Git version is $(git --version)"
echo ""

echo "Configuring Git ..."
read -rp "Enter your Github Username: " git_username
read -rp "Enter your Github email: " git_email
echo "[user]" >~/.gitconfig
echo " name = $git_username" >>~/.gitconfig
echo "email = $git_email" >>~/.gitconfig

# Generating SSH key and adding it to the Github account
echo "Configuring SSH with Github"
ssh-keygen -t ed25519 -C "$git_email"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
echo "Add the following SSH key to your GitHub account:"
echo ""
cat ~/.ssh/id_ed25519.pub
read -rp "Press Enter key to continue ..."
echo "If everything went right, you should be able to clone any repo from your GitHub account."
echo ""
echo "======================================= Git Installation Finished ============================================="
echo ""

# Installing and configuring Firewall
echo "======================================= Firewall Installation ============================================"
echo ""
read -rp "Do you want to install Firewall? Enter 'y' to continue: " consent_firewall
echo ""
if [ "$consent_firewall" = "y" ]; then
    echo "Installing Firewall..."
    echo ""
    sudo -S apt install ufw -y
    sudo -S ufw default deny incoming
    sudo -S ufw default allow outgoing
    sudo -S ufw enable
    echo "By Default, All incoming connections are denied and All outgoing connections are allowed."
    echo ""
    read -rp "Enter the names of the apps in the list and port numbers you want to allow through the firewall separated by comma: " apps
    echo ""
    IFS=','                    # Setting IFS (input field separator) value as ","
    read -ra arr <<<"$apps"    # Reading the split string into an array
    for val in "${arr[@]}"; do # Iterating through the array elements
        sudo -S ufw allow "$val"
    done
    sudo ufw reload
    echo "Current Firewall Status"
    sudo -S ufw status
    read -rp "Press Enter key to continue ..."
    echo "============================================= Firewall Installation completed =============================================="
else
    echo "Firewall installation aborted..."
fi

# Installing and configuring Jenkins
echo ""
echo "=================================== Jenkins Installation ====================================================="
echo ""
read -rp "Do you want to install Jenkins CI/CD? Enter 'y' to continue: " consent_jenkins
if [ "$consent_jenkins" = "y" ]; then
    echo "Installing JAVA"
    echo ""
    sudo -S apt update
    sudo -S apt install openjdk-17-jre -y
    java -version
    echo "Installing Jenkins..."
    echo ""
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null
    echo deb [ signed-by=/usr/share/keyrings/jenkins-keyring.asc ] \
        https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
        /etc/apt/sources.list.d/jenkins.list sudo -S apt-get update >/dev/null
    sudo -S apt-get install -y jenkins
    echo "Configuring Jenkins..."
    echo ""
    sudo -S systemctl enable jenkins
    sudo -S systemctl start jenkins
    echo "Status of Jenkins Service"
    sudo -S systemctl status jenkins
    read -rp "Enter the port to run Jenkins. Default is port 8080: " port
    if [ -z "$port" ]; then
        port=8080
    fi
    sudo -S ufw allow "$port"
    sudo -S ufw reload
    # YOURPORT=8080
    # PERM="--permanent"
    # SERV="$PERM --service=jenkins"

    # firewall-cmd $PERM --new-service=jenkins
    # firewall-cmd $SERV --set-short="Jenkins ports"
    # firewall-cmd $SERV --set-description="Jenkins port exceptions"
    # firewall-cmd $SERV --add-port=$YOURPORT/tcp
    # firewall-cmd $PERM --add-service=jenkins
    # firewall-cmd --zone=public --add-service=http --permanent
    # firewall-cmd --reload
    echo "==================================== Jenkins Installation Finished ================================="
else
    echo "Jenkins Installation Aborted"
fi

#echo ""
#echo "======================================= Jitsi Meet ===================================="
#echo ""
#read -rp "Do you want to install Jitsi meet? Enter 'y' to continue: " consent
#if [ $consent -eq 'y' ]; then
#echo "Installing Jitsi..."
#else
#echo "Jitsi Installation Aborted..."
#echo ""
#fi

# Cleaning up the system
echo "======================================= Cleaning up the system ===================================="
sudo -S apt update
sudo -S apt-get update
sudo -S apt upgrade -y
sudo -S apt-get upgrade -y
sudo -S apt autoremove -y
sudo -S apt-get autoremove -y

cat <<"EOF"
                             _____      __                 _______       _      __             __
                            / ___/___  / /___  ______     / ____(_)___  (_)____/ /_  ___  ____/ /
                            \__ \/ _ \/ __/ / / / __ \   / /_  / / __ \/ / ___/ __ \/ _ \/ __  / 
                           ___/ /  __/ /_/ /_/ / /_/ /  / __/ / / / / / (__  ) / / /  __/ /_/ /  
                          /____/\___/\__/\__,_/ .___/  /_/   /_/_/ /_/_/____/_/ /_/\___/\__,_/   
                                            /_/                                                 
EOF
