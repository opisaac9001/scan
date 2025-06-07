import Foundation
import CoreData
import UIKit

class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()

    lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ReceiptData")

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()

    private init() {}

    func save() {
        let context = container.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save Core Data context: \(error)")
            }
        }
    }

    func createReceipt(from receipt: Receipt) -> ReceiptEntity? {
        let context = container.viewContext
        let entity = ReceiptEntity(context: context)

        entity.id = receipt.id
        entity.imageData = receipt.imageData
        entity.vendor = receipt.vendor
        entity.amount = receipt.amount ?? 0.0
        entity.date = receipt.date
        entity.category = receipt.category
        entity.notes = receipt.notes
        entity.rawText = receipt.rawText
        entity.confidence = receipt.confidence ?? 0.0
        entity.paymentMethod = receipt.paymentMethod
        entity.location = receipt.location
        entity.tags = receipt.tags.joined(separator: ",")
        entity.needsReview = receipt.needsReview
        entity.createdAt = receipt.createdAt
        entity.updatedAt = receipt.updatedAt

        // Enhanced fields from Receipt struct
        entity.taxCategory = receipt.taxCategory
        entity.businessPurpose = receipt.businessPurpose
        entity.subtotal = receipt.subtotal ?? 0.0
        entity.taxAmount = receipt.taxAmount ?? 0.0
        entity.tipAmount = receipt.tipAmount ?? 0.0
        entity.taxRate = receipt.taxRate ?? 0.0
        entity.transactionId = receipt.transactionId
        entity.vendorTaxId = receipt.vendorTaxId
        entity.mileage = receipt.mileage
        entity.vehicleInfo = receipt.vehicleInfo
        entity.receiptType = receipt.receiptType
        entity.rawOCRText = receipt.rawOCRText // Corresponds to Receipt.rawOCRText
        entity.confidenceScore = receipt.confidenceScore ?? 0.0 // Corresponds to Receipt.confidenceScore

        save()
        return entity
    }

    func fetchReceipts() -> [Receipt] {
        let context = container.viewContext
        let request: NSFetchRequest<ReceiptEntity> = ReceiptEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ReceiptEntity.createdAt, ascending: false)]

        do {
            let entities = try context.fetch(request)
            return entities.map { entity in
                Receipt(
                    id: entity.id ?? UUID(),
                    imageData: entity.imageData,
                    vendor: entity.vendor,
                    amount: entity.amount == 0.0 ? nil : entity.amount,
                    date: entity.date,
                    category: entity.category,
                    notes: entity.notes,
                    rawText: entity.rawText,
                    confidence: entity.confidence == 0.0 ? nil : entity.confidence,
                    paymentMethod: entity.paymentMethod,
                    location: entity.location,
                    tags: entity.tags?.components(separatedBy: ",").filter { !$0.isEmpty } ?? [],
                    needsReview: entity.needsReview,
                    createdAt: entity.createdAt ?? Date(),
                    updatedAt: entity.updatedAt ?? Date(),
                    // Map enhanced fields from Entity to Struct
                    taxCategory: entity.taxCategory,
                    businessPurpose: entity.businessPurpose,
                    subtotal: entity.subtotal == 0.0 ? nil : entity.subtotal,
                    taxAmount: entity.taxAmount == 0.0 ? nil : entity.taxAmount,
                    tipAmount: entity.tipAmount == 0.0 ? nil : entity.tipAmount,
                    taxRate: entity.taxRate == 0.0 ? nil : entity.taxRate,
                    transactionId: entity.transactionId,
                    vendorTaxId: entity.vendorTaxId,
                    mileage: entity.mileage,
                    vehicleInfo: entity.vehicleInfo,
                    receiptType: entity.receiptType,
                    rawOCRText: entity.rawOCRText,
                    confidenceScore: entity.confidenceScore == 0.0 ? nil : entity.confidenceScore
                )
            }
        } catch {
            print("Failed to fetch receipts: \(error)")
            return []
        }
    }

    func deleteReceipt(withId id: UUID) {
        let context = container.viewContext
        let request: NSFetchRequest<ReceiptEntity> = ReceiptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let entities = try context.fetch(request)
            entities.forEach { context.delete($0) }
            save()
        } catch {
            print("Failed to delete receipt: \(error)")
        }
    }

    func updateReceipt(_ receipt: Receipt) {
        let context = container.viewContext
        let request: NSFetchRequest<ReceiptEntity> = ReceiptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", receipt.id as CVarArg)

        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                entity.vendor = receipt.vendor
                entity.amount = receipt.amount ?? 0.0
                entity.date = receipt.date
                entity.category = receipt.category
                entity.notes = receipt.notes
                entity.paymentMethod = receipt.paymentMethod
                entity.location = receipt.location
                entity.tags = receipt.tags.joined(separator: ",")
                entity.needsReview = receipt.needsReview
                // Note: imageData, rawText, confidence, and createdAt are not updated here.

                // Update enhanced fields
                entity.taxCategory = receipt.taxCategory
                entity.businessPurpose = receipt.businessPurpose
                entity.subtotal = receipt.subtotal ?? 0.0
                entity.taxAmount = receipt.taxAmount ?? 0.0
                entity.tipAmount = receipt.tipAmount ?? 0.0
                entity.taxRate = receipt.taxRate ?? 0.0
                entity.transactionId = receipt.transactionId
                entity.vendorTaxId = receipt.vendorTaxId
                entity.mileage = receipt.mileage
                entity.vehicleInfo = receipt.vehicleInfo
                entity.receiptType = receipt.receiptType
                entity.rawOCRText = receipt.rawOCRText // Corresponds to Receipt.rawOCRText
                entity.confidenceScore = receipt.confidenceScore ?? 0.0 // Corresponds to Receipt.confidenceScore

                entity.updatedAt = Date()

                save()
            }
        } catch {
            print("Failed to update receipt: \(error)")
        }
    }

    func clearAllReceipts(completion: @escaping (Result<Void, Error>) -> Void) {
        let context = container.viewContext
        let request: NSFetchRequest<NSFetchRequestResult> = ReceiptEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        do {
            try context.execute(deleteRequest)
            save()
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
}
