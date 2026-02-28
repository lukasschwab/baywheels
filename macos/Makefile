APP_NAME = Bay Wheels.app
BUNDLE_ID = com.lukasschwab.BayWheelsMenuBar
BUILD_DIR = .build
APP_DIR = $(APP_NAME)

.PHONY: build run clean bundle dist install uninstall

build:
	swift build -c release

# Bundle into a .app for proper Info.plist and entitlements.
bundle: build
	@rm -rf "$(APP_DIR)"
	@mkdir -p "$(APP_DIR)/Contents/MacOS"
	@mkdir -p "$(APP_DIR)/Contents/Resources"
	cp $(BUILD_DIR)/release/BayWheelsMenuBar "$(APP_DIR)/Contents/MacOS/BayWheelsMenuBar"
	cp Sources/BayWheelsMenuBar/Info.plist "$(APP_DIR)/Contents/Info.plist"
	@# Generate PkgInfo
	@echo -n "APPL????" > "$(APP_DIR)/Contents/PkgInfo"
	@echo "Built $(APP_DIR)"

# Sign with entitlements (ad-hoc for local development).
sign: bundle
	codesign --force --deep --sign - \
		--entitlements BayWheelsMenuBar.entitlements \
		"$(APP_DIR)"
	@echo "Signed $(APP_DIR)"

run: sign
	open "$(APP_DIR)"

install: sign
	@rm -rf "/Applications/$(APP_NAME)"
	cp -R "$(APP_DIR)" "/Applications/$(APP_NAME)"
	@echo "Installed to /Applications/$(APP_NAME)"

uninstall:
	@rm -rf "/Applications/$(APP_NAME)"
	@echo "Removed /Applications/$(APP_NAME)"

dist: sign
	@rm -f "Bay Wheels.zip"
	ditto -c -k --keepParent "$(APP_DIR)" "Bay Wheels.zip"
	@echo "Created Bay Wheels.zip ($$(du -h 'Bay Wheels.zip' | cut -f1))"

clean:
	swift package clean
	rm -rf "$(APP_DIR)" "Bay Wheels.zip"
