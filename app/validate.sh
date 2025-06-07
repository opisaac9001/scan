#!/bin/bash

# iOS Receipt Scanner - Project Validation Script
# This script validates the project structure and configuration

echo "🔍 Validating iOS Receipt Scanner Project..."
echo "============================================="

# Check if we're on macOS (required for Xcode development)
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "⚠️  Warning: This project requires macOS for iOS development"
    echo "   Please transfer to a Mac with Xcode installed"
    echo ""
fi

# Project structure validation
echo "📁 Checking project structure..."

required_dirs=(
    "App"
    "Models" 
    "Views"
    "ViewModels"
    "Services"
    "Resources"
    "Tests"
)

missing_dirs=()
for dir in "${required_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        missing_dirs+=("$dir")
    else
        echo "✅ $dir/"
    fi
done

if [ ${#missing_dirs[@]} -ne 0 ]; then
    echo "❌ Missing directories: ${missing_dirs[*]}"
    exit 1
fi

# Critical files validation  
echo ""
echo "📄 Checking critical files..."

critical_files=(
    "ReceiptScanner.xcodeproj/project.pbxproj"
    "App/ReceiptScannerApp.swift"
    "App/ContentView.swift"
    "Models/Receipt.swift"
    "Models/CoreDataManager.swift"
    "Models/ReceiptData.xcdatamodeld/contents"
    "Services/OCRService.swift"
    "Services/OllamaService.swift"
    "Resources/Info.plist"
    "Resources/AppConfig.swift"
)

missing_files=()
for file in "${critical_files[@]}"; do
    if [ ! -f "$file" ]; then
        missing_files+=("$file")
    else
        echo "✅ $file"
    fi
done

if [ ${#missing_files[@]} -ne 0 ]; then
    echo "❌ Missing critical files: ${missing_files[*]}"
    exit 1
fi

# Xcode project validation (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo ""
    echo "🔨 Validating Xcode project..."
    
    if command -v xcodebuild &> /dev/null; then
        # List project targets and schemes
        echo "📋 Available targets and schemes:"
        xcodebuild -project ReceiptScanner.xcodeproj -list
        
        echo ""
        echo "🏗️  Testing project build..."
        xcodebuild -project ReceiptScanner.xcodeproj -scheme ReceiptScanner -destination 'platform=iOS Simulator,name=iPhone 15' clean build CODE_SIGNING_ALLOWED=NO
        
        if [ $? -eq 0 ]; then
            echo "✅ Project builds successfully!"
        else
            echo "❌ Build failed - check Xcode configuration"
            exit 1
        fi
        
        echo ""
        echo "🧪 Running unit tests..."
        xcodebuild test -project ReceiptScanner.xcodeproj -scheme ReceiptScanner -destination 'platform=iOS Simulator,name=iPhone 15' CODE_SIGNING_ALLOWED=NO
        
        if [ $? -eq 0 ]; then
            echo "✅ All tests passed!"
        else
            echo "⚠️  Some tests failed - review test output"
        fi
    else
        echo "⚠️  xcodebuild not found - install Xcode Command Line Tools"
    fi
fi

# Configuration validation
echo ""
echo "⚙️  Checking configuration..."

# Check Info.plist
if [ -f "Resources/Info.plist" ]; then
    if grep -q "NSCameraUsageDescription" "Resources/Info.plist"; then
        echo "✅ Camera permission description found"
    else
        echo "⚠️  Missing NSCameraUsageDescription in Info.plist"
    fi
    
    if grep -q "CFBundleIdentifier" "Resources/Info.plist"; then
        echo "✅ Bundle identifier configured"
    else
        echo "❌ Missing bundle identifier in Info.plist"
    fi
fi

# Check AppConfig
if [ -f "Resources/AppConfig.swift" ]; then
    if grep -q "Ollama" "Resources/AppConfig.swift"; then
        echo "✅ Ollama configuration found"
    else
        echo "⚠️  Missing Ollama configuration"
    fi
    
    if grep -q "OCR" "Resources/AppConfig.swift"; then
        echo "✅ OCR configuration found"
    else
        echo "⚠️  Missing OCR configuration"
    fi
fi

# Final summary
echo ""
echo "📊 Validation Summary"
echo "===================="

total_files=$(find . -name "*.swift" -not -path "./Tests/*" | wc -l)
echo "📱 Swift source files: $total_files"

test_files=$(find Tests -name "*.swift" 2>/dev/null | wc -l || echo "0")
echo "🧪 Test files: $test_files"

if [ -d "Resources/Assets.xcassets" ]; then
    echo "🖼️  Assets: Available"
else
    echo "⚠️  Assets: Missing"
fi

echo ""
echo "🚀 Next Steps:"
echo "1. Transfer project to macOS with Xcode"
echo "2. Open ReceiptScanner.xcodeproj in Xcode"
echo "3. Configure signing & provisioning"
echo "4. Test on physical iOS device"
echo "5. Install Ollama for LLM features (optional)"
echo ""
echo "📖 See DEVELOPMENT.md for detailed setup guide"
echo "✨ Project validation complete!"
