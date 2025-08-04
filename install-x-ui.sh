#!/bin/bash

# Smart X-UI Multi-Instance Management Script
# Complete solution for installing, managing, and uninstalling X-UI instances
# Supports custom .tar.gz files and GitHub releases with version selection

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
magenta='\033[0;35m'
cyan='\033[0;36m'
plain='\033[0m'

function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}

function LOGW() {
    echo -e "${blue}[WAR] $* ${plain}"
}

# Check root
[[ $EUID -ne 0 ]] && LOGE "ERROR: You must be root to run this script!" && exit 1

# Function to configure random security settings
# Generate random string function (from original 3x-ui)
gen_random_string() {
    local length="$1"
    local random_string=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w "$length" | head -n 1)
    echo "$random_string"
}

function configure_random_security() {
    local instance_name=$1
    local binary_path="/usr/local/${instance_name}/x-ui"
    
    # IP detection services (fallback approach)
    local show_ip_service_lists=("https://api.ipify.org" "https://4.ident.me")
    
    # Detect server IP address
    local server_ip
    # Try local methods first (no external dependencies)
    server_ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' | head -1)
    if [ -z "$server_ip" ]; then
        server_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    if [ -z "$server_ip" ]; then
        server_ip=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1 | head -1)
    fi
    # Fallback to external services if local detection fails
    if [ -z "$server_ip" ]; then
        for ip_service_addr in "${show_ip_service_lists[@]}"; do
            server_ip=$(curl -s --max-time 3 ${ip_service_addr} 2>/dev/null)
            if [ -n "${server_ip}" ]; then
                break
            fi
        done
    fi
    # Final fallback
    if [ -z "$server_ip" ]; then
        server_ip="YOUR_SERVER_IP"
    fi
    
    echo -e "${blue}╔══════════════════════════════════════════════════════════════════════════════╗${plain}"
    echo -e "${blue}║                          Security Configuration                             ║${plain}"
    echo -e "${blue}╚══════════════════════════════════════════════════════════════════════════════╝${plain}"
    echo
    
    # Check if this is a fresh installation by checking default credentials
    local existing_hasDefaultCredential
    local existing_webBasePath
    local existing_port
    
    # Wait a moment for service to fully start
    sleep 1
    
    if [ "$instance_name" != "x-ui" ]; then
        # For numbered instances, set environment variable
        existing_hasDefaultCredential=$(XUI_DB_FOLDER="/etc/${instance_name}" "$binary_path" setting -show true 2>/dev/null | grep -Eo 'hasDefaultCredential: .+' | awk '{print $2}')
        existing_webBasePath=$(XUI_DB_FOLDER="/etc/${instance_name}" "$binary_path" setting -show true 2>/dev/null | grep -Eo 'webBasePath: .+' | awk '{print $2}')
        existing_port=$(XUI_DB_FOLDER="/etc/${instance_name}" "$binary_path" setting -show true 2>/dev/null | grep -Eo 'port: .+' | awk '{print $2}')
    else
        # For base instance
        existing_hasDefaultCredential=$("$binary_path" setting -show true 2>/dev/null | grep -Eo 'hasDefaultCredential: .+' | awk '{print $2}')
        existing_webBasePath=$("$binary_path" setting -show true 2>/dev/null | grep -Eo 'webBasePath: .+' | awk '{print $2}')
        existing_port=$("$binary_path" setting -show true 2>/dev/null | grep -Eo 'port: .+' | awk '{print $2}')
    fi
    
    echo -e "${yellow}Configuring random security settings...${plain}"
    
    # Check if this is a fresh installation (database doesn't exist or is empty)
    local db_path
    if [ "$instance_name" != "x-ui" ]; then
        db_path="/etc/${instance_name}/x-ui.db"
    else
        db_path="/etc/x-ui/x-ui.db"
    fi
    
    local is_fresh_install=false
    if [ ! -f "$db_path" ] || [ ! -s "$db_path" ]; then
        is_fresh_install=true
    fi
    
    # Force randomization for fresh installations or when webBasePath is too short
    if [[ ${#existing_webBasePath} -lt 4 ]] || [[ "$is_fresh_install" == "true" ]]; then
        if [[ "$existing_hasDefaultCredential" == "true" ]] || [[ "$is_fresh_install" == "true" ]] || [[ ${#existing_webBasePath} -lt 4 ]]; then
            local config_webBasePath=$(gen_random_string 18)
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)
            local config_port=$(shuf -i 1024-62000 -n 1)
            
            if [[ "$is_fresh_install" == "true" ]]; then
                echo -e "  ${yellow}Fresh installation detected. Generating random credentials...${plain}"
            else
                echo -e "  ${yellow}WebBasePath is missing or too short. Generating random credentials...${plain}"
            fi
            
            # Apply settings using x-ui setting command
            if [ "$instance_name" != "x-ui" ]; then
                XUI_DB_FOLDER="/etc/${instance_name}" "$binary_path" setting -username "${config_username}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
            else
                "$binary_path" setting -username "${config_username}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
            fi
            
            # Wait for database changes to be committed
    sleep 1
            echo -e "    ${green}✓${plain} Random credentials configured successfully"
            
        else
            # Fallback case - should rarely happen now
            local config_webBasePath=$(gen_random_string 18)
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)
            local config_port=$(shuf -i 1024-62000 -n 1)
            
            echo -e "  ${yellow}Applying security defaults with random credentials...${plain}"
            
            if [ "$instance_name" != "x-ui" ]; then
                XUI_DB_FOLDER="/etc/${instance_name}" "$binary_path" setting -username "${config_username}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
            else
                "$binary_path" setting -username "${config_username}" -password "${config_password}" -port "${config_port}" -webBasePath "${config_webBasePath}"
            fi
        fi
    else
        if [[ "$existing_hasDefaultCredential" == "true" ]]; then
            local config_username=$(gen_random_string 10)
            local config_password=$(gen_random_string 10)
            
            echo -e "  ${yellow}Default credentials detected. Security update required...${plain}"
            
            if [ "$instance_name" != "x-ui" ]; then
                XUI_DB_FOLDER="/etc/${instance_name}" "$binary_path" setting -username "${config_username}" -password "${config_password}"
            else
                "$binary_path" setting -username "${config_username}" -password "${config_password}"
            fi
            
            # Wait for database changes to be committed
            sleep 1
            config_webBasePath="$existing_webBasePath"
            config_port="$existing_port"
            echo -e "    ${green}✓${plain} Random credentials updated successfully"
        else
            echo -e "    ${green}✓${plain} Username, Password, and WebBasePath are properly set. Skipping..."
            return 0
        fi
    fi
    
    # Run migration to ensure database is properly set up
    if [ "$instance_name" != "x-ui" ]; then
        XUI_DB_FOLDER="/etc/${instance_name}" "$binary_path" migrate
    else
        "$binary_path" migrate
    fi
    
    # Wait for migration to complete
    sleep 1
    
    # Verify settings were applied correctly
    echo -e "${blue}Verifying configuration...${plain}"
    echo
    echo -e "${green}╔══════════════════════════════════════════════════════════════════════════════╗${plain}"
    echo -e "${green}║                        IMPORTANT SECURITY INFORMATION                       ║${plain}"
    echo -e "${green}╚══════════════════════════════════════════════════════════════════════════════╝${plain}"
    echo -e "${yellow}Please save these credentials:${plain}"
    echo
    echo -e "  ${cyan}Username:${plain}  ${cyan}$config_username${plain}"
    echo -e "  ${cyan}Password:${plain}  ${cyan}$config_password${plain}"
    echo -e "  ${cyan}Port:${plain}      ${cyan}$config_port${plain}"
    echo -e "  ${cyan}WebBasePath:${plain} ${cyan}$config_webBasePath${plain}"
    echo -e "  ${cyan}Access URL:${plain} http://${cyan}$server_ip${plain}:${cyan}$config_port${plain}/${cyan}$config_webBasePath${plain}"
    echo
    echo -e "${red}⚠️  SECURITY WARNING:${plain}"
    echo -e "  • Save these credentials immediately - they cannot be recovered!"
    echo -e "  • Change the default settings if you prefer custom values"
    echo -e "  • Use ${yellow}$instance_name${plain} command to manage this instance"
    echo
}

# Function to check service status
function check_service() {
    local service_name=$1
    local display_name=$2
    
    echo -e "${yellow}Checking ${display_name}...${plain}"
    
    if systemctl is-active --quiet $service_name; then
        echo -e "${green}✓ ${display_name} is running${plain}"
        echo -e "  Status: $(systemctl is-active $service_name)"
        echo -e "  Enabled: $(systemctl is-enabled $service_name 2>/dev/null || echo 'unknown')"
    else
        echo -e "${red}✗ ${display_name} is not running${plain}"
        echo -e "  Status: $(systemctl is-active $service_name)"
        echo -e "  Enabled: $(systemctl is-enabled $service_name 2>/dev/null || echo 'unknown')"
    fi
    
    # Check if service file exists
    if [ -f "/etc/systemd/system/$service_name.service" ]; then
        echo -e "  Service file: ${green}exists${plain}"
    else
        echo -e "  Service file: ${red}missing${plain}"
    fi
    
    echo
}

# Function to check installation
function check_installation() {
    local install_path=$1
    local display_name=$2
    local command_path=$3
    local db_path=$4
    
    echo -e "${yellow}Checking ${display_name} installation...${plain}"
    
    if [ -d "$install_path" ]; then
        echo -e "  Installation directory: ${green}exists${plain} ($install_path)"
    else
        echo -e "  Installation directory: ${red}missing${plain} ($install_path)"
    fi
    
    if [ -f "$command_path" ]; then
        echo -e "  Management command: ${green}exists${plain} ($command_path)"
    else
        echo -e "  Management command: ${red}missing${plain} ($command_path)"
    fi
    
    if [ -n "$db_path" ]; then
        if [ -d "$db_path" ]; then
            echo -e "  Database directory: ${green}exists${plain} ($db_path)"
            if [ -f "$db_path/x-ui.db" ]; then
                echo -e "  Database file: ${green}exists${plain} ($db_path/x-ui.db)"
            else
                echo -e "  Database file: ${yellow}not initialized${plain} ($db_path/x-ui.db)"
            fi
        else
            echo -e "  Database directory: ${red}missing${plain} ($db_path)"
        fi
    fi
    
    echo
}



# Function to show summary
function show_summary() {
    local instances=("$@")
    local running_count=0
    local total_count=${#instances[@]}
    
    for instance in "${instances[@]}"; do
        if systemctl is-active --quiet "$instance"; then
            running_count=$((running_count + 1))
        fi
    done
    
    echo -e "${blue}Summary:${plain}"
    echo -e "  Total instances: ${yellow}$total_count${plain}"
    echo -e "  Running instances: ${green}$running_count${plain}"
    echo -e "  Stopped instances: ${red}$((total_count - running_count))${plain}"
    echo
}

# Function to show management commands
function show_management_commands() {
    local instances=("$@")
    
    if [ ${#instances[@]} -eq 0 ]; then
        echo -e "${yellow}No X-UI instances detected${plain}"
        echo
        return
    fi
    
    echo -e "${blue}Management Commands:${plain}"
    for instance in "${instances[@]}"; do
        if [ "$instance" = "x-ui" ]; then
            echo -e "  X-UI (original): ${green}$instance${plain}"
        else
            local num=${instance#x-ui}
            echo -e "  X-UI${num} (instance ${num}): ${green}$instance${plain}"
        fi
    done
    echo
    
    
}

# Function to uninstall instance
function uninstall_instance() {
    local instance_name="$1"
    
    LOGI "Uninstalling ${instance_name}..."
    
    # Stop and disable service
    LOGI "Stopping ${instance_name} service..."
    systemctl stop "${instance_name}" 2>/dev/null
    systemctl disable "${instance_name}" 2>/dev/null
    
    # Remove service file
    if [ -f "/etc/systemd/system/${instance_name}.service" ]; then
        LOGI "Removing service file..."
        rm -f "/etc/systemd/system/${instance_name}.service"
    fi
    
    # Remove installation directory
    if [ -d "/usr/local/${instance_name}" ]; then
        LOGI "Removing installation directory..."
        rm -rf "/usr/local/${instance_name}"
    fi
    
    # Remove management command
    if [ -f "/usr/bin/${instance_name}" ]; then
        LOGI "Removing management command..."
        rm -f "/usr/bin/${instance_name}"
    fi
    
    # Remove database directory (ask for confirmation)
    local db_path="/etc/${instance_name}"
    if [ "$instance_name" = "x-ui" ]; then
        db_path="/etc/x-ui"
    fi
    
    if [ -d "$db_path" ]; then
        echo
        LOGW "Database directory found: $db_path"
        read -p "Do you want to remove the database and all configurations? [y/N]: " remove_db
        if [[ $remove_db =~ ^[Yy]$ ]]; then
            LOGI "Removing database directory..."
            rm -rf "$db_path"
        else
            LOGI "Database directory preserved: $db_path"
        fi
    fi
    
    # Reload systemd
    systemctl daemon-reload
    
    LOGI "${instance_name} uninstallation completed!"
    echo
}

# Function to uninstall all instances
function uninstall_all_instances() {
    local instances_array=($(detect_instances))
    
    if [ ${#instances_array[@]} -eq 0 ]; then
        echo -e "${yellow}No X-UI instances found to uninstall.${plain}"
        echo
        return
    fi
    
    echo -e "${red}╔════════════════════════════════════════╗${plain}"
    echo -e "${red}║          UNINSTALL ALL PANELS          ║${plain}"
    echo -e "${red}║            ⚠️  WARNING ⚠️             ║${plain}"
    echo -e "${red}╚════════════════════════════════════════╝${plain}"
    echo
    echo -e "${yellow}The following X-UI instances will be PERMANENTLY removed:${plain}"
    echo
    
    for i in "${!instances_array[@]}"; do
        local instance="${instances_array[$i]}"
        local status=$(systemctl is-active "$instance" 2>/dev/null || echo "inactive")
        local status_color
        local status_icon
        
        if [ "$status" = "active" ]; then
            status_color="${green}"
            status_icon="●"
        else
            status_color="${red}"
            status_icon="○"
        fi
        
        echo -e "  ${status_color}${status_icon}${plain} ${yellow}${instance}${plain} (${status_color}${status}${plain})"
    done
    
    echo
    echo -e "${red}This action will:${plain}"
    echo -e "  • Stop all running X-UI services"
    echo -e "  • Remove all installation directories"
    echo -e "  • Delete all service files"
    echo -e "  • Remove all management commands"
    echo -e "  • Optionally remove databases and configurations"
    echo
    
    LOGW "This action cannot be undone!"
    echo
    read -p "Are you absolutely sure you want to uninstall ALL X-UI panels? [y/N]: " confirm_all
    
    if [[ ! $confirm_all =~ ^[Yy]$ ]]; then
        LOGI "Uninstallation cancelled."
        return
    fi
    
    echo
    echo -e "${blue}Starting mass uninstallation...${plain}"
    echo -e "${blue}$(printf '=%.0s' {1..40})${plain}"
    
    local success_count=0
    local total_count=${#instances_array[@]}
    
    for instance in "${instances_array[@]}"; do
        echo
        echo -e "${cyan}Uninstalling ${instance}...${plain}"
        echo -e "${cyan}$(printf '%*s' 30 '' | tr ' ' '-')${plain}"
        
        # Stop and disable service
        LOGI "Stopping ${instance} service..."
        systemctl stop "${instance}" 2>/dev/null
        systemctl disable "${instance}" 2>/dev/null
        
        # Remove service file
        if [ -f "/etc/systemd/system/${instance}.service" ]; then
            LOGI "Removing service file..."
            rm -f "/etc/systemd/system/${instance}.service"
        fi
        
        # Remove installation directory
        if [ -d "/usr/local/${instance}" ]; then
            LOGI "Removing installation directory..."
            rm -rf "/usr/local/${instance}"
        fi
        
        # Remove management command
        if [ -f "/usr/bin/${instance}" ]; then
            LOGI "Removing management command..."
            rm -f "/usr/bin/${instance}"
        fi
        
        success_count=$((success_count + 1))
        LOGI "${instance} uninstalled successfully!"
    done
    
    # Handle database removal
    echo
    echo -e "${yellow}Database and configuration cleanup:${plain}"
    echo -e "${yellow}$(printf '%*s' 35 '' | tr ' ' '-')${plain}"
    
    local db_dirs=()
    for instance in "${instances_array[@]}"; do
        local db_path
        if [ "$instance" = "x-ui" ]; then
            db_path="/etc/x-ui"
        else
            db_path="/etc/${instance}"
        fi
        
        if [ -d "$db_path" ]; then
            db_dirs+=("$db_path")
        fi
    done
    
    if [ ${#db_dirs[@]} -gt 0 ]; then
        echo -e "${yellow}Found database directories:${plain}"
        for db_dir in "${db_dirs[@]}"; do
            echo -e "  • $db_dir"
        done
        echo
        read -p "Do you want to remove ALL databases and configurations? [y/N]: " remove_all_db
        
        if [[ $remove_all_db =~ ^[Yy]$ ]]; then
            for db_dir in "${db_dirs[@]}"; do
                LOGI "Removing database: $db_dir"
                rm -rf "$db_dir"
            done
        else
            LOGI "Database directories preserved."
        fi
    fi
    
    # Reload systemd
    systemctl daemon-reload
    
    echo
    echo -e "${green}╔════════════════════════════════════════╗${plain}"
    echo -e "${green}║         UNINSTALLATION COMPLETE        ║${plain}"
    echo -e "${green}╚════════════════════════════════════════╝${plain}"
    echo
    LOGI "Successfully uninstalled ${success_count}/${total_count} X-UI instances!"
    echo -e "${blue}All X-UI panels have been removed from the system.${plain}"
    echo
}

# Function to show uninstall menu
function show_uninstall_menu() {
    local instances_array=($(detect_instances))
    
    if [ ${#instances_array[@]} -eq 0 ]; then
        echo -e "${yellow}No X-UI instances found to uninstall.${plain}"
        echo
        return
    fi
    
    echo -e "${red}Available instances for uninstallation:${plain}"
    for i in "${!instances_array[@]}"; do
        local instance="${instances_array[$i]}"
        local status=$(systemctl is-active "$instance" 2>/dev/null || echo "inactive")
        echo -e "  $((i+1)). ${instance} (${status})"
    done
    echo -e "  0. Cancel"
    echo
    
    while true; do
        read -p "Select instance to uninstall [0-${#instances_array[@]}]: " choice
        
        if [ "$choice" = "0" ]; then
            LOGI "Uninstallation cancelled."
            return
        elif [ "$choice" -ge 1 ] && [ "$choice" -le "${#instances_array[@]}" ]; then
            local selected_instance="${instances_array[$((choice-1))]}"
            echo
            LOGW "You are about to uninstall: ${selected_instance}"
            read -p "Are you sure? [y/N]: " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                uninstall_instance "$selected_instance"
            else
                LOGI "Uninstallation cancelled."
            fi
            return
        else
            LOGE "Invalid choice. Please enter a number between 0 and ${#instances_array[@]}."
        fi
    done
}

# Function to detect instances
function detect_instances() {
    local instances=()
    
    # Check base x-ui
    if [ -d "/usr/local/x-ui" ] || [ -f "/usr/bin/x-ui" ]; then
        instances+=("x-ui")
    fi
    
    # Check x-ui2, x-ui3, etc. (numbered instances)
    for i in {2..10}; do
        if [ -d "/usr/local/x-ui${i}" ] || [ -f "/usr/bin/x-ui${i}" ]; then
            instances+=("x-ui${i}")
        fi
    done
    
    # Check for custom named instances by scanning /usr/local/ and /usr/bin/
    # Look for directories in /usr/local/ that contain x-ui binary
    if [ -d "/usr/local" ]; then
        for dir in /usr/local/*/; do
            if [ -d "$dir" ]; then
                local dirname=$(basename "$dir")
                # Skip already detected numbered instances and base x-ui
                if [[ "$dirname" != "x-ui" ]] && [[ ! "$dirname" =~ ^x-ui[0-9]+$ ]] && [ -f "$dir/x-ui" ]; then
                    # Verify it's actually an x-ui instance by checking for management script
                    if [ -f "/usr/bin/$dirname" ]; then
                        instances+=("$dirname")
                    fi
                fi
            fi
        done
    fi
    
    echo "${instances[@]}"
}

# Function to check status of all instances
function check_all_status() {
    echo -e "${blue}================================${plain}"
    echo -e "${blue}  X-UI Multi-Instance Status${plain}"
    echo -e "${blue}================================${plain}"
    echo
    
    # Detect all instances
    local instances_array=($(detect_instances))
    
    if [ ${#instances_array[@]} -eq 0 ]; then
        echo -e "${yellow}No X-UI instances found on this system.${plain}"
        echo -e "${blue}To install X-UI, choose option 1 from the main menu.${plain}"
        echo
        return
    fi
    
    echo -e "${green}Found ${#instances_array[@]} X-UI instance(s): ${instances_array[*]}${plain}"
    echo
    
    # Summary Table Header
    echo -e "${cyan}Instance      | Status   | Enabled | Install Dir | Cmd | DB Dir${plain}"
    echo -e "${cyan}--------------|----------|---------|-------------|-----|-------${plain}"
    
    local running_count=0
    local total_count=${#instances_array[@]}
    
    for instance in "${instances_array[@]}"; do
        local display_name
        if [ "$instance" = "x-ui" ]; then
            display_name="X-UI"
        else
            display_name="$instance"
        fi
        
        local status=$(systemctl is-active "$instance" 2>/dev/null || echo "stopped")
        local enabled=$(systemctl is-enabled "$instance" 2>/dev/null || echo "no")
        local install_path="/usr/local/$instance"
        local cmd_path="/usr/bin/$instance"
        local db_path="/etc/$instance"
        if [ "$instance" = "x-ui" ]; then
            db_path="/etc/x-ui"
        fi
        
        local status_color=${red}
        if [ "$status" = "active" ]; then
            status_color=${green}
            running_count=$((running_count + 1))
        fi
        local enabled_color=${red}
        if [ "$enabled" = "enabled" ]; then
            enabled_color=${green}
        fi
        local install_color=${green}
        if [ ! -d "$install_path" ]; then install_color=${red}; fi
        local cmd_color=${green}
        if [ ! -f "$cmd_path" ]; then cmd_color=${red}; fi
        local db_color=${green}
        if [ ! -d "$db_path" ]; then db_color=${red}; fi
        
        printf "${yellow}%-13s${plain} | ${status_color}%-8s${plain} | ${enabled_color}%-7s${plain} | ${install_color}OK${plain}         | ${cmd_color}OK${plain} | ${db_color}OK${plain}
" "$display_name" "$status" "$enabled"
    done
    echo
    

    
    # Show summary
    echo -e "${green}Summary:${plain}"
    echo -e "  Total instances: $total_count"
    echo -e "  Running: $running_count"
    echo -e "  Stopped: $((total_count - running_count))"
    echo
    
    # Show management commands
    show_management_commands "${instances_array[@]}"
    
    echo -e "${blue}================================${plain}"
}

# Function to clear screen
function clear_screen() {
    clear
}

# Function to show main menu
function show_main_menu() {
    clear_screen
    bold_cyan='\033[1;36m'
bold_blue='\033[1;34m'
bold_green='\033[1;32m'
bold_yellow='\033[1;33m'
bold_magenta='\033[1;35m'
echo -e "${bold_cyan}╔════════════════════════════════════════╗${plain}"
echo -e "${bold_cyan}║        Smart X-UI Management           ║${plain}"
echo -e "${bold_cyan}║             Control Panel              ║${plain}"
echo -e "${bold_cyan}╚════════════════════════════════════════╝${plain}"
echo
echo -e "${bold_blue}┌─ Available Operations ─────────────────┐${plain}"
echo -e "${bold_blue}│${plain}                                        ${bold_blue}│${plain}"
echo -e "${bold_blue}│${plain}  ${bold_green}[1]${plain} ${bold_yellow}Install New Instance${plain}           ${bold_blue}│${plain}"
echo -e "${bold_blue}│${plain}      ${bold_magenta}→${plain} Create and configure X-UI      ${bold_blue}│${plain}"
echo -e "${bold_blue}│${plain}                                        ${bold_blue}│${plain}"
echo -e "${bold_blue}│${plain}  ${bold_green}[2]${plain} ${bold_yellow}Check System Status${plain}            ${bold_blue}│${plain}"
echo -e "${bold_blue}│${plain}      ${bold_magenta}→${plain} View all running instances     ${bold_blue}│${plain}"
echo -e "${bold_blue}│${plain}                                        ${bold_blue}│${plain}"
echo -e "${bold_blue}│${plain}  ${bold_green}[3]${plain} ${bold_yellow}Uninstall Instance${plain}             ${bold_blue}│${plain}"
echo -e "${bold_blue}│${plain}      ${bold_magenta}→${plain} Remove X-UI installation       ${bold_blue}│${plain}"
echo -e "${bold_blue}│${plain}                                        ${bold_blue}│${plain}"
echo -e "${bold_blue}│${plain}  ${bold_green}[4]${plain} ${bold_yellow}Uninstall All Panels${plain}           ${bold_blue}│${plain}"
echo -e "${bold_blue}│${plain}      ${bold_magenta}→${plain} Remove all X-UI installations  ${bold_blue}│${plain}"
echo -e "${bold_blue}│${plain}                                        ${bold_blue}│${plain}"
echo -e "${bold_blue}│${plain}  ${bold_green}[5]${plain} ${bold_yellow}Exit Program${plain}                   ${bold_blue}│${plain}"
echo -e "${bold_blue}│${plain}      ${bold_magenta}→${plain} Close management script        ${bold_blue}│${plain}"
echo -e "${bold_blue}│${plain}                                        ${bold_blue}│${plain}"
echo -e "${bold_blue}└────────────────────────────────────────┘${plain}"
echo
}

# Function to detect next available instance
function detect_next_instance() {
    local instance_num=1
    local instance_name="x-ui"
    
    # Check if base x-ui exists
    if [ ! -d "/usr/local/x-ui" ] && [ ! -f "/usr/bin/x-ui" ]; then
        echo "x-ui"
        return
    fi
    
    # Check for x-ui2, x-ui3, etc.
    while true; do
        instance_num=$((instance_num + 1))
        instance_name="x-ui${instance_num}"
        
        if [ ! -d "/usr/local/${instance_name}" ] && [ ! -f "/usr/bin/${instance_name}" ]; then
            echo "${instance_name}"
            return
        fi
        
        # Safety check to prevent infinite loop
        if [ $instance_num -gt 10 ]; then
            LOGE "Too many instances detected. Maximum 10 instances supported."
            exit 1
        fi
    done
}

# Function to show existing installations
function show_existing_installations() {
    echo -e "${cyan}┌─ Existing X-UI Installations ───────────┐${plain}"
    echo -e "${cyan}│${plain}                                         ${cyan}│${plain}"
    
    local instances_array=($(detect_instances))
    local status_color
    local status_icon
    
    if [ ${#instances_array[@]} -eq 0 ]; then
        echo -e "${cyan}│${plain}  ${yellow}•${plain} No existing installations found        ${cyan}│${plain}"
    else
        for instance in "${instances_array[@]}"; do
            local status=$(systemctl is-active "$instance" 2>/dev/null || echo "inactive")
            if [ "$status" = "active" ]; then
                status_color="${green}"
                status_icon="●"
            else
                status_color="${red}"
                status_icon="○"
            fi
            
            # Handle long status text with meaningful abbreviations
            local display_status="$status"
            if [ ${#status} -gt 8 ]; then
                case "$status" in
                    "activating"*) display_status="starting" ;;
                    "deactivating"*) display_status="stopping" ;;
                    "reloading"*) display_status="reload" ;;
                    "failed"*) display_status="failed" ;;
                    *) display_status="${status:0:6}.." ;;
                esac
            fi
            
            # Calculate dots for alignment (adjust for box width)
            local dots_count=$((33 - ${#instance} - ${#display_status}))
            local dots=$(printf "%*s" $dots_count "" | tr ' ' '.')
            echo -e "${cyan}│${plain}  ${status_color}${status_icon}${plain} ${yellow}${instance}${plain} ${dots} ${status_color}${display_status}${plain} ${cyan}│${plain}"
        done
    fi
    
    echo -e "${cyan}│${plain}                                         ${cyan}│${plain}"
    echo -e "${cyan}└─────────────────────────────────────────┘${plain}"
}

# Function to get architecture
function get_architecture() {
    ARCH=$(uname -m)
    case "${ARCH}" in
        x86_64 | x64 | amd64) XUI_ARCH="amd64" ;;
        i*86 | x86) XUI_ARCH="386" ;;
        armv8* | armv8 | arm64 | aarch64) XUI_ARCH="arm64" ;;
        armv7* | armv7) XUI_ARCH="armv7" ;;
        armv6* | armv6) XUI_ARCH="armv6" ;;
        armv5* | armv5) XUI_ARCH="armv5" ;;
        s390x) XUI_ARCH="s390x" ;;
        *) XUI_ARCH="amd64" ;;
    esac
    echo -e "${cyan}┌─ System Architecture ───────────────────┐${plain}"
    echo -e "${cyan}│${plain}                                         ${cyan}│${plain}"
    echo -e "${cyan}│${plain}  ${green}✓${plain} Detected: ${yellow}${ARCH}${plain}                    ${cyan}│${plain}"
    echo -e "${cyan}│${plain}  ${green}✓${plain} Target: ${yellow}${XUI_ARCH}${plain}                      ${cyan}│${plain}"
    echo -e "${cyan}│${plain}                                         ${cyan}│${plain}"
    echo -e "${cyan}└─────────────────────────────────────────┘${plain}"
}

# Function to download from GitHub
function download_from_github() {
    local version="$1"
    local filename="$2"
    
    if [ "$version" = "latest" ]; then
        local download_url="https://github.com/MHSanaei/3x-ui/releases/latest/download/x-ui-linux-${XUI_ARCH}.tar.gz"
    else
        local download_url="https://github.com/MHSanaei/3x-ui/releases/download/${version}/x-ui-linux-${XUI_ARCH}.tar.gz"
    fi
    
    LOGI "Downloading from GitHub: ${download_url}"
    wget "$download_url" -O "$filename"
    
    if [ $? -ne 0 ]; then
        LOGE "Failed to download from GitHub"
        return 1
    fi
    
    return 0
}

# Function to get GitHub version
function get_github_version() {
    echo >&2
    echo -e "${cyan}┌─────────────────────────────────────────┐${plain}" >&2
    echo -e "${cyan}│         GitHub Version Options          │${plain}" >&2
    echo -e "${cyan}└─────────────────────────────────────────┘${plain}" >&2
    echo >&2
    echo -e "${green}[1]${plain} ${yellow}Latest release${plain} ${cyan}(recommended)${plain}" >&2
    echo -e "    ${cyan}→${plain} Automatically download the newest version" >&2
    echo -e "    ${cyan}→${plain} Always up-to-date with latest features" >&2
    echo >&2
    echo -e "${green}[2]${plain} ${yellow}Specific version${plain} ${cyan}(e.g., v2.3.9)${plain}" >&2
    echo -e "    ${cyan}→${plain} Choose a particular release version" >&2
    echo -e "    ${cyan}→${plain} For compatibility or testing purposes" >&2
    echo >&2
    echo -e "${cyan}─────────────────────────────────────────${plain}" >&2
    
    while true; do
        printf "\033[0;33mChoose version option [1-2]:\033[0m " >&2
        read version_choice
        
        case $version_choice in
            1)
                echo "latest"
                return
                ;;
            2)
                echo >&2
                echo -e "${cyan}Please enter the specific version you want to install:${plain}" >&2
                echo -e "${yellow}Examples:${plain} v2.3.9, v2.4.0, v1.8.3" >&2
                while true; do
                    printf "\033[0;33mVersion:\033[0m " >&2
                    read specific_version
                    if [ -n "$specific_version" ]; then
                        echo -e "${green}✓${plain} Version selected: $specific_version" >&2
                        echo "$specific_version"
                        return
                    else
                        echo -e "${red}[ERR] Version cannot be empty${plain}" >&2
                        echo -e "${yellow}Please enter a valid version (e.g., v2.3.9)${plain}" >&2
                    fi
                done
                ;;
            *)
                echo -e "${red}[ERR] Invalid choice. Please enter 1 or 2.${plain}" >&2
                ;;
        esac
    done
}

# Function to get installation source
function get_installation_source() {
    echo -e "${cyan}┌─────────────────────────────────────────┐${plain}" >&2
    echo -e "${cyan}│        Installation Sources             │${plain}" >&2
    echo -e "${cyan}└─────────────────────────────────────────┘${plain}" >&2
    echo >&2
    echo -e "${green}[1]${plain} ${yellow}Custom .tar.gz file${plain}" >&2
    echo -e "    ${cyan}→${plain} Install from your own X-UI package file or URL" >&2
    echo -e "    ${cyan}→${plain} Use local file or download from URL" >&2
    echo >&2
    echo -e "${green}[2]${plain} ${yellow}GitHub releases${plain}" >&2
    echo -e "    ${cyan}→${plain} Download from MHSanaei/3x-ui repository" >&2
    echo -e "    ${cyan}→${plain} Get latest or specific version" >&2
    echo >&2
    echo -e "${cyan}─────────────────────────────────────────${plain}" >&2
    
    while true; do
        printf "\033[0;33mChoose installation source [1-2]:\033[0m " >&2
        read source_choice
        
        case $source_choice in
            1)
                echo >&2
                echo -e "${cyan}Please provide the full path or URL to your X-UI package file:${plain}" >&2
                while true; do
                    printf "\033[0;33mFile path/URL:\033[0m " >&2
                    read tar_file
                    
                    # Check if it's a URL
                    if [[ "$tar_file" =~ ^https?:// ]]; then
                        echo -e "${blue}Downloading from URL: $tar_file${plain}" >&2
                        temp_file="/tmp/x-ui-custom-$(date +%s).tar.gz"
                        if wget -q --show-progress -O "$temp_file" "$tar_file"; then
                            echo -e "${green}✓${plain} Downloaded successfully: $temp_file" >&2
                            echo "custom:$temp_file"
                            return
                        else
                            echo -e "${red}[ERR] Failed to download: $tar_file${plain}" >&2
                            echo -e "${yellow}Please check the URL and try again${plain}" >&2
                        fi
                    # Check if it's a local file
                    elif [ -f "$tar_file" ]; then
                        echo -e "${green}✓${plain} File found: $tar_file" >&2
                        echo "custom:$tar_file"
                        return
                    else
                        echo -e "${red}[ERR] File not found: $tar_file${plain}" >&2
                        echo -e "${yellow}Please enter a valid path to a .tar.gz file or a valid URL${plain}" >&2
                    fi
                done
                ;;
            2)
                local version=$(get_github_version)
                echo "github:$version"
                return
                ;;
            *)
                echo -e "${red}[ERR] Invalid choice. Please enter 1 or 2.${plain}" >&2
                ;;
        esac
    done
}

# Function to install instance
function install_instance() {
    local instance_name="$1"
    local source_info="$2"
    local temp_file="/tmp/${instance_name}-linux-${XUI_ARCH}.tar.gz"
    
    LOGI "Installing ${instance_name}..."
    
    # Download or copy source file
    if [[ $source_info == custom:* ]]; then
        local source_file="${source_info#custom:}"
        LOGI "Using custom file: $source_file"
        cp "$source_file" "$temp_file"
        if [ $? -ne 0 ]; then
            LOGE "Failed to copy custom file"
            return 1
        fi
    elif [[ $source_info == github:* ]]; then
        local version="${source_info#github:}"
        download_from_github "$version" "$temp_file"
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    
    # Remove any existing installation
    echo -e "${yellow}[1/6]${plain} Cleaning up existing installation..."
    systemctl stop "${instance_name}" 2>/dev/null
    systemctl disable "${instance_name}" 2>/dev/null
    rm -rf "/usr/local/${instance_name}/" "/usr/bin/${instance_name}" "/etc/systemd/system/${instance_name}.service"
    echo -e "      ${green}✓${plain} Cleanup completed"
    
    # Extract and prepare
    cd /tmp
    rm -rf "${instance_name}/"
    
    echo -e "${yellow}[2/6]${plain} Extracting installation package..."
    tar zxf "$temp_file" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        LOGE "Failed to extract package"
        return 1
    fi
    echo -e "      ${green}✓${plain} Package extracted successfully"
    
    # Rename extracted folder
    mv x-ui "${instance_name}"
    
    # Set permissions
    echo -e "${yellow}[3/6]${plain} Setting file permissions..."
    chmod +x "${instance_name}/x-ui" "${instance_name}/bin/xray-linux-"* "${instance_name}/x-ui.sh"
    echo -e "      ${green}✓${plain} Permissions configured"
    
    # Create modified management script
    echo -e "${yellow}[4/6]${plain} Creating management script..."
    cp "${instance_name}/x-ui.sh" "${instance_name}/${instance_name}.sh"
    
    # Modify the script for this instance - make it instance-aware
    if [ "$instance_name" != "x-ui" ]; then
        # Add instance detection logic at the top of the script
        sed -i '1a\
# Auto-detect instance name from script name\
SCRIPT_NAME=$(basename "$0")\
INSTANCE_NAME="$SCRIPT_NAME"\
SERVICE_NAME="$SCRIPT_NAME"\
BINARY_PATH="/usr/local/$SCRIPT_NAME/x-ui"\
DB_PATH="/etc/$SCRIPT_NAME"\
' "${instance_name}/${instance_name}.sh"
        
        # Replace hardcoded paths with variables and add environment variable support
         sed -i "s|/usr/local/x-ui/x-ui|XUI_DB_FOLDER=\$DB_PATH \$BINARY_PATH|g" "${instance_name}/${instance_name}.sh"
         sed -i "s|/usr/local/x-ui|/usr/local/\$INSTANCE_NAME|g" "${instance_name}/${instance_name}.sh"
         sed -i "s|/usr/bin/x-ui|/usr/bin/\$INSTANCE_NAME|g" "${instance_name}/${instance_name}.sh"
         sed -i "s|x-ui\.service|\$SERVICE_NAME.service|g" "${instance_name}/${instance_name}.sh"
         sed -i "s|journalctl -u x-ui\.service|journalctl -u \$SERVICE_NAME.service|g" "${instance_name}/${instance_name}.sh"
         sed -i "s|systemctl stop x-ui|systemctl stop \$SERVICE_NAME|g" "${instance_name}/${instance_name}.sh"
         sed -i "s|systemctl start x-ui|systemctl start \$SERVICE_NAME|g" "${instance_name}/${instance_name}.sh"
         sed -i "s|systemctl restart x-ui|systemctl restart \$SERVICE_NAME|g" "${instance_name}/${instance_name}.sh"
         sed -i "s|systemctl disable x-ui|systemctl disable \$SERVICE_NAME|g" "${instance_name}/${instance_name}.sh"
         sed -i "s|systemctl enable x-ui|systemctl enable \$SERVICE_NAME|g" "${instance_name}/${instance_name}.sh"
         sed -i "s|systemctl status x-ui|systemctl status \$SERVICE_NAME|g" "${instance_name}/${instance_name}.sh"
         sed -i "s|systemctl is-active x-ui|systemctl is-active \$SERVICE_NAME|g" "${instance_name}/${instance_name}.sh"
         sed -i "s|systemctl is-enabled x-ui|systemctl is-enabled \$SERVICE_NAME|g" "${instance_name}/${instance_name}.sh"
         sed -i "s|/etc/x-ui/|\$DB_PATH/|g" "${instance_name}/${instance_name}.sh"
    else
         # For base x-ui instance, also add instance detection for consistency
         sed -i '1a\
 # Auto-detect instance name from script name\
 SCRIPT_NAME=$(basename "$0")\
 INSTANCE_NAME="x-ui"\
 SERVICE_NAME="x-ui"\
 BINARY_PATH="/usr/local/x-ui/x-ui"\
 DB_PATH="/etc/x-ui"\
 ' "${instance_name}/${instance_name}.sh"
         
         # Replace hardcoded paths with variables for consistency
         sed -i "s|/usr/local/x-ui/x-ui|\$BINARY_PATH|g" "${instance_name}/${instance_name}.sh"
         sed -i "s|/etc/x-ui/|\$DB_PATH/|g" "${instance_name}/${instance_name}.sh"
    fi
    echo -e "      ${green}✓${plain} Management script created"
    
    # Create separate database directory
    if [ "$instance_name" != "x-ui" ]; then
        echo -e "${yellow}[5/6]${plain} Setting up database directory..."
        mkdir -p "/etc/${instance_name}"
        chown root:root "/etc/${instance_name}"
        chmod 755 "/etc/${instance_name}"
        echo -e "      ${green}✓${plain} Database directory: /etc/${instance_name}/"
    else
        echo -e "${yellow}[5/6]${plain} Configuring system service..."
    fi
    
    # Create service file
    if [ "$instance_name" = "x-ui" ]; then
        cp "${instance_name}/x-ui.service" "/etc/systemd/system/"
    else
        cat > "${instance_name}/${instance_name}.service" << EOF
[Unit]
Description=${instance_name} Service
After=network.target
Wants=network.target

[Service]
Environment="XRAY_VMESS_AEAD_FORCED=false"
Environment="XUI_DB_FOLDER=/etc/${instance_name}"
Type=simple
WorkingDirectory=/usr/local/${instance_name}/
ExecStart=/usr/local/${instance_name}/x-ui
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
        cp "${instance_name}/${instance_name}.service" "/etc/systemd/system/"
    fi
    echo -e "      ${green}✓${plain} Service file configured"
    
    # Install files
    echo -e "${yellow}[6/6]${plain} Installing system files..."
    if [ "$instance_name" = "x-ui" ]; then
        cp "${instance_name}/x-ui.sh" "/usr/bin/x-ui"
    else
        cp "${instance_name}/${instance_name}.sh" "/usr/bin/${instance_name}"
    fi
    mv "${instance_name}/" "/usr/local/"
    chmod +x "/usr/bin/${instance_name}"
    echo -e "      ${green}✓${plain} Files installed to system"
    
    # Start service temporarily to initialize database
    echo
    echo -e "${blue}Starting ${instance_name} service for initialization...${plain}"
    systemctl daemon-reload
    systemctl enable "${instance_name}" >/dev/null 2>&1
    systemctl start "${instance_name}"
    
    # Wait for service to fully initialize
    sleep 2
    
    # Stop service before applying configuration changes
    echo -e "${blue}Stopping ${instance_name} service to apply configuration...${plain}"
    systemctl stop "${instance_name}"
    sleep 1
    
    # Configure random security settings
    configure_random_security "${instance_name}"
    
    # Start service with new configuration
    echo -e "${blue}Starting ${instance_name} service with new configuration...${plain}"
    systemctl start "${instance_name}"
    
    # Check final service status
    sleep 1
    if systemctl is-active --quiet "${instance_name}"; then
        
        echo
        echo -e "${green}================================${plain}"
        echo -e "${green}   Installation Successful!${plain}"
        echo -e "${green}================================${plain}"
        echo
        echo -e "${cyan}Instance Details:${plain}"
        echo -e "  ${green}●${plain} Name: ${cyan}${instance_name}${plain}"
        echo -e "  ${green}●${plain} Status: ${green}$(systemctl is-active ${instance_name})${plain}"
        echo -e "  ${green}●${plain} Management: ${yellow}${instance_name}${plain}"
        if [ "$instance_name" != "x-ui" ]; then
            echo -e "  ${green}●${plain} Database: ${yellow}/etc/${instance_name}/${plain}"
        fi
        echo
        echo -e "${cyan}Quick Commands:${plain}"
        echo -e "  Start service:   ${yellow}systemctl start ${instance_name}${plain}"
        echo -e "  Stop service:    ${yellow}systemctl stop ${instance_name}${plain}"
        echo -e "  Restart service: ${yellow}systemctl restart ${instance_name}${plain}"
        echo -e "  Check status:    ${yellow}systemctl status ${instance_name}${plain}"
        echo -e "  Management menu: ${yellow}${instance_name}${plain}"
        echo
    else
        echo
        echo -e "${red}================================${plain}"
        echo -e "${red}   Installation Failed!${plain}"
        echo -e "${red}================================${plain}"
        echo
        LOGE "${instance_name} service failed to start."
        LOGE "Check logs with: journalctl -u ${instance_name}.service"
        return 1
    fi
    
    # Clean up
    rm -f "$temp_file"
    
    return 0
}



# Main execution
if [[ $# -eq 0 ]]; then
    # Interactive mode with menu
    clear_screen
    while true; do
        show_main_menu
        
        read -p "Enter your choice [1-5]: " choice
        echo
        
        case $choice in
            1)
                # Install new instance
                clear_screen
                echo -e "${cyan}╔════════════════════════════════════════╗${plain}"
                echo -e "${cyan}║          X-UI Installation             ║${plain}"
                echo -e "${cyan}║            Setup Wizard                ║${plain}"
                echo -e "${cyan}╚════════════════════════════════════════╝${plain}"
                echo
                
                # Step 1: Architecture Detection
                get_architecture
                echo
                
                # Step 2: Existing Installations
                show_existing_installations
                echo
                
                # Step 3: Instance Name Selection
                echo -e "${blue}Choose instance name...${plain}"
                echo -e "${yellow}Instance naming options:${plain}"
                echo -e "  ${green}1)${plain} Auto-detect next available (${cyan}$(detect_next_instance)${plain})"
                echo -e "  ${green}2)${plain} Custom name"
                echo
                printf "${yellow}Select option [1-2]:${plain} "
                read name_choice
                echo
                
                case $name_choice in
                    1)
                        next_instance=$(detect_next_instance)
                        LOGI "Using auto-detected instance: ${next_instance}"
                        ;;
                    2)
                        while true; do
                            printf "${yellow}Enter custom instance name (alphanumeric, no spaces):${plain} "
                            read custom_name
                            
                            # Validate custom name
                            if [[ -z "$custom_name" ]]; then
                                LOGE "Instance name cannot be empty."
                                continue
                            fi
                            
                            if [[ ! "$custom_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                                LOGE "Instance name can only contain letters, numbers, hyphens, and underscores."
                                continue
                            fi
                            
                            # Check if instance already exists
                            if [ -d "/usr/local/${custom_name}" ] || [ -f "/usr/bin/${custom_name}" ] || systemctl list-units --full -all | grep -Fq "${custom_name}.service"; then
                                LOGE "Instance '${custom_name}' already exists. Please choose a different name."
                                continue
                            fi
                            
                            next_instance="$custom_name"
                            LOGI "Using custom instance name: ${next_instance}"
                            break
                        done
                        ;;
                    *)
                        LOGE "Invalid choice. Using auto-detected instance."
                        next_instance=$(detect_next_instance)
                        LOGI "Using auto-detected instance: ${next_instance}"
                        ;;
                esac
                echo
                
                # Step 4: Source Selection
                echo -e "${blue}Choose your preferred download method...${plain}"
                source_info=$(get_installation_source)
                echo
                
                # Step 5: Final Confirmation
                echo -e "${yellow}Installation Summary:${plain}"
                echo -e "  ${green}•${plain} Instance name: ${cyan}${next_instance}${plain}"
                echo -e "  ${green}•${plain} Service name: ${cyan}${next_instance}.service${plain}"
                echo -e "  ${green}•${plain} Management command: ${cyan}${next_instance}${plain}"
                if [ "$next_instance" != "x-ui" ]; then
                    echo -e "  ${green}•${plain} Database location: ${cyan}/etc/${next_instance}/${plain}"
                fi
                echo -e "  ${green}•${plain} Download source: ${cyan}$(echo "$source_info" | cut -d':' -f1)${plain}"
                echo
                printf "${yellow}Proceed with installation? [y/N]:${plain} "
                read confirm
                if [[ ! $confirm =~ ^[Yy]$ ]]; then
                    LOGI "Installation cancelled."
                    echo
                    read -p "Press Enter to continue..."
                    continue
                fi
                echo
                
                # Step 6: Installation
                echo -e "${blue}Installing ${next_instance}${plain}"
                install_instance "$next_instance" "$source_info"
                
                if [ $? -eq 0 ]; then
                    echo
                    LOGI "Installation complete!"
                    LOGI "Management command: ${next_instance}"
                    LOGI "Service name: ${next_instance}.service"
                    if [ "$next_instance" != "x-ui" ]; then
                        LOGI "Database location: /etc/${next_instance}/"
                    fi
                    echo -e "${blue}================================${plain}"
                else
                    LOGE "Installation failed!"
                fi
                
                echo
                 read -p "Press Enter to continue..."
                 ;;
             2)
                 # Check status
                 check_all_status
                 echo
                 read -p "Press Enter to continue..."
                 ;;
             3)
                 # Uninstall instance
                 show_uninstall_menu
                 echo
                 read -p "Press Enter to continue..."
                 ;;
             4)
                 # Uninstall all panels
                 uninstall_all_instances
                 echo
                 read -p "Press Enter to continue..."
                 ;;
            5)
                 # Exit
                 clear_screen
                 echo -e "${green}Thank you for using Smart X-UI Management Script!${plain}"
                 echo -e "${blue}Returning to shell...${plain}"
                 echo
                 exit 0
                 ;;
            *)
                LOGE "Invalid choice. Please enter a number between 1 and 5."
                echo
                ;;
        esac
    done
else
    # Command line mode
    case "$1" in
        "--file")
            if [ -z "$2" ]; then
                LOGE "Please specify the .tar.gz file path or URL"
                exit 1
            fi
            
            # Check if it's a URL
            if [[ "$2" =~ ^https?:// ]]; then
                LOGI "Downloading from URL: $2"
                temp_file="/tmp/x-ui-custom-$(date +%s).tar.gz"
                if wget -q --show-progress -O "$temp_file" "$2"; then
                    LOGI "Downloaded successfully: $temp_file"
                    get_architecture
                    next_instance=$(detect_next_instance)
                    LOGI "Installing $next_instance from downloaded file: $temp_file"
                    install_instance "$next_instance" "custom:$temp_file"
                else
                    LOGE "Failed to download: $2"
                    exit 1
                fi
            # Check if it's a local file
            elif [ ! -f "$2" ]; then
                LOGE "File not found: $2"
                exit 1
            else
                get_architecture
                next_instance=$(detect_next_instance)
                LOGI "Installing $next_instance from custom file: $2"
                install_instance "$next_instance" "custom:$2"
            fi
            ;;
        "--github")
            get_architecture
            next_instance=$(detect_next_instance)
            if [ -n "$2" ]; then
                LOGI "Installing $next_instance from GitHub version: $2"
                install_instance "$next_instance" "github:$2"
            else
                LOGI "Installing $next_instance from GitHub (latest)"
                install_instance "$next_instance" "github:latest"
            fi
            ;;
        "--status")
            check_all_status
            ;;
        "--uninstall")
            if [ -z "$2" ]; then
                show_uninstall_menu
            else
                uninstall_instance "$2"
            fi
            ;;
        "--name")
            if [ -z "$2" ]; then
                LOGE "Instance name is required with --name option"
                echo "Usage: $0 --name <instance_name> [--file <path/url> | --github [version]]"
                exit 1
            fi
            
            # Validate custom name
            if [[ ! "$2" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                LOGE "Instance name can only contain letters, numbers, hyphens, and underscores."
                exit 1
            fi
            
            # Check if instance already exists
            if [ -d "/usr/local/$2" ] || [ -f "/usr/bin/$2" ] || systemctl list-units --full -all | grep -Fq "$2.service"; then
                LOGE "Instance '$2' already exists. Please choose a different name."
                exit 1
            fi
            
            get_architecture
            custom_instance_name="$2"
            
            # Check for additional options
            if [ -n "$3" ]; then
                case "$3" in
                    "--file")
                        if [ -z "$4" ]; then
                            LOGE "File path/URL is required with --file option"
                            exit 1
                        fi
                        # Check if it's a URL
                        if [[ "$4" =~ ^https?:// ]]; then
                            temp_file="/tmp/$custom_instance_name-custom-$(date +%s).tar.gz"
                            if wget -q --show-progress -O "$temp_file" "$4"; then
                                LOGI "Downloaded successfully: $temp_file"
                                LOGI "Installing $custom_instance_name from downloaded file: $temp_file"
                                install_instance "$custom_instance_name" "custom:$temp_file"
                            else
                                LOGE "Failed to download: $4"
                                exit 1
                            fi
                        elif [ ! -f "$4" ]; then
                            LOGE "File not found: $4"
                            exit 1
                        else
                            LOGI "Installing $custom_instance_name from custom file: $4"
                            install_instance "$custom_instance_name" "custom:$4"
                        fi
                        ;;
                    "--github")
                        if [ -n "$4" ]; then
                            LOGI "Installing $custom_instance_name from GitHub version: $4"
                            install_instance "$custom_instance_name" "github:$4"
                        else
                            LOGI "Installing $custom_instance_name from GitHub (latest)"
                            install_instance "$custom_instance_name" "github:latest"
                        fi
                        ;;
                    *)
                        LOGE "Invalid option with --name: $3"
                        echo "Usage: $0 --name <instance_name> [--file <path/url> | --github [version]]"
                        exit 1
                        ;;
                esac
            else
                # Default to GitHub latest if no source specified
                LOGI "Installing $custom_instance_name from GitHub (latest)"
                install_instance "$custom_instance_name" "github:latest"
            fi
            ;;
        "--help")
            echo "Smart X-UI Multi-Instance Management Script"
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --file <path/url>    Install from custom .tar.gz file or URL"
            echo "  --github [version]   Install from GitHub (latest or specific version)"
            echo "  --name <name>        Install with custom instance name"
            echo "  --status             Check status of all instances"
            echo "  --uninstall [name]   Uninstall specific instance or show menu"
            echo "  --help               Show this help message"
            echo
            echo "Examples:"
            echo "  $0 --name my-panel                    # Install with custom name (GitHub latest)"
            echo "  $0 --name my-panel --github v1.8.3    # Install custom name with specific version"
            echo "  $0 --name my-panel --file /path/file  # Install custom name from local file"
            echo
            echo "Interactive mode: Run without arguments to access the menu"
            ;;
        *)
            LOGE "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
fi