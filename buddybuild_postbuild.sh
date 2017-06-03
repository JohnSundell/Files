#!/usr/bin/env bash

# Run tests using SPM for macOS
swift test

# Run tests for tvOS
xcodebuild clean test -project Files.xcodeproj -scheme Files-tvOS -destination "platform=tvOS Simulator,name=Apple TV 1080p" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO ONLY_ACTIVE_ARCH=NO

# Build for watchOS
xcodebuild clean build -project Files.xcodeproj -scheme Files-watchOS CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO ONLY_ACTIVE_ARCH=NO
