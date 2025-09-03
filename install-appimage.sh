#!/bin/bash

# AppImage安装和管理脚本
# 安装用法: ./install-appimage.sh <AppImage文件> [--system] [--no-sandbox]
# 卸载用法: ./install-appimage.sh --uninstall [过滤字符串]

set -e

# 函数定义
show_installed_apps() {
    local filter="$1"
    local apps=()
    local i=1
    
    echo "已安装的AppImage应用:"
    echo "================================"
    
    # 查找用户安装的应用
    if [ -d "$HOME/Applications" ]; then
        for app_dir in "$HOME/Applications"/*/; do
            if [ -d "$app_dir" ]; then
                local app_name=$(basename "$app_dir")
                if [ -z "$filter" ] || [[ "$app_name" =~ $filter ]]; then
                    apps+=("USER:$app_name:$app_dir")
                fi
            fi
        done
    fi
    
    # 查找系统安装的应用
    if [ -d "/opt/Applications" ]; then
        for app_dir in "/opt/Applications"/*/; do
            if [ -d "$app_dir" ]; then
                local app_name=$(basename "$app_dir")
                if [ -z "$filter" ] || [[ "$app_name" =~ $filter ]]; then
                    apps+=("SYSTEM:$app_name:$app_dir")
                fi
            fi
        done
    fi
    
    if [ ${#apps[@]} -eq 0 ]; then
        if [ -n "$filter" ]; then
            echo "未找到匹配 '$filter' 的应用"
        else
            echo "未找到已安装的应用"
        fi
        exit 0
    fi
    
    # 显示应用列表
    for app_info in "${apps[@]}"; do
        IFS=':' read -r type app_name app_dir <<< "$app_info"
        echo "$i. [$type] $app_name - $app_dir"
        ((i++))
    done
    
    echo "================================"
    echo "0. 退出"
    echo -n "请选择要卸载的应用编号: "
    read -r choice
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 0 ] || [ "$choice" -gt ${#apps[@]} ]; then
        echo "无效的选择"
        exit 1
    fi
    
    if [ "$choice" -eq 0 ]; then
        echo "已取消"
        exit 0
    fi
    
    # 获取选择的应用信息
    local selected_info="${apps[$((choice-1))]}"
    IFS=':' read -r type app_name app_dir <<< "$selected_info"
    
    echo ""
    echo "即将卸载: $app_name"
    echo "位置: $app_dir"
    echo "类型: $type"
    echo -n "确认卸载？(y/N): "
    read -r confirm
    
    if [[ "$confirm" != [yY] ]]; then
        echo "已取消卸载"
        exit 0
    fi
    
    # 执行卸载
    uninstall_app "$type" "$app_name" "$app_dir"
}

uninstall_app() {
    local type="$1"
    local app_name="$2"
    local app_dir="$3"
    
    echo "正在卸载 $app_name..."
    
    # 删除应用目录
    if [ "$type" = "USER" ]; then
        rm -rf "$app_dir"
        echo "已删除应用目录: $app_dir"
    else
        sudo rm -rf "$app_dir"
        echo "已删除应用目录: $app_dir"
    fi
    
    # 删除desktop文件
    if [ "$type" = "USER" ]; then
        local desktop_file="$HOME/.local/share/applications/$app_name.desktop"
        if [ -f "$desktop_file" ]; then
            rm -f "$desktop_file"
            echo "已删除desktop文件: $desktop_file"
            # 更新desktop数据库
            if command -v update-desktop-database >/dev/null 2>&1; then
                update-desktop-database "$HOME/.local/share/applications"
            fi
        fi
    else
        local desktop_file="/usr/share/applications/$app_name.desktop"
        if [ -f "$desktop_file" ]; then
            sudo rm -f "$desktop_file"
            echo "已删除desktop文件: $desktop_file"
            # 更新desktop数据库
            if command -v update-desktop-database >/dev/null 2>&1; then
                sudo update-desktop-database "/usr/share/applications"
            fi
        fi
    fi
    
    echo "$app_name 卸载完成！"
}

show_help() {
    echo "AppImage 安装和管理脚本"
    echo ""
    echo "安装用法:"
    echo "  $0 <AppImage文件> [--system] [--no-sandbox]"
    echo ""
    echo "卸载用法:"
    echo "  $0 --uninstall [过滤字符串]"
    echo ""
    echo "选项:"
    echo "  --system          安装到系统目录 (/opt/Applications)"
    echo "  --no-sandbox      在启动时添加--no-sandbox参数"
    echo "  --uninstall       进入卸载模式，显示已安装应用列表"
    echo "  --help, -h        显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  安装用户应用:      $0 app.AppImage"
    echo "  安装系统应用:      $0 app.AppImage --system"
    echo "  带沙盒禁用安装:    $0 app.AppImage --no-sandbox"
    echo "  列出所有应用卸载:  $0 --uninstall"
    echo "  卸载特定应用:      $0 --uninstall chrome"
}

# 检查参数数量决定模式
UNINSTALL_MODE=false
FILTER=""
SYSTEM_INSTALL=false
NO_SANDBOX=false
APPIMAGE_PATH=""

# 解析命令行参数
for arg in "$@"; do
    case "$arg" in
        --uninstall)
            UNINSTALL_MODE=true
            ;;
        --system)
            SYSTEM_INSTALL=true
            ;;
        --no-sandbox)
            NO_SANDBOX=true
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        -*)
            echo "错误: 未知选项 $arg"
            show_help
            exit 1
            ;;
        *)
            if [ -z "$APPIMAGE_PATH" ] && [ -f "$arg" ] && [[ "$arg" =~ \.AppImage$ ]]; then
                APPIMAGE_PATH="$arg"
            elif [ "$UNINSTALL_MODE" = true ]; then
                FILTER="$arg"
            else
                echo "错误: 未知参数 $arg"
                show_help
                exit 1
            fi
            ;;
    esac
done

# 确定运行模式
if [ "$UNINSTALL_MODE" = true ]; then
    # 卸载模式
    show_installed_apps "$FILTER"
    exit 0
elif [ -n "$APPIMAGE_PATH" ]; then
    # 安装模式
    install_mode=true
else
    echo "错误: 需要指定AppImage文件或使用--uninstall选项"
    show_help
    exit 1
fi

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

exit 0
