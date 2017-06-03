#!/usr/bin/env bash

# Run tests using SPM for macOS
swift test

# Run tests for tvOS
xcodebuild clean test -quiet -project Files.xcodeproj -scheme Files-tvOS -destination "platform=tvOS Simulator,name=Apple TV 1080p" CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO ONLY_ACTIVE_ARCH=NO
