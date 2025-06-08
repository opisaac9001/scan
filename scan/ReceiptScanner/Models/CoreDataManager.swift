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
                // Consider more robust error handling or logging for production
                print("Failed to save Core Data context: \(error.localizedDescription)")
                // Optionally, rethrow or handle specific errors
                // For example, if validation errors occur:
                if let detailedErrors = (error as NSError).userInfo[NSDetailedErrorsKey] as? [Error] {
                    for detailedError in detailedErrors {
                        print("Detailed error: \((detailedError as NSError).localizedDescription)")
                    }
                } else {
                    print("Error details: \((error as NSError).userInfo)")
                }
            }
        }
    }

    // Helper to encode Codable structs to Data
    private func encode<T: Codable>(_ value: T?) -> Data? {
        guard let value = value else { return nil }
        let encoder = JSONEncoder()
        do {
            return try encoder.encode(value)
        } catch {
            print("Failed to encode \(T.self): \(error.localizedDescription)")
            return nil
        }
    }

    // Helper to decode Data to Codable structs
    private func decode<T: Codable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data = data else { return nil }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(type, from: data)
        } catch {
            print("Failed to decode \(T.self): \(error.localizedDescription)")
            return nil
        }
    }

    func createReceipt(from receipt: Receipt) -> ReceiptEntity? {
        let context = container.viewContext
        let entity = ReceiptEntity(context: context)

        // Direct attributes from Receipt to ReceiptEntity
        entity.id = receipt.id
        entity.imageData = receipt.imageData
        entity.rawOCRText = receipt.rawOCRText // Assuming this is the original full OCR text
        entity.confidenceScore = receipt.confidenceScore ?? 0.0
        entity.needsReview = receipt.needsReview
        entity.createdAt = receipt.createdAt
        entity.updatedAt = receipt.updatedAt
        entity.receiptType = receipt.receiptType

        // Serialize complex structs into Data
        // IMPORTANT: Assumes ReceiptEntity has corresponding 'Data?' attributes:
        // vendorInfoData, transactionInfoData, itemsData, totalsData, notesData
        entity.setValue(encode(receipt.vendorInfo), forKey: "vendorInfoData")
        entity.setValue(encode(receipt.transactionInfo), forKey: "transactionInfoData")
        entity.setValue(encode(receipt.items), forKey: "itemsData")
        entity.setValue(encode(receipt.totals), forKey: "totalsData")
        entity.setValue(encode(receipt.notes), forKey: "notesData")

        // Old direct fields that are now part of nested structs are no longer set here.
        // e.g., entity.vendor, entity.amount, entity.date, etc.
        // These would be removed from ReceiptEntity's attributes in the Core Data model.

        save()
        return entity
    }

    func fetchReceipts() -> [Receipt] {
        let context = container.viewContext
        let request: NSFetchRequest<ReceiptEntity> = ReceiptEntity.fetchRequest()
        // Consider sorting by a more relevant field like transaction date if available and parsed
        // For now, using createdAt for consistency with previous version.
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ReceiptEntity.createdAt, ascending: false)]

        do {
            let entities = try context.fetch(request)
            return entities.compactMap { entity -> Receipt? in
                // Deserialize complex structs from Data
                // IMPORTANT: Assumes ReceiptEntity has corresponding 'Data?' attributes
                let vendorInfo: Receipt.VendorInfo? = decode(Receipt.VendorInfo.self, from: entity.value(forKey: "vendorInfoData") as? Data)
                let transactionInfo: Receipt.TransactionInfo? = decode(Receipt.TransactionInfo.self, from: entity.value(forKey: "transactionInfoData") as? Data)
                let items: [Receipt.LineItem]? = decode([Receipt.LineItem].self, from: entity.value(forKey: "itemsData") as? Data)
                let totals: Receipt.Totals? = decode(Receipt.Totals.self, from: entity.value(forKey: "totalsData") as? Data)
                let notes: Receipt.Notes? = decode(Receipt.Notes.self, from: entity.value(forKey: "notesData") as? Data)

                // Map direct attributes
                return Receipt(
                    id: entity.id ?? UUID(),
                    imageData: entity.imageData,
                    rawOCRText: entity.rawOCRText,
                    confidenceScore: entity.confidenceScore, // Already a Double in entity
                    needsReview: entity.needsReview,
                    createdAt: entity.createdAt ?? Date(),
                    updatedAt: entity.updatedAt ?? Date(),
                    receiptType: entity.receiptType,
                    vendorInfo: vendorInfo,
                    transactionInfo: transactionInfo,
                    items: items,
                    totals: totals,
                    notes: notes
                )
            }
        } catch {
            print("Failed to fetch receipts: \(error.localizedDescription)")
            return []
        }
    }

    func deleteReceipt(withId id: UUID) {
        let context = container.viewContext
        let request: NSFetchRequest<ReceiptEntity> = ReceiptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            if let entityToDelete = try context.fetch(request).first {
                context.delete(entityToDelete)
                save()
            }
        } catch {
            print("Failed to delete receipt with id \(id): \(error.localizedDescription)")
        }
    }

    func updateReceipt(_ receipt: Receipt) {
        let context = container.viewContext
        let request: NSFetchRequest<ReceiptEntity> = ReceiptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", receipt.id as CVarArg)

        do {
            if let entity = try context.fetch(request).first {
                // Update direct attributes
                entity.imageData = receipt.imageData // Allow image update
                entity.rawOCRText = receipt.rawOCRText
                entity.confidenceScore = receipt.confidenceScore ?? 0.0
                entity.needsReview = receipt.needsReview
                entity.receiptType = receipt.receiptType
                entity.updatedAt = Date() // Always update this

                // Serialize and update complex structs
                // IMPORTANT: Assumes ReceiptEntity has corresponding 'Data?' attributes
                entity.setValue(encode(receipt.vendorInfo), forKey: "vendorInfoData")
                entity.setValue(encode(receipt.transactionInfo), forKey: "transactionInfoData")
                entity.setValue(encode(receipt.items), forKey: "itemsData")
                entity.setValue(encode(receipt.totals), forKey: "totalsData")
                entity.setValue(encode(receipt.notes), forKey: "notesData")

                // entity.createdAt should not change on update.

                save()
            } else {
                print("Receipt with ID \(receipt.id) not found for update.")
                // Optionally, create it if not found, or handle as an error
                // _ = createReceipt(from: receipt)
            }
        } catch {
            print("Failed to update receipt with ID \(receipt.id): \(error.localizedDescription)")
        }
    }

    func clearAllReceipts(completion: @escaping (Result<Void, Error>) -> Void) {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = ReceiptEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        // For older iOS versions or if specific lifecycle methods on NSManagedObject are needed,
        // fetch and delete individually:
        // do {
        //     let receipts = try context.fetch(fetchRequest) as? [NSManagedObject]
        //     receipts?.forEach(context.delete)
        //     saveContext()
        //     completion(.success(()))
        // } catch let error as NSError {
        //     completion(.failure(error))
        // }

        do {
            try context.execute(deleteRequest)
            // NSBatchDeleteRequest does not automatically update the viewContext,
            // so if UI is bound directly to context, it might need manual refresh/reset.
            // However, our fetchReceipts will get the fresh state.
            save() // Save changes if any (though batch delete might bypass context's hasChanges)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }

    // Example of a more specific fetch, if needed
    func fetchReceipt(withId id: UUID) -> Receipt? {
        let context = container.viewContext
        let request: NSFetchRequest<ReceiptEntity> = ReceiptEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            if let entity = try context.fetch(request).first {
                let vendorInfo: Receipt.VendorInfo? = decode(Receipt.VendorInfo.self, from: entity.value(forKey: "vendorInfoData") as? Data)
                let transactionInfo: Receipt.TransactionInfo? = decode(Receipt.TransactionInfo.self, from: entity.value(forKey: "transactionInfoData") as? Data)
                let items: [Receipt.LineItem]? = decode([Receipt.LineItem].self, from: entity.value(forKey: "itemsData") as? Data)
                let totals: Receipt.Totals? = decode(Receipt.Totals.self, from: entity.value(forKey: "totalsData") as? Data)
                let notes: Receipt.Notes? = decode(Receipt.Notes.self, from: entity.value(forKey: "notesData") as? Data)

                return Receipt(
                    id: entity.id ?? UUID(),
                    imageData: entity.imageData,
                    rawOCRText: entity.rawOCRText,
                    confidenceScore: entity.confidenceScore,
                    needsReview: entity.needsReview,
                    createdAt: entity.createdAt ?? Date(),
                    updatedAt: entity.updatedAt ?? Date(),
                    receiptType: entity.receiptType,
                    vendorInfo: vendorInfo,
                    transactionInfo: transactionInfo,
                    items: items,
                    totals: totals,
                    notes: notes
                )
            }
            return nil
        } catch {
            print("Failed to fetch receipt with ID \(id): \(error.localizedDescription)")
            return nil
        }
    }
}
