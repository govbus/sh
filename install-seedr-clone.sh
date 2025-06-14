#!/bin/bash
# One-click installer for Seedr Clone - A self-hosted torrent web client
# This script automatically installs Docker and deploys the torrent web application
# with all required dependencies.

set -e

# Text formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
WEB_PORT=8080
TORRENT_PORT=6881
DATA_DIR="/opt/seedr-clone"
DEFAULT_USERNAME="admin"
DEFAULT_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)

# Banner
echo -e "${BLUE}"
echo "  _____              _         _____ _                  "
echo " / ____|            | |       / ____| |                 "
echo "| (___   ___  ___  __| |_ __  | |    | | ___  _ __   ___ "
echo " \___ \ / _ \/ _ \/ _\` | '__| | |    | |/ _ \| '_ \ / _ \\"
echo " ____) |  __/  __/ (_| | |    | |____| | (_) | | | |  __/"
echo "|_____/ \___|\___|\__,_|_|     \_____|_|\___/|_| |_|\___|"
echo "                                                         "
echo -e "${NC}"
echo -e "${GREEN}Self-hosted torrent web client installation script${NC}"
echo

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check system requirements
check_system() {
    echo -e "${BLUE}➤ Checking system requirements...${NC}"
    
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Error: This script must be run as root${NC}"
        exit 1
    fi
    
    # Check OS compatibility
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        echo -e "  Detected OS: ${YELLOW}$OS${NC}"
    else
        echo -e "${RED}Error: Unable to detect operating system${NC}"
        exit 1
    fi
    
    # Check minimum system requirements
    MEM_TOTAL=$(free -m | grep Mem | awk '{print $2}')
    DISK_FREE=$(df -m / | tail -n 1 | awk '{print $4}')
    
    echo -e "  Available memory: ${YELLOW}${MEM_TOTAL}MB${NC}"
    echo -e "  Free disk space: ${YELLOW}${DISK_FREE}MB${NC}"
    
    if [ "$MEM_TOTAL" -lt 1024 ]; then
        echo -e "${YELLOW}Warning: Low memory detected. Recommended minimum is 1GB RAM.${NC}"
        echo -e "The application may work with limited performance."
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    if [ "$DISK_FREE" -lt 10240 ]; then
        echo -e "${YELLOW}Warning: Low disk space detected. Recommended minimum is 10GB free space.${NC}"
        echo -e "You may encounter issues when downloading large torrents."
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✓ System requirements check passed${NC}"
    echo
}

# Function to install Docker
install_docker() {
    echo -e "${BLUE}➤ Checking for Docker...${NC}"
    
    if command_exists docker && docker --version > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Docker is already installed${NC}"
    else
        echo -e "  Installing Docker..."
        
        # Install dependencies
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg
        
        # Add Docker GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
        
        # Set up the Docker repository
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        
        # Install Docker
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io
        
        # Start and enable Docker service
        systemctl start docker
        systemctl enable docker
        
        echo -e "${GREEN}✓ Docker installed successfully${NC}"
    fi
    
    # Check Docker Compose
    echo -e "${BLUE}➤ Checking for Docker Compose...${NC}"
    if command_exists docker-compose || command_exists docker compose; then
        echo -e "${GREEN}✓ Docker Compose is already installed${NC}"
    else
        echo -e "  Installing Docker Compose..."
        
        # Install Docker Compose
        curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        
        echo -e "${GREEN}✓ Docker Compose installed successfully${NC}"
    fi
    echo
}

# Function to get configuration from user
get_configuration() {
    echo -e "${BLUE}➤ Configuration...${NC}"
    
    # Ask for web port
    read -p "Web UI port [default: ${WEB_PORT}]: " input_web_port
    WEB_PORT=${input_web_port:-$WEB_PORT}
    
    # Ask for torrent port
    read -p "BitTorrent port [default: ${TORRENT_PORT}]: " input_torrent_port
    TORRENT_PORT=${input_torrent_port:-$TORRENT_PORT}
    
    # Ask for data directory
    read -p "Data directory [default: ${DATA_DIR}]: " input_data_dir
    DATA_DIR=${input_data_dir:-$DATA_DIR}
    
    # Ask for username
    read -p "Admin username [default: ${DEFAULT_USERNAME}]: " input_username
    USERNAME=${input_username:-$DEFAULT_USERNAME}
    
    # Ask for password or use generated one
    read -p "Admin password [default: auto-generated]: " input_password
    PASSWORD=${input_password:-$DEFAULT_PASSWORD}
    
    echo
    echo -e "${GREEN}✓ Configuration complete${NC}"
    echo
}

# Function to create directories and docker-compose file
setup_application() {
    echo -e "${BLUE}➤ Setting up application...${NC}"
    
    # Create required directories
    mkdir -p "${DATA_DIR}"
    mkdir -p "${DATA_DIR}/config"
    mkdir -p "${DATA_DIR}/downloads"
    mkdir -p "${DATA_DIR}/torrents"
    
    # Create docker-compose.yml file
    cat > "${DATA_DIR}/docker-compose.yml" << EOL
version: '3'

services:
  seedr-clone:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: seedr-clone
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - WEBUI_PORT=${WEB_PORT}
      - WEBUI_USERNAME=${USERNAME}
      - WEBUI_PASSWORD=${PASSWORD}
    volumes:
      - ${DATA_DIR}/config:/config
      - ${DATA_DIR}/downloads:/downloads
      - ${DATA_DIR}/torrents:/torrents
    ports:
      - ${WEB_PORT}:${WEB_PORT}
      - ${TORRENT_PORT}:${TORRENT_PORT}
      - ${TORRENT_PORT}:${TORRENT_PORT}/udp
    restart: unless-stopped
EOL

    # Create custom WebUI directory and download VueTorrent
    echo -e "  Downloading modern web UI..."
    mkdir -p "${DATA_DIR}/config/qBittorrent/vuetorrent"
    
    # Download VueTorrent WebUI
    curl -L "https://github.com/WDaan/VueTorrent/releases/latest/download/vuetorrent.zip" -o "${DATA_DIR}/vuetorrent.zip"
    unzip -q "${DATA_DIR}/vuetorrent.zip" -d "${DATA_DIR}/config/qBittorrent/"
    rm "${DATA_DIR}/vuetorrent.zip"
    
    echo -e "${GREEN}✓ Application setup complete${NC}"
    echo
}

# Function to start the application
start_application() {
    echo -e "${BLUE}➤ Starting application...${NC}"
    
    # Navigate to application directory
    cd "${DATA_DIR}"
    
    # Start containers
    docker-compose up -d
    
    # Check if application started successfully
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Application started successfully${NC}"
        
        # Get server IP
        SERVER_IP=$(hostname -I | awk '{print $1}')
        
        echo
        echo -e "${GREEN}=== INSTALLATION COMPLETE ===${NC}"
        echo
        echo -e "Your Seedr Clone is now running at: ${YELLOW}http://${SERVER_IP}:${WEB_PORT}${NC}"
        echo -e "Login credentials:"
        echo -e "  Username: ${YELLOW}${USERNAME}${NC}"
        echo -e "  Password: ${YELLOW}${PASSWORD}${NC}"
        echo
        echo -e "${YELLOW}IMPORTANT:${NC} Please save these credentials in a secure location."
        echo -e "You can access your downloaded files in: ${YELLOW}${DATA_DIR}/downloads${NC}"
        echo
        echo -e "To stop the application: ${YELLOW}cd ${DATA_DIR} && docker-compose down${NC}"
        echo -e "To start the application: ${YELLOW}cd ${DATA_DIR} && docker-compose up -d${NC}"
        echo
    else
        echo -e "${RED}Error: Failed to start the application${NC}"
        echo -e "Please check the logs with: ${YELLOW}cd ${DATA_DIR} && docker-compose logs${NC}"
    fi
}

# Main installation process
main() {
    check_system
    install_docker
    get_configuration
    setup_application
    start_application
}

# Run the main function
main