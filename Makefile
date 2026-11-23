CC = clang
MIN_MACOS = 11.0
CFLAGS = -O3 -fobjc-arc -Wall -Wno-deprecated-declarations -mmacosx-version-min=$(MIN_MACOS)
FRAMEWORKS = -framework Cocoa -framework WebKit -framework IOKit -lproc
SOURCES = src/main.m src/AppDelegate.m src/SystemMonitor.m

APP_NAME = Statix
BUILD_DIR = build
DIST_DIR = dist
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app

.PHONY: all clean run icons dist install help

all: dist

icons:
	@mkdir -p assets
	$(CC) -O2 -framework Cocoa tools/generate_icons.m -o tools/gen_icons
	./tools/gen_icons assets
	python3 tools/pack_icns.py assets assets/AppIcon.icns

app: icons
	@mkdir -p $(BUILD_DIR) $(APP_BUNDLE)/Contents/MacOS $(APP_BUNDLE)/Contents/Resources/web
	@echo "==> Compiling arm64..."
	$(CC) $(CFLAGS) -target arm64-apple-macos$(MIN_MACOS) $(FRAMEWORKS) $(SOURCES) -o $(BUILD_DIR)/$(APP_NAME)_arm64
	@echo "==> Compiling x86_64..."
	$(CC) $(CFLAGS) -target x86_64-apple-macos$(MIN_MACOS) $(FRAMEWORKS) $(SOURCES) -o $(BUILD_DIR)/$(APP_NAME)_x86_64
	@echo "==> Merging Universal Binary..."
	lipo -create -output $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME) $(BUILD_DIR)/$(APP_NAME)_arm64 $(BUILD_DIR)/$(APP_NAME)_x86_64
	@chmod +x $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	@echo "==> Copying resources..."
	cp src/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	cp assets/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	cp assets/menubar_icon.png $(APP_BUNDLE)/Contents/Resources/menubar_icon.png
	cp assets/menubar_icon@2x.png $(APP_BUNDLE)/Contents/Resources/menubar_icon@2x.png
	cp -r src/web/* $(APP_BUNDLE)/Contents/Resources/web/
	@echo "==> Codesigning bundle..."
	codesign -s - --force --deep $(APP_BUNDLE)

dist: app
	@mkdir -p $(DIST_DIR)
	@rm -rf $(DIST_DIR)/$(APP_NAME).app
	cp -R $(APP_BUNDLE) $(DIST_DIR)/$(APP_NAME).app
	cd $(DIST_DIR) && rm -f $(APP_NAME)-Universal.zip && zip -r -q $(APP_NAME)-Universal.zip $(APP_NAME).app
	@echo "==> Distribution package ready at $(DIST_DIR)/$(APP_NAME).app"

run: app
	@echo "==> Launching $(APP_NAME)..."
	open $(APP_BUNDLE)

install: dist
	@echo "==> Installing to /Applications/$(APP_NAME).app..."
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(DIST_DIR)/$(APP_NAME).app /Applications/
	@echo "==> Installed successfully to /Applications/$(APP_NAME).app"

clean:
	rm -rf $(BUILD_DIR) $(DIST_DIR) tools/gen_icons

help:
	@echo "Statix Build System:"
	@echo "  make dist     - Build Universal macOS app bundle and zip"
	@echo "  make run      - Build and run Statix"
	@echo "  make install  - Install Statix to /Applications"
	@echo "  make clean    - Remove build artifacts"
