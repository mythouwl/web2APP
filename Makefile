.PHONY: build build-release test bundle bundle-release run install patch-wrappers clean

build:
	swift build

build-release:
	swift build -c release -Xswiftc -O -Xswiftc -wmo

test:
	swift test

bundle: build
	./Scripts/bundle-webwrap.sh debug

bundle-release: build-release
	./Scripts/bundle-webwrap.sh release

run: bundle
	open "build/灵镜.app"

install: bundle-release
	ditto "build/灵镜.app" "$$HOME/Applications/灵镜.app"
	codesign --force --deep --sign - "$$HOME/Applications/灵镜.app"
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$$HOME/Applications/灵镜.app"
	killall Dock 2>/dev/null || true
	open "$$HOME/Applications/灵镜.app"

patch-wrappers: build-release
	@RUNTIME=".build/release/WebWrapRuntime"; \
	COUNT=0; \
	for app in $$HOME/Applications/*.app; do \
	  plist="$$app/Contents/Info.plist"; \
	  [ -f "$$plist" ] || continue; \
	  bid=$$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$$plist" 2>/dev/null); \
	  case "$$bid" in \
	    com.webwrap.generator) ;; \
	    com.webwrap.*) echo "Patching $$app"; \
	                   cp "$$RUNTIME" "$$app/Contents/MacOS/WebWrapRuntime"; \
	                   codesign --force --deep --sign - "$$app" 2>&1 | tail -1; \
	                   COUNT=$$((COUNT+1)) ;; \
	  esac; \
	done; \
	echo "Patched $$COUNT wrapper(s)."

clean:
	rm -rf .build build
