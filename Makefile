SHELL       := /bin/zsh
APP_NAME    := Seeport
DEV_APP_NAME := Seeport Dev
TARGET_NAME := seeport
SOURCE_DIR  := Sources/seeport
DEV_BUNDLE  := .build/$(DEV_APP_NAME).app
REL_BUNDLE  := .build/$(APP_NAME).app
EXECUTABLE  := .build/arm64-apple-macosx/debug/$(TARGET_NAME)
SPARKLE_FW  := $(shell find .build -name "Sparkle.framework" -not -path "*/.app/*" -print -quit 2>/dev/null)
SIGN_TOOL   := .build/artifacts/sparkle/Sparkle/bin/sign_update

.PHONY: build bundle run debug dev clean release deploy ship test-servers

# ── Build ──────────────────────────────────────────────

build:
	swift build 2>&1

bundle: build
	@rm -rf "$(DEV_BUNDLE)"
	@mkdir -p "$(DEV_BUNDLE)/Contents/MacOS" "$(DEV_BUNDLE)/Contents/Resources" "$(DEV_BUNDLE)/Contents/Frameworks"
	@cp $(EXECUTABLE) "$(DEV_BUNDLE)/Contents/MacOS/$(DEV_APP_NAME)"
	@cp $(SOURCE_DIR)/Resources/Info.dev.plist "$(DEV_BUNDLE)/Contents/Info.plist"
	@cp $(SOURCE_DIR)/Resources/AppIcon.icns "$(DEV_BUNDLE)/Contents/Resources/AppIcon.icns" 2>/dev/null || true
	@if [ -n "$(SPARKLE_FW)" ]; then \
		cp -R "$(SPARKLE_FW)" "$(DEV_BUNDLE)/Contents/Frameworks/"; \
		echo "Sparkle.framework copied"; \
	else \
		echo "Warning: Sparkle.framework not found"; \
	fi
	@install_name_tool -add_rpath @executable_path/../Frameworks "$(DEV_BUNDLE)/Contents/MacOS/$(DEV_APP_NAME)" 2>/dev/null || true
	@codesign --force --deep --sign - "$(DEV_BUNDLE)"
	@xattr -dr com.apple.quarantine "$(DEV_BUNDLE)" 2>/dev/null || true
	@echo "App bundle: $(DEV_BUNDLE)"

# ── Run ────────────────────────────────────────────────

run: bundle
	@pkill -f "$(DEV_BUNDLE)" 2>/dev/null || true
	@open "$(DEV_BUNDLE)"

# ── Debug (run in foreground with stdout/stderr) ───────

debug: bundle
	@pkill -f "$(DEV_BUNDLE)" 2>/dev/null || true
	"$(DEV_BUNDLE)/Contents/MacOS/$(DEV_APP_NAME)"

# ── Dev (watch & auto-rebuild) ─────────────────────────

dev: run
	@echo "Watching for changes... (Ctrl+C to stop)"
	@fswatch -o -e ".*" -i "\\.swift$$" Sources/ | while read _; do \
		echo "\n\033[1;33m[dev]\033[0m Rebuilding..."; \
		$(MAKE) run; \
	done

# ── Clean ──────────────────────────────────────────────

clean:
	swift package clean
	rm -rf "$(DEV_BUNDLE)" "$(REL_BUNDLE)" *.zip

# ── Release ────────────────────────────────────────────
# Usage: make release VERSION=0.2

VERSION ?= $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" $(SOURCE_DIR)/Resources/Info.plist)

bump-version:
	@/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" $(SOURCE_DIR)/Resources/Info.plist
	@/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(VERSION)" $(SOURCE_DIR)/Resources/Info.plist
	@/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" $(SOURCE_DIR)/Resources/Info.dev.plist
	@/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(VERSION)" $(SOURCE_DIR)/Resources/Info.dev.plist
	@echo "Version bumped to $(VERSION)"

release-bundle: bump-version build
	@rm -rf "$(REL_BUNDLE)"
	@mkdir -p "$(REL_BUNDLE)/Contents/MacOS" "$(REL_BUNDLE)/Contents/Resources" "$(REL_BUNDLE)/Contents/Frameworks"
	@cp $(EXECUTABLE) "$(REL_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@cp $(SOURCE_DIR)/Resources/Info.plist "$(REL_BUNDLE)/Contents/Info.plist"
	@cp $(SOURCE_DIR)/Resources/AppIcon.icns "$(REL_BUNDLE)/Contents/Resources/AppIcon.icns" 2>/dev/null || true
	@if [ -n "$(SPARKLE_FW)" ]; then \
		cp -R "$(SPARKLE_FW)" "$(REL_BUNDLE)/Contents/Frameworks/"; \
		echo "Sparkle.framework copied"; \
	else \
		echo "Warning: Sparkle.framework not found"; \
	fi
	@install_name_tool -add_rpath @executable_path/../Frameworks "$(REL_BUNDLE)/Contents/MacOS/$(APP_NAME)" 2>/dev/null || true
	@codesign --force --deep --sign - "$(REL_BUNDLE)"
	@xattr -dr com.apple.quarantine "$(REL_BUNDLE)" 2>/dev/null || true
	@echo "App bundle: $(REL_BUNDLE)"

release: release-bundle
	@rm -f $(APP_NAME)-v$(VERSION).zip
	@cd .build && zip -r ../$(APP_NAME)-v$(VERSION).zip $(APP_NAME).app -q
	@echo "Created $(APP_NAME)-v$(VERSION).zip"
	@$(SIGN_TOOL) $(APP_NAME)-v$(VERSION).zip
	@echo "\nUpdate appcast.xml with the signature and length above."

# ── Deploy ─────────────────────────────────────────────
# Usage: make deploy VERSION=0.2

deploy: release
	gh release create v$(VERSION) $(APP_NAME)-v$(VERSION).zip \
		--title "Seeport v$(VERSION)" \
		--generate-notes
	@echo "\nRelease v$(VERSION) published."
	@echo "Remember to update gh-pages branch appcast.xml with new entry."

# ── Ship (one-command deploy) ─────────────────────────
# Usage: make ship              (auto-increment version)
#        make ship VERSION=2.0  (specific version)

ship:
	@./scripts/ship.sh

# ── Test Servers (sample HTTP servers for port testing) ─

test-servers:
	@echo "Starting Python test servers..."
	@python3 -m http.server 8080 &>/dev/null & \
	 echo "  Server 1: http://localhost:8080 (PID: $$!)"; \
	 python3 -m http.server 13000 &>/dev/null & \
	 echo "  Server 2: http://localhost:13000 (PID: $$!)"; \
	 python3 -m http.server 9999 &>/dev/null & \
	 echo "  Server 3: http://localhost:9999 (PID: $$!)"; \
	 echo "\nAll servers running. Run 'make test-servers-stop' to stop."

test-servers-stop:
	@for port in 8080 13000 9999; do \
		pid=$$(lsof -ti TCP:$$port -sTCP:LISTEN 2>/dev/null); \
		[ -n "$$pid" ] && kill $$pid 2>/dev/null && echo "  Stopped port $$port (PID: $$pid)" || true; \
	done
	@echo "All test servers stopped."
