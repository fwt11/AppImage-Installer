#!/bin/bash

# AppImage安装脚本
# 使用方法: ./install-appimage.sh <AppImage文件> [--system] [--no-sandbox]

set -e

if [ $# -lt 1 ] || [ $# -gt 3 ]; then
    echo "使用方法: $0 <AppImage文件> [--system] [--no-sandbox]"
    echo "  --system: 安装到系统目录 (/opt/Applications)"
    echo "  --no-sandbox: 在启动时添加--no-sandbox参数"
    exit 1
fi

# 检查是否为系统安装
SYSTEM_INSTALL=false
NO_SANDBOX=false

for arg in "$@"; do
    case "$arg" in
        --system)
            SYSTEM_INSTALL=true
            ;;
        --no-sandbox)
            NO_SANDBOX=true
            ;;
    esac
done

APPIMAGE_PATH="$1"

# 将相对路径转换为绝对路径
if [[ "$APPIMAGE_PATH" != /* ]]; then
    APPIMAGE_PATH="$(realpath "$APPIMAGE_PATH")"
fi

if [ ! -f "$APPIMAGE_PATH" ]; then
    echo "错误: 文件 '$APPIMAGE_PATH' 不存在"
    exit 1
fi

if [[ ! "$APPIMAGE_PATH" =~ \.AppImage$ ]]; then
    echo "错误: 文件必须以.AppImage结尾"
    exit 1
fi

# 获取文件名和目录名
FULL_BASENAME=$(basename "$APPIMAGE_PATH" .AppImage)

# 提取纯净软件名（移除版本号和架构信息）
PURE_NAME=$(echo "$FULL_BASENAME" | sed -E 's/[-_]([0-9]+(\.[0-9]+)+.*$|[aA]md64|[xX]86_64|[iI]686|[aA]arch64|[aA]rm64|[uU]niversal|[lL]inux)//g' | sed -E 's/[-_][0-9].*$//')

# 确保名称不为空
if [ -z "$PURE_NAME" ]; then
    PURE_NAME="$FULL_BASENAME"
fi

# 设置目标目录
if [ "$SYSTEM_INSTALL" = true ]; then
    TARGET_DIR="/opt/Applications/$PURE_NAME"
else
    TARGET_DIR="$HOME/Applications/$PURE_NAME"
fi
TEMP_DIR=$(mktemp -d)

echo "正在处理: $PURE_NAME"

# 创建目标目录
if [ "$SYSTEM_INSTALL" = true ]; then
    if command -v sudo >/dev/null 2>&1; then
        sudo mkdir -p "$TARGET_DIR"
    else
        echo "错误: 需要sudo权限来创建系统目录 $TARGET_DIR"
        exit 1
    fi
else
    mkdir -p "$TARGET_DIR"
fi

# 解压AppImage
echo "正在解压AppImage..."
cd "$TEMP_DIR"
"$APPIMAGE_PATH" --appimage-extract >/dev/null 2>&1

# 查找图标和desktop文件
DESKTOP_FILE=$(find squashfs-root -name "*.desktop" | head -n 1)
ICON_FILE=$(find squashfs-root -type f \( -name "*.png" -o -name "*.svg" -o -name "*.xpm" \) | grep -i icon | head -n 1)

if [ -z "$DESKTOP_FILE" ]; then
    echo "警告: 未找到desktop文件"
    DESKTOP_FILE=""
fi

if [ -z "$ICON_FILE" ]; then
    echo "警告: 未找到图标文件"
    ICON_FILE=""
fi

# 移动AppImage
echo "正在移动AppImage..."
if [ "$SYSTEM_INSTALL" = true ]; then
    sudo mv "$APPIMAGE_PATH" "$TARGET_DIR/$PURE_NAME.AppImage"
    sudo chmod +x "$TARGET_DIR/$PURE_NAME.AppImage"
else
    mv "$APPIMAGE_PATH" "$TARGET_DIR/$PURE_NAME.AppImage"
    chmod +x "$TARGET_DIR/$PURE_NAME.AppImage"
fi

# 移动图标
if [ -n "$ICON_FILE" ]; then
    echo "正在移动图标..."
    ICON_EXT="${ICON_FILE##*.}"
    if [ "$SYSTEM_INSTALL" = true ]; then
        sudo cp "$TEMP_DIR/$ICON_FILE" "$TARGET_DIR/$PURE_NAME.$ICON_EXT"
    else
        cp "$TEMP_DIR/$ICON_FILE" "$TARGET_DIR/$PURE_NAME.$ICON_EXT"
    fi
    ICON_PATH="$TARGET_DIR/$PURE_NAME.$ICON_EXT"
else
    ICON_PATH=""
fi

# 处理desktop文件
if [ -n "$DESKTOP_FILE" ]; then
    echo "正在处理desktop文件..."
    if [ "$SYSTEM_INSTALL" = true ]; then
        sudo cp "$TEMP_DIR/$DESKTOP_FILE" "$TARGET_DIR/$PURE_NAME.desktop"
    else
        cp "$TEMP_DIR/$DESKTOP_FILE" "$TARGET_DIR/$PURE_NAME.desktop"
    fi
    
    # 更新desktop文件中的路径
    DESKTOP_PATH="$TARGET_DIR/$PURE_NAME.desktop"
    
    # 更新Exec字段
    if [ "$SYSTEM_INSTALL" = true ]; then
        if [ "$NO_SANDBOX" = true ]; then
            sudo sed -i "s|^Exec=.*|Exec=$TARGET_DIR/$PURE_NAME.AppImage --no-sandbox|" "$DESKTOP_PATH"
        else
            sudo sed -i "s|^Exec=.*|Exec=$TARGET_DIR/$PURE_NAME.AppImage|" "$DESKTOP_PATH"
        fi
        
        # 更新Icon字段
        if [ -n "$ICON_PATH" ]; then
            sudo sed -i "s|^Icon=.*|Icon=$ICON_PATH|" "$DESKTOP_PATH"
        fi
    else
        if [ "$NO_SANDBOX" = true ]; then
            sed -i "s|^Exec=.*|Exec=$TARGET_DIR/$PURE_NAME.AppImage --no-sandbox|" "$DESKTOP_PATH"
        else
            sed -i "s|^Exec=.*|Exec=$TARGET_DIR/$PURE_NAME.AppImage|" "$DESKTOP_PATH"
        fi
        
        # 更新Icon字段
        if [ -n "$ICON_PATH" ]; then
            sed -i "s|^Icon=.*|Icon=$ICON_PATH|" "$DESKTOP_PATH"
        fi
    fi
    
    # 拷贝desktop文件到应用目录
    echo "正在安装应用程序启动器..."
    if [ "$SYSTEM_INSTALL" = true ]; then
        # 系统安装：直接使用sudo（前面已经检查过sudo权限）
        sudo mkdir -p "/usr/share/applications"
        sudo cp "$DESKTOP_PATH" "/usr/share/applications/"
        
        # 更新系统desktop数据库
        if command -v update-desktop-database >/dev/null 2>&1; then
            sudo update-desktop-database "/usr/share/applications"
        fi
    else
        # 用户安装
        mkdir -p "$HOME/.local/share/applications"
        cp "$DESKTOP_PATH" "$HOME/.local/share/applications/"
        
        # 更新用户desktop数据库
        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database "$HOME/.local/share/applications"
        fi
    fi
fi

# 清理临时文件
rm -rf "$TEMP_DIR"

echo "安装完成！"
echo "AppImage已安装到: $TARGET_DIR"
echo "应用程序可在应用菜单中找到"