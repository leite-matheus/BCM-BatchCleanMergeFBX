/*
 * BCM_FileFunctions.ms
 * 
 * Description: Functions for file operations in the Bulk Clean and Merge tool.
 * 
 * Created: March 17, 2025
 */

-- ==========================================================================
-- Function to Get FBX Files Based on Current Configuration
-- ==========================================================================
fn BCM_GetFBXFiles = (
    local fbxFiles = #()
    
    if BCM_processingMode == 1 then (
        -- Directory mode - get all FBX files in the directory
        local filePattern = BCM_inputDir + "\\*.fbx"
        fbxFiles = getFiles filePattern
        
        -- Sort the files according to the sorting mode
        case BCM_sortingMode of (
            1: ( -- Alphabetical
                sort fbxFiles
            )
            2: ( -- Size ascending
                -- Get file sizes and create a sorted array
                local fileSizes = #()
                local sortedFiles = #()
                
                -- Create array of [index, filesize] pairs to avoid path encoding issues
                for i = 1 to fbxFiles.count do (
                    try (
                        local fileObj = dotNetObject "System.IO.FileInfo" fbxFiles[i]
                        append fileSizes #(i, fileObj.Length as float)
                    ) catch (
                        -- If we can't get file size, use 0 as default
                        format "Warning: Could not get file size for %\n" fbxFiles[i]
                        append fileSizes #(i, 0.0)
                    )
                )
                
                -- Sort by file size (ascending)
                -- In MAXScript, we need to sort the array manually for complex comparisons
                for i = 1 to (fileSizes.count - 1) do (
                    for j = i + 1 to fileSizes.count do (
                        if fileSizes[i][2] > fileSizes[j][2] then (
                            -- Swap elements
                            local temp = fileSizes[i]
                            fileSizes[i] = fileSizes[j]
                            fileSizes[j] = temp
                        )
                    )
                )
                
                -- Extract the filenames in sorted order
                for i = 1 to fileSizes.count do (
                    append sortedFiles fbxFiles[fileSizes[i][1]]
                )
                
                fbxFiles = sortedFiles
            )
            3: ( -- Size descending
                -- Get file sizes and create a sorted array
                local fileSizes = #()
                local sortedFiles = #()
                
                -- Create array of [index, filesize] pairs to avoid path encoding issues
                for i = 1 to fbxFiles.count do (
                    try (
                        local fileObj = dotNetObject "System.IO.FileInfo" fbxFiles[i]
                        append fileSizes #(i, fileObj.Length as float)
                    ) catch (
                        -- If we can't get file size, use 0 as default
                        format "Warning: Could not get file size for %\n" fbxFiles[i]
                        append fileSizes #(i, 0.0)
                    )
                )
                
                -- Sort by file size (descending)
                -- In MAXScript, we need to sort the array manually for complex comparisons
                for i = 1 to (fileSizes.count - 1) do (
                    for j = i + 1 to fileSizes.count do (
                        if fileSizes[i][2] < fileSizes[j][2] then (
                            -- Swap elements
                            local temp = fileSizes[i]
                            fileSizes[i] = fileSizes[j]
                            fileSizes[j] = temp
                        )
                    )
                )
                
                -- Extract the filenames in sorted order
                for i = 1 to fileSizes.count do (
                    append sortedFiles fbxFiles[fileSizes[i][1]]
                )
                
                fbxFiles = sortedFiles
            )
        )
    ) else (
        -- Single file mode - ask user to select a file
        local fbxFile = getOpenFileName caption:"Select FBX File" \
                         types:"FBX Files (*.fbx)|*.fbx|All Files (*.*)|*.*" \
                         initialDir:BCM_inputDir
        
        if fbxFile != undefined then (
            -- Store the input directory for next time
            BCM_inputDir = getFilenamePath fbxFile
            append fbxFiles fbxFile
        )
    )
    
    return fbxFiles
)

-- ==========================================================================
-- Function to Import FBX File
-- ==========================================================================
fn BCM_ImportFBX filename = (
    local success = false
    
    format "Importing FBX file: %\n" filename
    BCM_currentFile = filenameFromPath filename
    
    try (
        -- Reset scene first
        resetMaxFile #noPrompt
        
        -- Import the FBX file
        importFile filename #noPrompt using:FBXIMPORTER
        
        -- Check if import was successful
        if objects.count > 0 then (
            success = true
            format "Successfully imported % objects\n" objects.count
        ) else (
            format "Warning: FBX file imported but no objects found\n"
            success = false
        )
    ) catch (
        format "Error importing FBX: %\n" (getCurrentException())
        success = false
    )
    
    return success
)

-- ==========================================================================
-- Function to Save Processed File as MAX
-- ==========================================================================
fn BCM_SaveAsMax originalFilename = (
    try (
        -- Create output directory if it doesn't exist
        makeDir BCM_outputDir all:true
        
        -- Extract base filename and create new path with .max extension
        local baseName = getFilenameFile originalFilename
        local outputPath = pathConfig.appendPath BCM_outputDir (baseName + ".max")
        
        format "Saving processed file to: %\n" outputPath
        
        -- Save the file
        saveMaxFile outputPath quiet:true
        
        format "File saved successfully\n"
        return true
    ) catch (
        format "Error saving file: %\n" (getCurrentException())
        return false
    )
)

-- ==========================================================================
-- Function to Process a Single FBX File
-- ==========================================================================
fn BCM_ProcessFile fbxFile = (
    local success = true
    
    -- Import the FBX file
    if not (BCM_ImportFBX fbxFile) then (
        format "Failed to import FBX file: %\n" fbxFile
        return false
    )
    
    -- Clean the scene
    if not (BCM_CleanScene()) then (
        format "Failed to clean scene\n"
        success = false
    )
    
    -- Fix inverted normals if enabled
    if BCM_fixNormals and not (BCM_FixInvertedNormals()) then (
        format "Failed to fix normals\n"
        success = false
    )
    
    -- Merge objects by material
    if not (BCM_MergeByMaterial()) then (
        format "Failed to merge objects by material\n"
        success = false
    )
    
    -- Save the processed file
    if not (BCM_SaveAsMax fbxFile) then (
        format "Failed to save processed file\n"
        success = false
    )
    
    return success
)

-- ==========================================================================
-- Main Processing Function for All Files
-- ==========================================================================
fn BCM_ProcessAllFiles = (
    -- Reset status
    BCM_processingComplete = false
    BCM_cancelProcessing = false
    BCM_skipToNext = false
    
    -- Get files to process
    local fbxFiles = BCM_GetFBXFiles()
    
    -- Check if we have files to process
    if fbxFiles.count == 0 then (
        messageBox "No FBX files found to process." title:"No Files"
        return false
    )
    
    -- Set up progress tracking
    BCM_totalFiles = fbxFiles.count
    BCM_currentProgress = 0
    
    -- Update UI
    if BCM_RolloutProgress != undefined then (
        try (
            if BCM_prgOverall != undefined then BCM_prgOverall.value = 0
            if BCM_lblCurrentFile != undefined then BCM_lblCurrentFile.text = "Preparing..."
        ) catch (
            format "Warning: Unable to update progress UI elements\n"
        )
    )
    
    -- Process each file
    local overallSuccess = true
    local processedCount = 0
    
    for i = 1 to fbxFiles.count do (
        -- Check if user canceled
        if BCM_cancelProcessing then (
            format "Processing canceled by user\n"
            exit
        )
        
        -- Update progress
        BCM_currentProgress = 100.0 * (i - 1) / BCM_totalFiles
        if BCM_RolloutProgress != undefined then (
            try (
                if BCM_prgOverall != undefined then BCM_prgOverall.value = BCM_currentProgress
                if BCM_lblCurrentFile != undefined then BCM_lblCurrentFile.text = "Processing: " + (filenameFromPath fbxFiles[i])
            ) catch (
                format "Warning: Unable to update progress UI elements\n"
            )
        )
        
        -- Process the file
        format "\n====================================================\n"
        format "Processing file % of %: %\n" i BCM_totalFiles fbxFiles[i]
        format "====================================================\n"
        
        local fileSuccess = BCM_ProcessFile fbxFiles[i]
        
        if fileSuccess then (
            processedCount += 1
        ) else (
            format "Failed to process file: %\n" fbxFiles[i]
            overallSuccess = false
            
            -- Prompt user to continue or cancel
            if BCM_processingMode == 1 and i < BCM_totalFiles then (
                -- Only prompt in directory mode with multiple files
                BCM_skipToNext = true
                
                -- Skip to next file automatically after a failure
                format "Skipping to next file...\n"
            )
        )
        
        -- Update progress
        BCM_currentProgress = 100.0 * i / BCM_totalFiles
        if BCM_RolloutProgress != undefined then (
            try (
                if BCM_prgOverall != undefined then BCM_prgOverall.value = BCM_currentProgress
            ) catch (
                format "Warning: Unable to update progress UI elements\n"
            )
        )
    )
    
    -- Complete the process
    BCM_processingComplete = true
    
    -- Update UI for completion
    if BCM_RolloutProgress != undefined then (
        BCM_prgOverall.value = 100
        BCM_lblCurrentFile.text = "Processing complete"
    )
    
    -- Show completion message
    local resultMessage = "Processed " + processedCount as string + " of " + BCM_totalFiles as string + " files"
    
    if processedCount == BCM_totalFiles then (
        messageBox resultMessage title:"Processing Complete"
    ) else (
        messageBox (resultMessage + "\nSome files could not be processed. Check the MAXScript Listener for details.") title:"Processing Complete with Errors"
    )
    
    format "\n====================================================\n"
    format "%\n" resultMessage
    format "====================================================\n"
    
    return overallSuccess
)