.PHONY: build app run test lint format check icons ci-test

CONFIGURATION ?= debug

build:
	swift build

icons: Support/AppIcon.icns

Support/AppIcon.icns: scripts/GenerateIcons.swift Sources/MiniUI/PixelSymbol.swift
	mkdir -p .build/tools
	swiftc Sources/MiniUI/PixelSymbol.swift scripts/GenerateIcons.swift -o .build/tools/generate-icons
	.build/tools/generate-icons
	iconutil --convert icns .build/AppIcon.iconset --output Support/AppIcon.icns

app:
	bash scripts/build-app.sh "$(CONFIGURATION)"

run: app
	open "dist/Hello Mini.app"

test:
	swift test

lint:
	swift format lint --strict --recursive Package.swift Sources Tests scripts

format:
	swift format format --in-place --recursive Package.swift Sources Tests scripts

ci-test:
	python3 scripts/test-ci.py

check: lint test ci-test build
