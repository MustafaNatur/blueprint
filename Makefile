PREFIX ?= $(HOME)/.local
BINARY = .build/release/blueprint

.PHONY: build install uninstall test

build:
	swift build -c release

install: build
	install -d "$(PREFIX)/bin"
	install -m 755 "$(BINARY)" "$(PREFIX)/bin/blueprint"
	@echo "Installed $(PREFIX)/bin/blueprint"

uninstall:
	rm -f "$(PREFIX)/bin/blueprint"

test:
	swift test
