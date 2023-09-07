#! /bin/sh

cat <<"EOF"

                                             _____      __            
                                            / ___/___  / /___  ______ 
                                            \__ \/ _ \/ __/ / / / __ \
                                           ___/ /  __/ /_/ /_/ / /_/ /
                                          /____/\___/\__/\__,_/ .___/ 
                                                            /_/      

EOF

#Update the system
echo "Running this script requires root previliges"
echo ""
read -sp "Enter your root password: " password
echo ""
echo "Updating the system"
echo ""
sudo -S apt update
sudo -S apt-get dist-upgrade -y
echo ""

# Changing the Hostname and FQDN (Fully Qualified Domain Name)
echo "Changing your hostname & Fully Qualified Domain Name"
echo ""
echo "Your current hostname is: $(hostname -f)"
echo ""
read -s "Do you want to change the hostname? Enter 'y' to continue:" consent
if [$consent -eq "y"]; then
    read -s "Enter your hostname (Eg: nutz)" hostname
    read -s "Enter your domain name (Eg: nutz.in)" domain_name
    sudo -S echo $hostname >/etc/hostname
    echo "Your hostname has been modified successfully."
    echo "Your current hostname is $(cat /etc/hostname)"
    echo ""
    echo "Modyfying your hosts file..."
    sudo -S echo "127.0.1.1	$domain_name $hostname" >>/etc/hosts
    echo "Your hosts file has been changed successfully"
    echo ""
else
    echo "Hostname remains unchanged"
fi

#Webmin & Virtualmin setup
echo "Virtualmin Setup"
echo ""
echo "Downloading Virtualmin ..."
wget https://software.virtualmin.com/gpl/scripts/install.sh
echo "Installing Virtualmin ..."
echo "y $(sudo /bin/sh ./install.sh)"
echo "Virtualmin setup complete. Go to 'https://$domain_name:10000' to complete the post installation wizard"
echo ""

#Node & NPM Setup using NVM
read -s "Do you want to install Node.js and NPM. We will use NVM to set these up" consent
if [$consent -eq "y"]; then

    # NVM Installing and configuration
    echo "Installing NVM ..."
    export NVM_DIR="$HOME/.nvm" && (
        git clone https://github.com/nvm-sh/nvm.git "$NVM_DIR"
        cd "$NVM_DIR"
        git checkout $(git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1))
    ) && \. "$NVM_DIR/nvm.sh"

    echo export NVM_DIR="$HOME/.nvm" >>~/.bashrc
    echo [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" >>~/.bashrc                   # This loads nvm
    echo [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" >>~/.bashrc # This loads nvm bash_completion
    echo ""

    #Installing Node.js and NPM
    read -s "Enter the Node.js version to install: (Eg: 14.17.0)" node_version
    echo "Installing Node.js v$node_version"
    echo ""
    nvm install $node_version
    echo "Successfully installed Node.js v$node_version"
    echo ""
    nvm use $node_version
    echo "Current Node.js verison is $(node -v)"

    read -s "Do you want to install PM2? Enter 'y' to proceed" $consent
    if [$consent -eq "y"]; then
        npm i -g pm2
    fi
else
    echo "Node.js Installation Aborted"
fi

#Installing and configuring git
echo "Installing Git ..."
sudo -S apt-get update
sudo -S apt-get install git-all
echo "Your current Git version is $(git --version)"
echo ""

echo "Configuring Git ..."
read -s "Enter your Github Username" git_username
read -s "Enter your Github email" git_email
ehco "[user]" >~/.gitconfig
echo " name = $git_username" >>~/.gitconfig
echo "email = $git_email" >>~/.gitconfig

#Generating SSH key and adding it to the github account
echo "Configuring SSH with Github"
ssh-keygen -t ed25519 -C $git_email
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
echo "Add the following SSH key to your github account"
echo ""
cat ~/.ssh/id_ed25519.pub
read
echo "If everything went right, you should be able to clone any repo from your github account."

#Installing and configuring Firewall
read -s "Do you want to install Firewall? Enter 'y' to continue" consent
echo ""
if [$consent -eq "y"]; then
    echo "Installing Firewall..."
    echo ""
    sudo -S apt install ufw
    sudo -S ufw default deny incoming
    sudo -S ufw default allow outgoing
    echo "By Default, All incoming connection are denied and All outgoing connections are allowed."
    echo ""
    read -s "Enter the names of the apps in the below list and port numbers you want to allow through firewall seperated by spaces." apps
    echo ""
    IFS=' ' # Setting IFS (input field separator) value as " "
    read -ra arr <<< "$apps" # Reading the split string into array
    for val in "${arr[@]}"; do # Iterating through the array elements
      sudo -S ufw allow "$val"
    done
    echo "Current Firewall Status"
    sudo -S ufw status
    read "Press any key to continue ..."
    echo "Firewall Installation completed..."
else
    echo "Firewall installation aborted..."
fi

#Installing and configuring Jenkins
read -s "Do you want to install Jenkins CI/CD? Enter y to continue" consent
if [$consent -eq "y"]; then
    echo "Installing Jenkins..."
    echo ""
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \ /usr/share/keyrings/jenkins-keyring.asc >/dev/null
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \ https://pkg.jenkins.io/debian-stable binary/ | sudo tee \ /etc/apt/sources.list.d/jenkins.list >/dev/null
    sudo -S apt-get update
    sudo -S apt-get install jenkins
    echo "Installing JAVA"
    echo ""
    sudo -S apt update
    sudo -S apt install openjdk-17-jre
    java -version
    echo "Configuring Jenkins..."
    echo ""
    sudo -S systemctl enable jenkins
    sudo -S systemctl start jenkins
    echo "Status of Jenkins Service"
    sudo -S systemctl status jenkins
    read -s "Enter the port to run Jenkins. Default is port 8080: " port
    if [$port -eq ""]; then
        port=8080
    fi
    YOURPORT=$port
    PERM="--permanent"
    SERV="$PERM --service=jenkins"

    firewall-cmd $PERM --new-service=jenkins
    firewall-cmd $SERV --set-short="Jenkins ports"
    firewall-cmd $SERV --set-description="Jenkins port exceptions"
    firewall-cmd $SERV --add-port=$YOURPORT/tcp
    firewall-cmd $PERM --add-service=jenkins
    firewall-cmd --zone=public --add-service=http --permanent
    firewall-cmd --reload
    echo "Jenkins Installation Finished"
else
    echo "Jenkins Installation Aborted"
fi

#Cleaning up the system
echo "Cleaning up the system..."
sudo -S apt update
sudo -S apt-get update
sudo -S apt upgrade
sudo -S apt-get upgrade
sudo -S apt autoremove
sudo -S apt-get autoremove

cat <<"EOF"


                             _____      __                 _______       _      __             __
                            / ___/___  / /___  ______     / ____(_)___  (_)____/ /_  ___  ____/ /
                            \__ \/ _ \/ __/ / / / __ \   / /_  / / __ \/ / ___/ __ \/ _ \/ __  / 
                           ___/ /  __/ /_/ /_/ / /_/ /  / __/ / / / / / (__  ) / / /  __/ /_/ /  
                          /____/\___/\__/\__,_/ .___/  /_/   /_/_/ /_/_/____/_/ /_/\___/\__,_/   
                                            /_/                                                 


EOF
