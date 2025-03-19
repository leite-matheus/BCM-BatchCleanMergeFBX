/*
 * Comprehensive Scene Cleaner and Merger
 * Combines scene cleanup and object merging by material
 * 
 * Features:
 * 1. Delete all unnecessary objects (shapes, lights, cameras, helpers, etc.)
 * 2. Automatically select remaining geometry for merging
 * 3. Always processes objects in batches for optimal memory management
 */

-- Include necessary script files
fileIn "cleaner.ms"
fileIn "merge.ms"

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

-- Main function to run both operations
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

-- Run the combined operation
cleanAndMergeScene()