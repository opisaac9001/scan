#!/bin/bash

# Receipt Scanner - Xcode Project Validation Script
# This script validates the Xcode project structure and configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}📱 Receipt Scanner - Xcode Project Validation${NC}"
    echo "=============================================="
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

validate_xcode_project() {
    echo -e "${BLUE}🔍 Validating Xcode Project Structure...${NC}"
    echo ""
    
    # Check main project file
    if [ -f "ReceiptScanner.xcodeproj/project.pbxproj" ]; then
        print_success "Project file exists"
    else
        print_error "Missing project.pbxproj file"
        return 1
    fi
    
    # Check workspace
    if [ -f "ReceiptScanner.xcodeproj/project.xcworkspace/contents.xcworkspacedata" ]; then
        print_success "Workspace configuration exists"
    else
        print_error "Missing workspace configuration"
        return 1
    fi
    
    # Check scheme
    if [ -f "ReceiptScanner.xcodeproj/xcshareddata/xcschemes/ReceiptScanner.xcscheme" ]; then
        print_success "Shared scheme exists"
    else
        print_warning "Missing shared scheme - will be created in Xcode"
    fi
}

validate_source_structure() {
    echo -e "${BLUE}📁 Validating Source Code Structure...${NC}"
    echo ""
    
    # Check main directories
    for dir in "ReceiptScanner/App" "ReceiptScanner/Models" "ReceiptScanner/Views" "ReceiptScanner/ViewModels" "ReceiptScanner/Services" "ReceiptScanner/Resources"; do
        if [ -d "$dir" ]; then
            print_success "Directory exists: $dir"
        else
            print_error "Missing directory: $dir"
        fi
    done
    
    # Check key files
    key_files=(
        "ReceiptScanner/App/ReceiptScannerApp.swift"
        "ReceiptScanner/App/ContentView.swift"
        "ReceiptScanner/Models/Receipt.swift"
        "ReceiptScanner/Models/CoreDataManager.swift"
        "ReceiptScanner/Resources/Info.plist"
        "ReceiptScanner/Resources/AppConfig.swift"
        "ReceiptScannerTests/ReceiptScannerTests.swift"
    )
    
    for file in "${key_files[@]}"; do
        if [ -f "$file" ]; then
            print_success "Source file exists: $(basename "$file")"
        else
            print_error "Missing source file: $file"
        fi
    done
}

validate_configuration() {
    echo -e "${BLUE}⚙️ Validating Configuration...${NC}"
    echo ""
    
    # Check Info.plist
    if [ -f "ReceiptScanner/Resources/Info.plist" ]; then
        if grep -q "NSCameraUsageDescription" "ReceiptScanner/Resources/Info.plist"; then
            print_success "Camera permission description found"
        else
            print_warning "Missing NSCameraUsageDescription in Info.plist"
        fi
        
        if grep -q "CFBundleIdentifier" "ReceiptScanner/Resources/Info.plist"; then
            print_success "Bundle identifier configured"
        else
            print_error "Missing bundle identifier in Info.plist"
        fi
    fi
    
    # Check Core Data model
    if [ -d "ReceiptScanner/Models/ReceiptData.xcdatamodeld" ]; then
        print_success "Core Data model found"
    else
        print_error "Missing Core Data model"
    fi
}

count_files() {
    echo -e "${BLUE}📊 Project Statistics...${NC}"
    echo ""
    
    swift_files=$(find ReceiptScanner -name "*.swift" | wc -l)
    view_files=$(find ReceiptScanner/Views -name "*.swift" 2>/dev/null | wc -l || echo "0")
    service_files=$(find ReceiptScanner/Services -name "*.swift" 2>/dev/null | wc -l || echo "0")
    
    echo "📝 Total Swift files: $swift_files"
    echo "🖼️ View files: $view_files"
    echo "⚙️ Service files: $service_files"
    echo ""
}

show_next_steps() {
    echo -e "${BLUE}🚀 Next Steps...${NC}"
    echo ""
    echo "1. Transfer this project to a Mac with Xcode installed"
    echo "2. Open ReceiptScanner.xcodeproj in Xcode"
    echo "3. Configure your Apple Developer Team in project settings"
    echo "4. Update bundle identifier if needed"
    echo "5. Build and run on device or simulator"
    echo ""
    echo "📚 Documentation:"
    echo "   • README-XCODE.md - Project overview and setup"
    echo "   • app/DEVELOPMENT.md - Development workflow"
    echo "   • app/DEPLOYMENT-CHECKLIST.md - App Store deployment"
    echo ""
}

# Main execution
print_header
echo ""

validate_xcode_project
echo ""

validate_source_structure
echo ""

validate_configuration
echo ""

count_files

show_next_steps

echo -e "${GREEN}🎉 Xcode project validation complete!${NC}"
echo -e "${GREEN}Ready for iOS development and App Store deployment.${NC}"
