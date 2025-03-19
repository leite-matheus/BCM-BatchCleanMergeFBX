/*
 * Comprehensive Scene Cleaner, Merger, and Importer
 * Combines scene cleanup, object merging by material, and FBX import functionality
 * 
 * Features:
 * 1. Import FBX files individually or in batches
 * 2. Delete all unnecessary objects (shapes, lights, cameras, helpers, etc.)
 * 3. Automatically select remaining geometry for merging
 * 4. Always processes objects in batches for optimal memory management
 */

-- Include necessary script files
fileIn "cleaner.ms"
fileIn "merge.ms"
fileIn "importer.ms"

-- Global utility function to update progress dialog
global updateProgress

-- Define the global function for updating progress
fn updateProgress progressDialog percent statusText = (
    if progressDialog != undefined and progressDialog.created then (
        try (
            progressDialog.pbMerge.value = percent
            progressDialog.lblStatus.text = statusText
            windows.processPostedMessages()
        )
        catch (
            format "Error updating progress: %\n" (getCurrentException())
        )
    )
)

-- Main function to run both cleaning and merging operations
fn cleanAndMergeScene = (
    -- First, clean the scene and get remaining geometry
    local remainingGeometry = deleteAllUnwantedObjects()
    
    -- Then, merge objects by material
    if remainingGeometry != undefined and remainingGeometry.count > 0 then (
        mergeByMaterial remainingGeometry
    ) else (
        messageBox "No geometry found to merge after cleanup." title:"No Geometry"
    )
)

-- Create the tool UI directly
fn showMainToolUI = (
    rollout mainToolRollout "Scene Processing Tools" width:300 height:250 (
        groupBox grpActions "Available Actions" pos:[10,10] width:280 height:180
        
        button btnImport "Import FBX Files" pos:[20,40] width:260 height:35
        button btnClean "Clean Current Scene" pos:[20,85] width:260 height:35
        button btnMerge "Merge By Material" pos:[20,130] width:260 height:35
        
        button btnRunAll "Import, Clean & Merge" pos:[20,200] width:260 height:40
        
        -- Button event handlers
        on btnImport pressed do (
            destroyDialog mainToolRollout
            showImportSettingsDialog()
        )
        
        on btnClean pressed do (
            destroyDialog mainToolRollout
            deleteAllUnwantedObjects()
        )
        
        on btnMerge pressed do (
            destroyDialog mainToolRollout
            mergeByMaterial (getCurrentSelection())
        )
        
        on btnRunAll pressed do (
            destroyDialog mainToolRollout
            showImportSettingsDialog()
        )
    )
    
    -- Try to close any existing dialog first
    try (destroyDialog mainToolRollout) catch()
    
    -- Create the dialog
    createDialog mainToolRollout
)

-- Register macroscripts for toolbar buttons
macroscript FBXImporterTool
    category:"Processing Tools"
    toolTip:"Import FBX Files"
    buttonText:"Import FBX"
(
    on execute do (
        showImportSettingsDialog()
    )
)

macroscript SceneCleanerTool
    category:"Processing Tools"
    toolTip:"Clean Current Scene"
    buttonText:"Clean Scene"
(
    on execute do (
        deleteAllUnwantedObjects()
    )
)

macroscript MaterialMergerTool
    category:"Processing Tools"
    toolTip:"Merge By Material"
    buttonText:"Merge Objects"
(
    on execute do (
        mergeByMaterial (getCurrentSelection())
    )
)

macroscript AllProcessingTool
    category:"Processing Tools"
    toolTip:"Complete Processing"
    buttonText:"All Processing"
(
    on execute do (
        showMainToolUI()
    )
)

-- Show the tool UI on startup
showMainToolUI()