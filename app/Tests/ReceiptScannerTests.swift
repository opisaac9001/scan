import XCTest
import Vision
@testable import ReceiptScanner

class ReceiptScannerTests: XCTestCase {
    
    var ocrService: OCRService!
    var receiptParser: ReceiptParser!
    var coreDataManager: CoreDataManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        ocrService = OCRService()
        receiptParser = ReceiptParser()
        coreDataManager = CoreDataManager.shared
    }
    
    override func tearDownWithError() throws {
        ocrService = nil
        receiptParser = nil
        try super.tearDownWithError()
    }
    
    // MARK: - OCR Service Tests
    func testOCRServiceInitialization() {
        XCTAssertNotNil(ocrService, "OCRService should initialize successfully")
    }
    
    func testReceiptParserInitialization() {
        XCTAssertNotNil(receiptParser, "ReceiptParser should initialize successfully")
    }
    
    // MARK: - Receipt Parser Tests
    func testAmountExtraction() {
        let testTexts = [
            "Total: $25.99",
            "TOTAL $45.67",
            "Amount Due: 123.45",
            "Grand Total: $1,234.56"
        ]
        
        for text in testTexts {
            let amount = receiptParser.extractAmount(from: text)
            XCTAssertNotNil(amount, "Should extract amount from: \(text)")
            XCTAssertGreaterThan(amount ?? 0, 0, "Amount should be greater than 0")
        }
    }
    
    func testVendorExtraction() {
        let testTexts = [
            "WALMART SUPERCENTER\n123 Main St",
            "Target\nStore #1234",
            "STARBUCKS COFFEE\nLocation Details"
        ]
        
        for text in testTexts {
            let vendor = receiptParser.extractVendor(from: text)
            XCTAssertNotNil(vendor, "Should extract vendor from: \(text)")
            XCTAssertFalse(vendor?.isEmpty ?? true, "Vendor should not be empty")
        }
    }
    
    func testDateExtraction() {
        let testTexts = [
            "Date: 12/25/2023",
            "2023-12-25 14:30:00",
            "Dec 25, 2023"
        ]
        
        for text in testTexts {
            let date = receiptParser.extractDate(from: text)
            XCTAssertNotNil(date, "Should extract date from: \(text)")
        }
    }
    
    func testCategoryClassification() {
        let testVendors = [
            ("Starbucks", "Meals & Entertainment"),
            ("Shell", "Fuel & Vehicle"),
            ("Best Buy", "Equipment & Software"),
            ("Office Depot", "Office Supplies")
        ]
        
        for (vendor, expectedCategory) in testVendors {
            let category = receiptParser.classifyCategory(vendor: vendor, rawText: vendor)
            XCTAssertEqual(category, expectedCategory, "Should classify \(vendor) as \(expectedCategory)")
        }
    }
    
    // MARK: - Core Data Tests
    func testReceiptCreation() {
        let testReceipt = Receipt(
            vendor: "Test Vendor",
            amount: 25.99,
            date: Date(),
            category: "Test Category"
        )
        
        coreDataManager.saveReceipt(testReceipt) { result in
            switch result {
            case .success(let savedReceipt):
                XCTAssertEqual(savedReceipt.vendor, "Test Vendor")
                XCTAssertEqual(savedReceipt.amount, 25.99)
            case .failure(let error):
                XCTFail("Receipt save failed: \(error)")
            }
        }
    }
    
    // MARK: - Performance Tests
    func testOCRPerformance() {
        // Test OCR performance with a sample image
        guard let testImage = createTestReceiptImage() else {
            XCTFail("Could not create test image")
            return
        }
        
        measure {
            let expectation = self.expectation(description: "OCR Processing")
            
            ocrService.extractText(from: testImage) { result in
                switch result {
                case .success(_):
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("OCR failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Helper Methods
    private func createTestReceiptImage() -> UIImage? {
        // Create a simple test image with receipt-like text
        let size = CGSize(width: 400, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add some test text
            let text = """
            WALMART SUPERCENTER
            123 MAIN STREET
            ANYTOWN, ST 12345
            
            Date: 12/25/2023
            Time: 14:30:00
            
            Item 1          $10.99
            Item 2          $15.00
            
            Subtotal:       $25.99
            Tax:            $2.08
            Total:          $28.07
            
            Thank you!
            """
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle
            ]
            
            let rect = CGRect(x: 20, y: 50, width: 360, height: 500)
            text.draw(in: rect, withAttributes: attributes)
        }
    }
}

// MARK: - Integration Tests
class ReceiptScannerIntegrationTests: XCTestCase {
    
    func testFullScanningWorkflow() {
        guard let testImage = createTestReceiptImage() else {
            XCTFail("Could not create test image")
            return
        }
        
        let scanViewModel = ScanViewModel()
        let expectation = self.expectation(description: "Full scanning workflow")
        
        // Monitor the scan result
        scanViewModel.$scanResult
            .compactMap { $0 }
            .first()
            .sink { receipt in
                XCTAssertNotNil(receipt.vendor)
                XCTAssertNotNil(receipt.amount)
                XCTAssertNotNil(receipt.date)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Start the scanning process
        Task {
            await scanViewModel.processReceipt(image: testImage)
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func createTestReceiptImage() -> UIImage? {
        // Same implementation as in main test class
        let size = CGSize(width: 400, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            let text = "WALMART SUPERCENTER\nTotal: $28.07\nDate: 12/25/2023"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.black
            ]
            
            let rect = CGRect(x: 20, y: 200, width: 360, height: 200)
            text.draw(in: rect, withAttributes: attributes)
        }
    }
}

import Combine
