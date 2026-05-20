#!/bin/bash
set -e

echo "--- ПОЧАТОК ЗБИРАННЯ APP ТА DMG ---"

# Визначаємо шляхи
WORKSPACE_DIR="/Users/slava_prosto_shootit/.gemini/antigravity/scratch/file_sorter"
DOWNLOADS_DIR="/Users/slava_prosto_shootit/Downloads"
BUILD_DIR="$WORKSPACE_DIR/build"
APP_DIR="$BUILD_DIR/Smart File Sorter.app"
ICON_PNG="/Users/slava_prosto_shootit/.gemini/antigravity/brain/0786cbe5-49b7-47fb-8a0b-f5d420474e57/app_icon_1779222189541.png"

# Очищення
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 1. Компіляція у режимі Release
echo "[1/6] Компіляція релізу через Swift Package Manager..."
swift build -c release

# 2. Пошук зібраних артефактів
BINARY_PATH=$(find .build -name "SmartFileSorter" -type f | grep "/release/" | head -n 1)
SPARKLE_FRAMEWORK=$(find .build -name "Sparkle.framework" -type d | grep "macos-arm64" | head -n 1)

if [ -z "$BINARY_PATH" ]; then
    echo "Помилка: Не знайдено бінарний файл SmartFileSorter в релізі."
    exit 1
fi

if [ -z "$SPARKLE_FRAMEWORK" ]; then
    echo "Помилка: Не знайдено Sparkle.framework."
    exit 1
fi

echo "Знайдено бінарний файл: $BINARY_PATH"
echo "Знайдено Sparkle.framework: $SPARKLE_FRAMEWORK"

# 3. Створення структури App Bundle
echo "[2/6] Створення структури App Bundle..."
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
mkdir -p "$APP_DIR/Contents/Frameworks"

cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/SmartFileSorter"
cp -R "$SPARKLE_FRAMEWORK" "$APP_DIR/Contents/Frameworks/"
chmod +w "$APP_DIR/Contents/MacOS/SmartFileSorter"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_DIR/Contents/MacOS/SmartFileSorter"

# 4. Створення Info.plist
echo "[3/6] Створення Info.plist..."
cat <<EOF > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>uk</string>
    <key>CFBundleExecutable</key>
    <string>SmartFileSorter</string>
    <key>CFBundleIdentifier</key>
    <string>com.slavashootit.smart-file-sorter</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Smart File Sorter</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.4.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <string>0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/slavashootit/smart-file-sorter/main/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>z+t6x5990B01D2nS98jH8dKl2J0P8s7g5a4h3j2k1m0=</string>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMessage</key>
            <string>applySorterRuleService</string>
            <key>NSPortName</key>
            <string>SmartFileSorter</string>
            <key>NSSendTypes</key>
            <array>
                <string>NSFilenamesPboardType</string>
                <string>public.file-url</string>
            </array>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>Quick sort with Sorter</string>
                <key>uk</key>
                <string>Швидке сортування з Sorter</string>
            </dict>
        </dict>
    </array>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Smart File Sorter Rule</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Owner</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>com.slavashootit.smart-file-sorter.rule</string>
            </array>
        </dict>
    </array>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.json</string>
                <string>public.content</string>
            </array>
            <key>UTTypeDescription</key>
            <string>Smart File Sorter Rule</string>
            <key>UTTypeIdentifier</key>
            <string>com.slavashootit.smart-file-sorter.rule</string>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>sorterrule</string>
                </array>
            </dict>
        </dict>
    </array>
</dict>
</plist>
EOF

# Створення PkgInfo
echo "APPL????" > "$APP_DIR/Contents/PkgInfo"

# 5. Створення іконки .icns
echo "[4/6] Генерація файлу іконки AppIcon.icns..."
if [ -f "$ICON_PNG" ]; then
    mkdir -p "$BUILD_DIR/AppIcon.iconset"
    sips -s format png -z 16 16     "$ICON_PNG" --out "$BUILD_DIR/AppIcon.iconset/icon_16x16.png" > /dev/null 2>&1
    sips -s format png -z 32 32     "$ICON_PNG" --out "$BUILD_DIR/AppIcon.iconset/icon_16x16@2x.png" > /dev/null 2>&1
    sips -s format png -z 32 32     "$ICON_PNG" --out "$BUILD_DIR/AppIcon.iconset/icon_32x32.png" > /dev/null 2>&1
    sips -s format png -z 64 64     "$ICON_PNG" --out "$BUILD_DIR/AppIcon.iconset/icon_32x32@2x.png" > /dev/null 2>&1
    sips -s format png -z 128 128   "$ICON_PNG" --out "$BUILD_DIR/AppIcon.iconset/icon_128x128.png" > /dev/null 2>&1
    sips -s format png -z 256 256   "$ICON_PNG" --out "$BUILD_DIR/AppIcon.iconset/icon_128x128@2x.png" > /dev/null 2>&1
    sips -s format png -z 256 256   "$ICON_PNG" --out "$BUILD_DIR/AppIcon.iconset/icon_256x256.png" > /dev/null 2>&1
    sips -s format png -z 512 512   "$ICON_PNG" --out "$BUILD_DIR/AppIcon.iconset/icon_256x256@2x.png" > /dev/null 2>&1
    sips -s format png -z 512 512   "$ICON_PNG" --out "$BUILD_DIR/AppIcon.iconset/icon_512x512.png" > /dev/null 2>&1
    sips -s format png -z 1024 1024 "$ICON_PNG" --out "$BUILD_DIR/AppIcon.iconset/icon_512x512@2x.png" > /dev/null 2>&1
    
    iconutil -c icns "$BUILD_DIR/AppIcon.iconset" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
    rm -rf "$BUILD_DIR/AppIcon.iconset"
    echo "Іконку згенеровано успішно."
else
    echo "Помилка: Іконку $ICON_PNG не знайдено."
    exit 1
fi

# 5. Копіюємо ресурси локалізації
echo "[5/6] Копіювання ресурсів локалізації..."
cp -R "$WORKSPACE_DIR/Sources/SmartFileSorter/Resources/en.lproj" "$APP_DIR/Contents/Resources/"
cp -R "$WORKSPACE_DIR/Sources/SmartFileSorter/Resources/uk.lproj" "$APP_DIR/Contents/Resources/"

# 5.5. Локальне підписання коду
echo "[5.5/6] Локальне підписання коду (Ad-hoc Codesign)..."
codesign --force --deep --sign - "$APP_DIR"

# 6. Створення DMG
echo "[6/6] Пакування в DMG..."
DMG_TEMP_DIR="$BUILD_DIR/dmg_temp"
rm -rf "$DMG_TEMP_DIR"
mkdir -p "$DMG_TEMP_DIR"

# Переміщуємо .app у тимчасову папку для DMG
cp -R "$APP_DIR" "$DMG_TEMP_DIR/"

# Додаємо лінк на Applications для drag-and-drop встановлення
ln -s /Applications "$DMG_TEMP_DIR/Applications"

# Створюємо DMG файл у папку Downloads користувача
FINAL_DMG="$DOWNLOADS_DIR/SmartFileSorter.dmg"
rm -f "$FINAL_DMG"

hdiutil create -volname "Smart File Sorter" -srcfolder "$DMG_TEMP_DIR" -ov -format UDZO "$FINAL_DMG"

# Очищення тимчасових файлів
rm -rf "$DMG_TEMP_DIR"

echo "----------------------------------------------"
echo "УСПІШНО! Зібраний додаток та DMG готові."
echo "App Bundle: $APP_DIR"
echo "DMG збережено за шляхом: $FINAL_DMG"
echo "----------------------------------------------"
