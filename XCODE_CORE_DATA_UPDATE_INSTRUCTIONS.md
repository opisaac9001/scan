# Xcode Core Data Model Update Instructions (`ReceiptEntity`)

These are detailed steps to update the `ReceiptEntity` within your `ReceiptData.xcdatamodeld` file in Xcode. This is necessary to align the Core Data schema with the new `Receipt` Swift struct that now uses nested objects for more detailed information.

**IMPORTANT PRELIMINARY NOTES:**
*   **Backup Your Project:** Before making significant changes to your Core Data model, it's always a good idea to commit your current work or create a backup of your project.
*   **Xcode Version:** These instructions assume a relatively modern version of Xcode (e.g., Xcode 13, 14, 15). Minor UI details might vary slightly between versions, but the core concepts remain the same.
*   **Codegen Setting for `ReceiptEntity`:** Before you start, select `ReceiptData.xcdatamodeld`, then select `ReceiptEntity`. In the Data Model Inspector (right-hand sidebar), under "Entity", check the "Codegen" setting.
    *   If it's "Manual/None" or "Category/Extension", these steps are fine. You will explicitly regenerate files in Step 7.
    *   If it's "Class Definition" (and Xcode is auto-generating a hidden file), you might need to switch it to "Manual/None" or "Category/Extension" to have more control, then proceed with these steps including Step 7. For this guide, we'll assume you'll use Step 7 to generate the files.

---

**Steps:**

1.  **Open Your Project in Xcode:**
    *   Navigate to your project folder in Finder.
    *   Open the `.xcodeproj` or `.xcworkspace` file to launch your project in Xcode.

2.  **Locate the Core Data Model File:**
    *   In the **Project Navigator** (the left-hand sidebar that lists all your project files and folders), find and click on the file named `ReceiptData.xcdatamodeld`.
    *   This action will open the Core Data model editor interface in the main Xcode window.

3.  **Select the `ReceiptEntity`:**
    *   Within the Core Data model editor, you will see a section typically labeled "ENTITIES" (usually on the left side of the main editor pane). Click on `ReceiptEntity` from this list.
    *   Once `ReceiptEntity` is selected, its details (Attributes, Relationships, etc.) will be displayed, often in the **Data Model Inspector** on the right-hand side of Xcode. If this inspector is not visible, you can open it by going to the Xcode menu: View > Inspectors > Show Data Model Inspector.

4.  **Add New Attributes for Serialized Data and `receiptType`:**
    *   Ensure the `ReceiptEntity` is selected.
    *   Focus on the "Attributes" section in the Data Model Inspector.
    *   To add a new attribute, click the `+` button (it might be labeled "Add Attribute" or just be a plus symbol) located at the bottom of the "Attributes" list.
    *   For each new attribute listed below, you will:
        *   Enter the **Attribute Name** exactly as specified.
        *   Choose the correct **Type** from the dropdown menu.
        *   Check or uncheck the **Optional** checkbox as specified.
        *   Set a **Default Value** if specified (primarily for non-optional scalar types).

    **Attributes to Add/Verify:**

    *   **For Serialized Data (Nested Structs):**
        *   Name: `vendorInfoData`
            *   Type: **Binary Data**
            *   Optional: **Checked** (Yes)
        *   Name: `transactionInfoData`
            *   Type: **Binary Data**
            *   Optional: **Checked** (Yes)
        *   Name: `itemsData`
            *   Type: **Binary Data**
            *   Optional: **Checked** (Yes)
        *   Name: `totalsData`
            *   Type: **Binary Data**
            *   Optional: **Checked** (Yes)
        *   Name: `notesData`
            *   Type: **Binary Data**
            *   Optional: **Checked** (Yes)

    *   **For Other Direct Properties of `ReceiptEntity`:**
        *   Name: `receiptType`
            *   Type: **String**
            *   Optional: **Checked** (Yes)

    *   **Verify/Ensure these Core Attributes Exist (they should from before, but confirm types and optionality):**
        *   Name: `id`
            *   Type: **UUID**
            *   Optional: **Unchecked** (No) - This is your primary identifier.
        *   Name: `imageData`
            *   Type: **Binary Data**
            *   Optional: **Checked** (Yes)
        *   Name: `rawOCRText`
            *   Type: **String**
            *   Optional: **Checked** (Yes)
        *   Name: `confidenceScore`
            *   Type: **Double**
            *   Optional: **Unchecked** (No)
            *   Default Value: `0.0` (Enter this in the "Default Value" field in the inspector).
        *   Name: `needsReview`
            *   Type: **Boolean**
            *   Optional: **Unchecked** (No)
            *   Default Value: `NO` (or `false`).
        *   Name: `createdAt`
            *   Type: **Date**
            *   Optional: **Unchecked** (No)
        *   Name: `updatedAt`
            *   Type: **Date**
            *   Optional: **Unchecked** (No)

5.  **Remove Old, Now Redundant Flat Attributes:**
    *   Carefully review the "Attributes" list for `ReceiptEntity`.
    *   For each attribute name listed below, if it exists as a separate, top-level attribute on `ReceiptEntity`, select it and then click the `-` button (at the bottom of the attributes list) to delete it.
    *   **Attributes to Remove (these are now part of the serialized `...Data` fields or replaced):**
        *   `vendor` (old String? attribute)
        *   `amount` (old Double attribute)
        *   `date` (old Date? attribute)
        *   `category` (old String? attribute)
        *   `notes` (the old top-level String? for notes)
        *   `confidence` (the old Double for confidence, if it wasn't already replaced by `confidenceScore`)
        *   `paymentMethod` (old String? attribute)
        *   `location` (old String? attribute)
        *   `tags` (old String? attribute)
        *   `taxCategory` (old String? attribute)
        *   `businessPurpose` (old String? attribute)
        *   `subtotal` (old Double attribute)
        *   `taxAmount` (old Double attribute)
        *   `tipAmount` (old Double attribute)
        *   `taxRate` (old Double attribute)
        *   `transactionId` (the old top-level String? for transaction ID)
        *   `vendorTaxId` (old String? attribute)
        *   `mileage` (old String? attribute)
        *   `vehicleInfo` (old String? attribute)

    *   **Goal:** After this step, `ReceiptEntity`'s attributes should primarily be: `id`, `imageData`, `rawOCRText`, `confidenceScore`, `needsReview`, `createdAt`, `updatedAt`, `receiptType`, and the five new `...Data` attributes (`vendorInfoData`, `transactionInfoData`, etc.).

6.  **Save the Core Data Model:**
    *   Press `Cmd+S` or choose File > Save from the Xcode menu to save your changes to the `ReceiptData.xcdatamodeld` file.

7.  **Generate `NSManagedObject` Subclass Files (Crucial Step):**
    *   After modifying the model, you **must** regenerate the Swift files for `ReceiptEntity` so your Swift code knows about the new attribute names and types.
    *   Make sure `ReceiptData.xcdatamodeld` is still selected in the Project Navigator.
    *   From the Xcode menu bar, choose **Editor > Create NSManagedObject Subclass...**.
    *   A dialog box will appear:
        *   **Select Data Models:** Ensure your `ReceiptData` model (or whatever your `.xcdatamodeld` is named) is checked. Click **Next**.
        *   **Select Entities to Manage:** Ensure `ReceiptEntity` is checked. Click **Next**.
    *   For `ReceiptEntity` in the next panel:
        *   **Language:** Set to **Swift**.
        *   **Codegen:** Choose **Class Definition**. (This will generate two files: `ReceiptEntity+CoreDataClass.swift` and `ReceiptEntity+CoreDataProperties.swift`).
    *   Click **Create**.
    *   Xcode will ask where to save these generated files. The default location (usually your project's main directory or a "CoreData" group if you have one) is typically fine.
    *   **Important:** If Xcode warns that files with these names already exist, **allow it to replace them**. This is necessary to get the updated versions.

**After Completing These Steps:**

1.  **Clean Your Project:**
    *   In Xcode, from the menu bar, choose **Product > Clean Build Folder**. This helps remove any old compiled versions.
2.  **Build Your Project:**
    *   Press `Cmd+B` or choose **Product > Build**.
    *   The project should now build successfully. If you get build errors, they will likely be in `CoreDataManager.swift` or the generated `ReceiptEntity` files. Double-check that the attribute names and types you set in the Core Data Model Editor exactly match what `CoreDataManager.swift` expects (e.g., `entity.vendorInfoData`, `entity.itemsData`, etc.).

This process ensures that your Core Data persistent store schema (defined in the model editor) matches what your Swift code (especially `CoreDataManager.swift` and the `ReceiptEntity` class files) expects.
