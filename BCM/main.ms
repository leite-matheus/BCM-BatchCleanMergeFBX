/*
 * Comprehensive Scene Cleaner, Merger, and Importer
 * Combines scene cleanup, object merging by material, and FBX import functionality
 */

-- Define a standard directory where all scripts should be located
global scriptDirectory = getFilenamePath (getSourceFileName())

-- Define the global function for updating progress first
global updateProgress
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

-- Simple function to load script files with error handling
fn loadScriptFile filename = (
    local filePath = pathConfig.appendPath scriptDirectory filename
    local success = false
    
    if doesFileExist filePath then (
        try (
            fileIn filePath
            format "Successfully loaded: %\n" filename
            success = true
        ) catch (
            local errorMsg = getCurrentException()
            format "Error loading %: %\n" filename errorMsg
            format "Failed to load " + filename + ":\n\n" + errorMsg + "\n"
        )
    ) else (
        format "Script file not found: %\n" filePath
        format "Script file not found:\n" + filePath + "\n"
    )
    
    success
)

-- Force a complete garbage collection before loading scripts
gc()
clearListener()

format "\n=== Starting Script Load ===\n"
format "Script directory: %\n" scriptDirectory

-- Define global tracking variables
global cleanerLoaded = false
global mergeLoaded = false
global importerLoaded = false

-- Load script files in the correct order
cleanerLoaded = loadScriptFile "cleaner.ms"
mergeLoaded = loadScriptFile "merge.ms"
importerLoaded = loadScriptFile "importer.ms"

-- Check if all required scripts were loaded
if not (cleanerLoaded and mergeLoaded and importerLoaded) then (
    format "One or more required scripts could not be loaded. The tool may not function correctly.\n"
    format "Script loading status:\n"
    format "  cleaner.ms: %\n" cleanerLoaded
    format "  merge.ms: %\n" mergeLoaded
    format "  importer.ms: %\n" importerLoaded
)

-- Main function to run both cleaning and merging operations
fn cleanAndMergeScene = (
    -- First, clean the scene and get remaining geometry
    local remainingGeometry = deleteAllUnwantedObjects()
    
    -- Then, merge objects by material
    if remainingGeometry != undefined and remainingGeometry.count > 0 then (
        mergeByMaterial remainingGeometry
    ) else (
        format "No geometry found to merge after cleanup.\n"
    )
)

-- Create the tool UI directly
fn showMainToolUI = (
    rollout mainToolRollout "Scene Processing Tools" width:300 height:280 (
        groupBox grpActions "Available Actions" pos:[10,10] width:280 height:180
        
        button btnImport "Import FBX Files" pos:[20,40] width:260 height:35
        button btnClean "Clean Current Scene" pos:[20,85] width:260 height:35
        button btnMerge "Merge By Material" pos:[20,130] width:260 height:35
        
        button btnRunAll "Import, Clean & Merge" pos:[20,200] width:260 height:40
        
        label lblStatus "All scripts loaded successfully" pos:[10,250] width:280 height:20
        
        -- Initialize UI
        on mainToolRollout open do (
            if not (cleanerLoaded and mergeLoaded and importerLoaded) then (
                lblStatus.text = "Warning: Not all scripts loaded correctly!"
                -- Don't use textColor property, it's not supported in some 3ds Max versions
                -- Use this instead:
                try(lblStatus.fgcolor = (color 255 0 0)) catch()
            ) else (
                lblStatus.text = "All scripts loaded successfully"
                try(lblStatus.fgcolor = (color 0 150 0)) catch()
            )
        )
        
        -- Button event handlers
        on btnImport pressed do (
            if importerLoaded then (
                destroyDialog mainToolRollout
                showImportSettingsDialog()
            ) else (
                format "Import functionality unavailable: script not loaded.\n"
            )
        )
        
        on btnClean pressed do (
            if cleanerLoaded then (
                destroyDialog mainToolRollout
                deleteAllUnwantedObjects()
            ) else (
                format "Clean functionality unavailable: script not loaded.\n"
            )
        )
        
        on btnMerge pressed do (
            if mergeLoaded then (
                destroyDialog mainToolRollout
                mergeByMaterial (getCurrentSelection())
            ) else (
                format "Merge functionality unavailable: script not loaded.\n"
            )
        )
        
        on btnRunAll pressed do (
            if importerLoaded then (
                destroyDialog mainToolRollout
                showImportSettingsDialog()
            ) else (
                format "Import functionality unavailable: script not loaded.\n"
            )
        )
    )
    
    -- Try to close any existing dialog first
    try (destroyDialog mainToolRollout) catch()
    
    -- Create the dialog
    createDialog mainToolRollout
)

-- Register macroscripts for toolbar buttons only if scripts are loaded
if cleanerLoaded and mergeLoaded and importerLoaded then (
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
)

-- Show the tool UI on startup
showMainToolUI()