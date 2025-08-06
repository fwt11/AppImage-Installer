#!/bin/bash

# AppImage安装脚本
# 使用方法: ./install-appimage.sh <AppImage文件>

set -e

if [ $# -ne 1 ]; then
    echo "使用方法: $0 <AppImage文件>"
    exit 1
fi

APPIMAGE_PATH="$1"
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

TARGET_DIR="$HOME/Applications/$PURE_NAME"
TEMP_DIR=$(mktemp -d)

echo "正在处理: $PURE_NAME"

# 创建目标目录
mkdir -p "$TARGET_DIR"

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
mv "$APPIMAGE_PATH" "$TARGET_DIR/$PURE_NAME.AppImage"
chmod +x "$TARGET_DIR/$PURE_NAME.AppImage"

# 移动图标
if [ -n "$ICON_FILE" ]; then
    echo "正在移动图标..."
    ICON_EXT="${ICON_FILE##*.}"
    cp "$TEMP_DIR/$ICON_FILE" "$TARGET_DIR/$PURE_NAME.$ICON_EXT"
    ICON_PATH="$TARGET_DIR/$PURE_NAME.$ICON_EXT"
else
    ICON_PATH=""
fi

# 处理desktop文件
if [ -n "$DESKTOP_FILE" ]; then
    echo "正在处理desktop文件..."
    cp "$TEMP_DIR/$DESKTOP_FILE" "$TARGET_DIR/$PURE_NAME.desktop"
    
    # 更新desktop文件中的路径
    DESKTOP_PATH="$TARGET_DIR/$PURE_NAME.desktop"
    
    # 更新Exec字段
    sed -i "s|^Exec=.*|Exec=$TARGET_DIR/$PURE_NAME.AppImage|" "$DESKTOP_PATH"
    
    # 更新Icon字段
    if [ -n "$ICON_PATH" ]; then
        sed -i "s|^Icon=.*|Icon=$ICON_PATH|" "$DESKTOP_PATH"
    fi
    
    # 拷贝desktop文件到应用目录
    echo "正在安装应用程序启动器..."
    mkdir -p "$HOME/.local/share/applications"
    cp "$DESKTOP_PATH" "$HOME/.local/share/applications/"
    
    # 更新desktop数据库
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$HOME/.local/share/applications"
    fi
fi

# 清理临时文件
rm -rf "$TEMP_DIR"

echo "安装完成！"
echo "AppImage已安装到: $TARGET_DIR"
echo "应用程序可在应用菜单中找到"