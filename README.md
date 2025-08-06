# AppImage Installer

A simple shell script to install and manage AppImage applications on Linux systems. It automatically extracts icons and desktop files, organizes applications into clean directories, and creates proper desktop integration.

## Features

- **Automatic Extraction**: Extracts icons and `.desktop` files from AppImage packages
- **Clean Organization**: Creates application directories with clean names (removes version numbers and architecture suffixes)
- **Desktop Integration**: Properly installs `.desktop` files for system integration
- **Smart Naming**: Automatically sanitizes application names by removing version numbers and architecture identifiers
- **User-Friendly**: Simple one-command installation process

## Usage

```bash
./install-appimage.sh path/to/your-app.AppImage
```

## What it does

1. **Extracts** the AppImage contents to a temporary directory
2. **Identifies** the correct icon and desktop file
3. **Creates** a clean directory under `~/Applications/` using the application name
4. **Moves** the AppImage, icon, and desktop file to the new directory
5. **Updates** paths in the desktop file to point to the correct locations
6. **Installs** the desktop file to `~/.local/share/applications/` for system integration

## Directory Structure

After installation, your applications will be organized like:

```
~/Applications/
├── Cursor/
│   ├── Cursor.AppImage
│   ├── Cursor.png
│   └── Cursor.desktop
├── VSCode/
│   ├── VSCode.AppImage
│   ├── VSCode.png
│   └── VSCode.desktop
└── Firefox/
    ├── Firefox.AppImage
    ├── Firefox.png
    └── Firefox.desktop
```

## Requirements

- Linux system with support for AppImage
- Bash shell
- Standard Unix tools (find, sed, chmod, etc.)

## Installation

1. Clone this repository
2. Make the script executable: `chmod +x install-appimage.sh`
3. Run it with any AppImage file

## Examples

```bash
# Install Cursor IDE
./install-appimage.sh Cursor-0.45.1-x86_64.AppImage

# Install VS Code
./install-appimage.sh code-1.95.0-1729604362.el7.AppImage
```

The script will automatically:
- Remove version numbers and architecture suffixes from directory names
- Extract the application icon
- Create proper desktop integration
- Make the AppImage executable