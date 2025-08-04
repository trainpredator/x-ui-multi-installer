# 3X-UI Multi-Instance Manager

A script for installing multiple 3X-UI instances on a single server with complete isolation.

## Key Features

✅ **Custom Instance Names** - Use any name you want (e.g., `my-panel`, `backup-ui`, `test-server`)

✅ **Multiple Installation Sources** - Install from GitHub releases or local files

✅ **Smart Detection** - Automatically finds existing instances

✅ **Complete Isolation** - Each instance has separate database and configuration

✅ **Easy Management** - Interactive menu and command-line support

✅ **Safe Uninstallation** - Remove instances with database preservation options

## Quick Installation

```bash
# Download the script
curl -O https://raw.githubusercontent.com/trainpredator/x-ui-multi-installer/main/install-x-ui.sh

# Make it executable and run
chmod +x install-x-ui.sh
./install-x-ui.sh
```


### ⚡ Command Line (Advanced)

```bash
# Install with custom name
./install-x-ui.sh --name my-panel                    # Latest from GitHub
./install-x-ui.sh --name backup-ui --github v1.8.3   # Specific version
./install-x-ui.sh --name test-server --file /path/to/file.tar.gz  # Local file

# Install with auto-numbered names (x-ui, x-ui2, x-ui3...)
./install-x-ui.sh --github                           # Latest version
./install-x-ui.sh --file /path/to/file.tar.gz        # From local file

# Management commands
./install-x-ui.sh --status                           # Check all instances
./install-x-ui.sh --uninstall my-panel               # Remove specific instance
./install-x-ui.sh --uninstall                        # Show removal menu
./install-x-ui.sh --help                             # Show all options
```


## 🗑️ Uninstallation

### Easy Removal

```bash
# Interactive menu - choose which instance to remove
./install-x-ui.sh --uninstall

# Remove specific instance directly
./install-x-ui.sh --uninstall my-panel
./install-x-ui.sh --uninstall x-ui2
```

### Manual Removal (if needed)

```bash
# Replace 'my-panel' with your instance name
sudo systemctl stop my-panel
sudo systemctl disable my-panel
sudo rm -rf /usr/local/my-panel/
sudo rm -f /usr/bin/my-panel
sudo rm -f /etc/systemd/system/my-panel.service
sudo rm -rf /etc/my-panel/  # This removes the database too
sudo systemctl daemon-reload
```


## 🔒 Security Tips

- **If you encounter issues with xray, check for port conflicts**
- Use different admin credentials for each instance
- Configure unique ports for each web panel
- Set up firewall rules for all instances
- Update each instance independently
