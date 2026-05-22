.PHONY: build build-release test bundle bundle-release run clean

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
	open build/WebWrap.app

clean:
	rm -rf .build build
