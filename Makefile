SHELL       := /bin/zsh
APP_NAME    := seeport
BUNDLE      := .build/$(APP_NAME).app
APP_DIR     := $(BUNDLE)/Contents
EXECUTABLE  := .build/arm64-apple-macosx/debug/$(APP_NAME)
SPARKLE_FW  := $(shell find .build -name "Sparkle.framework" -not -path "*/seeport.app/*" -print -quit 2>/dev/null)
SIGN_TOOL   := .build/artifacts/sparkle/Sparkle/bin/sign_update

.PHONY: build bundle run debug dev clean release deploy test-servers

# ── Build ──────────────────────────────────────────────

build:
	swift build 2>&1

bundle: build
	@rm -rf $(BUNDLE)
	@mkdir -p $(APP_DIR)/MacOS $(APP_DIR)/Resources $(APP_DIR)/Frameworks
	@cp $(EXECUTABLE) $(APP_DIR)/MacOS/$(APP_NAME)
	@cp Sources/$(APP_NAME)/Resources/Info.plist $(APP_DIR)/Info.plist
	@cp Sources/$(APP_NAME)/Resources/AppIcon.icns $(APP_DIR)/Resources/AppIcon.icns 2>/dev/null || true
	@if [ -n "$(SPARKLE_FW)" ]; then \
		cp -R $(SPARKLE_FW) $(APP_DIR)/Frameworks/; \
		echo "Sparkle.framework copied"; \
	else \
		echo "Warning: Sparkle.framework not found"; \
	fi
	@install_name_tool -add_rpath @executable_path/../Frameworks $(APP_DIR)/MacOS/$(APP_NAME) 2>/dev/null || true
	@codesign --force --deep --sign - $(BUNDLE)
	@xattr -dr com.apple.quarantine $(BUNDLE) 2>/dev/null || true
	@echo "App bundle: $(BUNDLE)"

# ── Run ────────────────────────────────────────────────

run: bundle
	@pkill -f "$(BUNDLE)" 2>/dev/null || true
	@open $(BUNDLE)

# ── Debug (run in foreground with stdout/stderr) ───────

debug: bundle
	@pkill -f "$(BUNDLE)" 2>/dev/null || true
	$(APP_DIR)/MacOS/$(APP_NAME)

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
	rm -rf $(BUNDLE) *.zip

# ── Release ────────────────────────────────────────────
# Usage: make release VERSION=0.2

VERSION ?= $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Sources/$(APP_NAME)/Resources/Info.plist)

release: bundle
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
