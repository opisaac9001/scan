#!/bin/bash

# Receipt Scanner iOS App - Build Script
# This script helps with common development tasks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project Configuration
PROJECT_NAME="ReceiptScanner"
SCHEME_NAME="ReceiptScanner"
WORKSPACE_PATH="."

# Functions
print_header() {
    echo -e "${BLUE}📱 Receipt Scanner iOS - $1${NC}"
    echo "=================================================="
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if we're on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script requires macOS to build iOS apps"
        exit 1
    fi
}

# Check if Xcode is installed
check_xcode() {
    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode is not installed or xcodebuild is not in PATH"
        exit 1
    fi
    print_success "Xcode found: $(xcodebuild -version | head -n1)"
}

# Clean project
clean_project() {
    print_header "Cleaning Project"
    xcodebuild clean -project "${PROJECT_NAME}.xcodeproj" -scheme "$SCHEME_NAME"
    print_success "Project cleaned"
}

# Build for simulator
build_simulator() {
    print_header "Building for iOS Simulator"
    xcodebuild build \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -destination 'platform=iOS Simulator,name=iPhone 15' \
        -configuration Debug
    print_success "Simulator build completed"
}

# Run tests
run_tests() {
    print_header "Running Tests"
    xcodebuild test \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -destination 'platform=iOS Simulator,name=iPhone 15'
    print_success "Tests completed"
}

# Archive for distribution
archive_project() {
    print_header "Archiving Project"
    ARCHIVE_PATH="./build/${PROJECT_NAME}.xcarchive"
    
    xcodebuild archive \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH"
    
    print_success "Archive created at: $ARCHIVE_PATH"
}

# Show project info
show_info() {
    print_header "Project Information"
    echo "📱 Project: $PROJECT_NAME"
    echo "🎯 Scheme: $SCHEME_NAME"
    echo "📍 Path: $(pwd)"
    echo "📋 iOS Deployment Target: 15.0+"
    echo "⚙️ Swift Version: 5.9+"
    echo "🏗 Architecture: MVVM"
    echo ""
    echo "🔧 Key Features:"
    echo "  • Camera-based receipt scanning"
    echo "  • iOS Vision Framework OCR"
    echo "  • Ollama LLM integration"
    echo "  • Core Data persistence"
    echo "  • SwiftUI interface"
    echo "  • Tax categorization"
    echo "  • Export capabilities"
    echo ""
    
    if [ -f "${PROJECT_NAME}.xcodeproj/project.pbxproj" ]; then
        print_success "Xcode project file found"
    else
        print_error "Xcode project file not found"
    fi
}

# Setup development environment
setup_dev() {
    print_header "Setting Up Development Environment"
    
    # Create build directory
    mkdir -p build
    print_success "Build directory created"
    
    # Check for required files
    if [ ! -f "Resources/Info.plist" ]; then
        print_warning "Info.plist not found in Resources/"
    fi
    
    if [ ! -f "Resources/Assets.xcassets/AppIcon.appiconset/Contents.json" ]; then
        print_warning "App icons not configured"
    fi
    
    print_success "Development environment ready"
}

# Show usage
show_usage() {
    echo "Receipt Scanner iOS Build Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  info     - Show project information"
    echo "  setup    - Setup development environment"
    echo "  clean    - Clean project"
    echo "  build    - Build for simulator"
    echo "  test     - Run unit tests"
    echo "  archive  - Create release archive"
    echo "  all      - Run clean, build, and test"
    echo ""
    echo "Examples:"
    echo "  $0 info"
    echo "  $0 build"
    echo "  $0 test"
}

# Main execution
main() {
    case "$1" in
        "info")
            show_info
            ;;
        "setup")
            check_macos
            check_xcode
            setup_dev
            ;;
        "clean")
            check_macos
            check_xcode
            clean_project
            ;;
        "build")
            check_macos
            check_xcode
            build_simulator
            ;;
        "test")
            check_macos
            check_xcode
            run_tests
            ;;
        "archive")
            check_macos
            check_xcode
            archive_project
            ;;
        "all")
            check_macos
            check_xcode
            clean_project
            build_simulator
            run_tests
            ;;
        *)
            show_usage
            ;;
    esac
}

# Run main function with all arguments
main "$@"
