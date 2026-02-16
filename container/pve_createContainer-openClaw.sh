#!/usr/bin/env bash
set -e
source "$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/function.sh"

hostname=$(basename "${BASH_SOURCE[0]}" .sh)
hostname="${hostname#pve_createContainer-}"
CONTAINER_ID=$(pvesh get /cluster/nextid)
timezone='host'
IP_Config="dhcp" #ip addess or dhcp
hwaddr=""                      # Optional MAC address (leave empty for random) - format: 02:xx:xx:xx:xx:xx (02 for locally administered)
GATEWAY=""                     # Gateway IP (leave empty for DHCP)
DISK_SIZE="1"                  # Disk size in GB
memory=4096                    # MB
swap=2048                      # MB
cores=2                        # CPU cores
storage="ssd1"                 # <storage ID>   (default=local)
vztmpl="${storage}_directory" #storage template
ostype="debian"               # OS type
ostemplate="13"                # OS version
ostemplate="${vztmpl}:vztmpl/$ostype-${ostemplate}-standard_${ostemplate}.1-2_amd64.tar.zst"
APT_CACHER="192.168.50.78:3142" # apt-cacher-ng host[:port] (empty to disable). Example: 10.0.0.2:3142
unprivileged=1
features="keyctl=0,nesting=0" #--start 1 --onboot 1

Installing_dependencies() {
    print_info "Installing_dependencies..."
    pct exec "$CONTAINER_ID" -- apt -y install curl
    print_info "...Installed_dependencies"
}

install_app() {
    print_info "install_app ..."
    pct exec "$CONTAINER_ID" -- curl -fsSL https://openclaw.ai/install.sh | bash
    print_info "...installed_app"
}

create_service() {
    print_info "create_service..."

    pct exec "$CONTAINER_ID" -- sh -c 'cat <<EOF > /etc/systemd/system/coroSync.service
[Unit]
Description=coroSync Quorum Device
Documentation=https://github.com/corosync/corosync
After=network.target

[Service]
#User=root
#Type=simple
Type=forking
WorkingDirectory=/root
ExecStart=/root/coroSync.sh -R start
ExecStop=/root/coroSync.sh stop
PIDFile=/var/run/coroSync.pid
Restart=on-failure
#Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
'
    pct exec "$CONTAINER_ID" -- systemctl enable -q --now coroSync.service
    print_info "service created and enabled."
}

main() {
    bashStart "0.0.1"
    validate_input
    time create_container
    time send_start
    time wait_container
    enable_console_autologin
    set_root_password
    time wait_IP_Config
    time wait_IP_internet
    time upDateGrading
    time Installing_dependencies
    time install_app
    #create_service
    time reBoot
    show_summary
}
time main