/*
 * FBX Importer Module
 * Provides batch import functionality for FBX files
 * Integrates with scene cleaner and merger modules
 */

-- Reference to the global updateProgress function
global updateProgress

-- Structure to track import status and metrics
struct ImportStatus (
    totalFiles = 0,
    currentFileIndex = 0,
    successCount = 0,
    failedCount = 0,
    currentFileName = "",
    startTime = 0,
    isCancelled = false
)

-- Global variable to track import status across functions
global gImportStatus = ImportStatus()

-- Import a single FBX file and return success/failure
fn importSingleFBX filePath progressDialog = (
    local success = false
    local errorMessage = ""
    local objectCountBefore = objects.count
    
    -- Update status display
    gImportStatus.currentFileName = getFilenameFile(filePath)
    format "Importing: %\n" filePath
    
    -- Update progress dialog
    if progressDialog != undefined then (
        local percent = 100.0 * gImportStatus.currentFileIndex / gImportStatus.totalFiles
        updateProgress progressDialog percent ("Importing: " + gImportStatus.currentFileName)
    )
    
    -- Reset scene before import
    resetMaxFile #noPrompt
    
    -- Attempt to import the FBX file
    try (
        importFile filePath #noPrompt
        
        -- Check if import actually created any objects
        if objects.count > objectCountBefore then (
            success = true
            gImportStatus.successCount += 1
        ) else (
            errorMessage = "Import completed but no objects were created"
            gImportStatus.failedCount += 1
        )
    ) catch (
        errorMessage = getCurrentException()
        gImportStatus.failedCount += 1
        format "*** ERROR: Failed to import %: %\n" filePath errorMessage
    )
    
    -- Return result
    #(success, errorMessage)
)

-- Helper function for alphabetical sorting - DEFINE BEFORE IT'S USED
fn alphabeticalSort a b = (
    stricmp a b
)

-- Helper function for size ascending sorting - DEFINE BEFORE IT'S USED
fn sizeAscendingSort a b = (
    local aInfo = dotNetObject "System.IO.FileInfo" a
    local bInfo = dotNetObject "System.IO.FileInfo" b
    aInfo.Length < bInfo.Length
)

-- Helper function for size descending sorting - DEFINE BEFORE IT'S USED
fn sizeDescendingSort a b = (
    local aInfo = dotNetObject "System.IO.FileInfo" a
    local bInfo = dotNetObject "System.IO.FileInfo" b
    aInfo.Length > bInfo.Length
)

-- Sort files by name or size
fn sortFilesByMode fileArray sortMode = (
    case sortMode of (
        #alphabetical: (
            qsort fileArray alphabeticalSort
        )
        #sizeAscending: (
            -- Sort by file size (ascending)
            qsort fileArray sizeAscendingSort
        )
        #sizeDescending: (
            -- Sort by file size (descending)
            qsort fileArray sizeDescendingSort
        )
        default: fileArray -- No sorting
    )
    
    fileArray
)

-- Process batch import of multiple FBX files
fn batchImportFBX fileArray sortMode saveCleanedFiles cleanAfterImport mergeAfterClean = (
    -- Initialize import status
    gImportStatus = ImportStatus()
    gImportStatus.totalFiles = fileArray.count
    gImportStatus.startTime = timestamp()
    gImportStatus.isCancelled = false
    
    -- Sort files according to specified mode
    fileArray = sortFilesByMode fileArray sortMode
    
    -- Create progress dialog rollout
    local progressDialog = rollout progressDialog "FBX Import Progress" width:450 height:150 (
        progressBar pbMerge "Overall Progress" pos:[10,10] width:430 height:20 value:0 color:(color 0 128 255)
        label lblStatus "Initializing..." pos:[10,40] width:430 height:20
        label lblFile "Preparing to import..." pos:[10,70] width:430 height:20
        label lblStats "0 of 0 files processed (0 succeeded, 0 failed)" pos:[10,100] width:430 height:20
        button btnCancel "Cancel" pos:[350,120] width:80 height:25
        
        -- Flag dialog as created
        local created = true
        
        -- Cancel button event handler
        on btnCancel pressed do (
            gImportStatus.isCancelled = true
            lblStatus.text = "Cancelling... Please wait"
        )
    )
    
    -- Try to destroy existing dialog first
    try (destroyDialog progressDialog) catch()
    
    -- Create the dialog
    createDialog progressDialog
    
    -- Loop through each file
    for i = 1 to fileArray.count while not gImportStatus.isCancelled do (
        local currentFile = fileArray[i]
        gImportStatus.currentFileIndex = i
        
        -- Update stats display
        progressDialog.lblStats.text = i as string + " of " + fileArray.count as string + 
                                      " files processed (" + gImportStatus.successCount as string + 
                                      " succeeded, " + gImportStatus.failedCount as string + " failed)"
        
        -- Update file display
        progressDialog.lblFile.text = "Current file: " + getFilenameFile currentFile
        
        -- Import the current file
        local importResult = importSingleFBX currentFile progressDialog
        local importSuccess = importResult[1]
        local errorMessage = importResult[2]
        
        -- If import successful and clean requested, run cleaning
        if importSuccess and cleanAfterImport do (
            try (
                -- Update status
                updateProgress progressDialog ((100.0 * i - 0.5) / fileArray.count) "Cleaning imported scene..."
                
                -- Run scene cleaner - verify function exists
                local remainingGeometry = undefined
                if (isFunction deleteAllUnwantedObjects) then (
                    remainingGeometry = deleteAllUnwantedObjects()
                ) else (
                    format "*** ERROR: deleteAllUnwantedObjects function not defined!\n"
                    continue
                )
                
                -- If merge requested and we have geometry, run merge
                if mergeAfterClean and remainingGeometry != undefined and remainingGeometry.count > 0 then (
                    updateProgress progressDialog ((100.0 * i - 0.25) / fileArray.count) "Merging objects by material..."
                    
                    -- Verify the mergeByMaterial function exists
                    if (isFunction mergeByMaterial) then (
                        -- Explicitly select the geometry objects first to ensure they're available
                        clearSelection()
                        select remainingGeometry
                        
                        try (
                            -- Call merge with specific array of objects
                            local mergeSuccess = mergeByMaterial remainingGeometry
                            
                            -- Check if merge was successful
                            if not mergeSuccess then (
                                format "*** WARNING: Merge operation failed or did not complete for %\n" currentFile
                            )
                        ) catch (
                            local mergeError = getCurrentException()
                            format "*** ERROR during merge operation: %\n" mergeError
                        )
                    ) else (
                        format "*** ERROR: mergeByMaterial function not defined!\n"
                    )
                )
                
                -- If save requested, save the file
                if saveCleanedFiles do (
                    -- Create output filename (same as input but .max extension)
                    local outputPath = getFilenamePath currentFile + getFilenameFile currentFile + ".max"
                    
                    -- Save the file
                    updateProgress progressDialog ((100.0 * i - 0.1) / fileArray.count) "Saving processed file..."
                    saveMaxFile outputPath useNewFile:false quiet:true
                    format "Saved processed file to %\n" outputPath
                )
            ) catch (
                local processingError = getCurrentException()
                format "*** ERROR during processing file %: %\n" currentFile processingError
            )
        )
        
        -- Force garbage collection
        gc()
        windows.processPostedMessages()
    )
    
    -- Calculate elapsed time
    local elapsedTime = (timestamp() - gImportStatus.startTime) / 1000.0
    
    -- Close progress dialog
    try (destroyDialog progressDialog) catch()
    
    -- Report results
    local resultMessage = "Import batch completed in " + elapsedTime as string + " seconds.\n"
    resultMessage += gImportStatus.successCount as string + " files imported successfully.\n"
    resultMessage += gImportStatus.failedCount as string + " files failed to import."
    
    if not gImportStatus.isCancelled then (
        messageBox resultMessage title:"Batch Import Complete"
    ) else (
        messageBox "Import process cancelled by user.\n" + resultMessage title:"Batch Import Cancelled"
    )
    
    format "%\n" resultMessage
    
    -- Return status
    gImportStatus
)

-- Function to get all FBX files in a directory
fn getFbxFilesInDirectory dirPath = (
    local fileArray = #()
    local searchPath = pathConfig.appendPath dirPath "*.fbx"
    
    -- Get all FBX files
    fileArray = getFiles searchPath
    
    fileArray
)

-- Main function to start the FBX import process
fn startFbxImport mode:#directory sortMode:#alphabetical cleanAfterImport:true mergeAfterClean:true saveCleanedFiles:true = (
    local fileArray = #()
    
    case mode of (
        #directory: (
            -- Ask user to select a directory
            local dirPath = getSavePath caption:"Select Directory with FBX Files" initialDir:(maxFilePath)
            
            if dirPath != undefined then (
                -- Get all FBX files in directory
                fileArray = getFbxFilesInDirectory dirPath
                
                if fileArray.count == 0 then (
                    messageBox "No FBX files found in the selected directory." title:"No Files Found"
                    return false
                )
            ) else (
                -- User cancelled directory selection
                return false
            )
        )
        
        #singleFile: (
            -- Ask user to select a single file
            local filePath = getOpenFileName caption:"Select FBX File" types:"FBX Files (*.fbx)|*.fbx|All Files (*.*)|*.*" initialDir:(maxFilePath)
            
            if filePath != undefined then (
                fileArray = #(filePath)
            ) else (
                -- User cancelled file selection
                return false
            )
        )
        
        default: (
            messageBox "Invalid import mode specified." title:"Error"
            return false
        )
    )
    
    -- If we have files to process, start the batch import
    if fileArray.count > 0 then (
        return batchImportFBX fileArray sortMode saveCleanedFiles cleanAfterImport mergeAfterClean
    )
    
    false
)

-- Create a UI dialog for import settings
fn showImportSettingsDialog = (
    rollout importSettingsRollout "FBX Import Settings" width:400 height:300 (
        -- Store settings locally in the rollout
        local mode = #directory
        local sortMode = #alphabetical
        local cleanAfterImport = true
        local mergeAfterClean = true
        local saveCleanedFiles = true
        
        groupBox grpMode "Import Mode" pos:[10,10] width:380 height:70
        radioButtons rdoMode labels:#("Directory (Batch Import)", "Single File") pos:[20,30] width:360 columns:2
        
        groupBox grpSort "Sort Order" pos:[10,90] width:380 height:70
        radioButtons rdoSort labels:#("Alphabetical", "Size (Smallest First)", "Size (Largest First)") pos:[20,110] width:360 columns:3
        
        groupBox grpProcess "Processing Options" pos:[10,170] width:380 height:80
        checkbox chkClean "Clean scene after import" pos:[20,190] width:170 height:20 checked:true
        checkbox chkMerge "Merge by material after cleaning" pos:[200,190] width:180 height:20 checked:true
        checkbox chkSave "Save processed files (.max)" pos:[20,220] width:170 height:20 checked:true
        
        button btnStart "Start Import" pos:[220,260] width:120 height:30
        button btnCancel "Cancel" pos:[100,260] width:100 height:30
        
        -- Initialize UI
        on importSettingsRollout open do (
            rdoMode.state = 1  -- Default to directory mode
            rdoSort.state = 1  -- Default to alphabetical
            chkClean.checked = true
            chkMerge.checked = true
            chkSave.checked = true
        )
        
        -- Start button handler
        on btnStart pressed do (
            -- Start import process with current settings
            local selectedMode = case rdoMode.state of (
                1: #directory
                2: #singleFile
                default: #directory
            )
            
            local selectedSortMode = case rdoSort.state of (
                1: #alphabetical
                2: #sizeAscending
                3: #sizeDescending
                default: #alphabetical
            )
            
            -- Close dialog
            destroyDialog importSettingsRollout
            
            -- Start import process
            startFbxImport mode:selectedMode sortMode:selectedSortMode cleanAfterImport:chkClean.checked mergeAfterClean:chkMerge.checked saveCleanedFiles:chkSave.checked
        )
        
        -- Cancel button handler
        on btnCancel pressed do (
            destroyDialog importSettingsRollout
        )
    )
    
    -- Show the dialog
    createDialog importSettingsRollout modal:true
)

-- Command function to show in toolbar or menu
fn fbxImportCommandFn = (
    showImportSettingsDialog()
)