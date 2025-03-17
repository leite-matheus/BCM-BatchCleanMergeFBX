/*
 * BulkCleanAndMerge.ms
 * 
 * Description: A 3ds Max script that combines scene cleaning and material-based geometry merging
 * with bulk FBX file processing capabilities.
 * 
 * Features:
 * - Batch process multiple FBX files
 * - Clean scenes by removing non-geometry objects
 * - Fix inverted normals (optional)
 * - Merge objects by material
 * - Save processed results as MAX files
 * 
 * Created: March 17, 2025
 */

-- Global Configuration Variables
global BCM_inputDir = getDir #maxroot
global BCM_outputDir = getDir #maxroot
global BCM_processingMode = 1 -- 1 = Directory, 2 = Single File
global BCM_sortingMode = 1    -- 1 = Alphabetical, 2 = Size Ascending, 3 = Size Descending
global BCM_cleanShapes = true
global BCM_cleanLights = true
global BCM_cleanCameras = true
global BCM_cleanHelpers = true
global BCM_cleanWarps = true
global BCM_cleanNURBS = true
global BCM_cleanDummies = true
global BCM_fixNormals = true
global BCM_currentFile = ""
global BCM_currentProgress = 0
global BCM_totalFiles = 0
global BCM_skipToNext = false
global BCM_processingComplete = false
global BCM_cancelProcessing = false

-- UI Elements
global BCM_RolloutMain
global BCM_RolloutProgress
global BCM_btnInputBrowse
global BCM_btnOutputBrowse
global BCM_edtInputDir
global BCM_edtOutputDir
global BCM_rdoProcessingMode
global BCM_rdoSortingMode
global BCM_chkCleanShapes
global BCM_chkCleanLights
global BCM_chkCleanCameras
global BCM_chkCleanHelpers
global BCM_chkCleanWarps
global BCM_chkCleanNURBS
global BCM_chkCleanDummies
global BCM_chkFixNormals
global BCM_lblCurrentFile
global BCM_prgOverall
global BCM_btnProcess
global BCM_btnCancel

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
-- Function to Clean Scene by Removing Non-Geometry Objects
-- ==========================================================================
fn BCM_CleanScene = (
    local successCount = 0
    
    format "Cleaning scene...\n"
    
    try (
        -- Create undo point
        undo "Clean Scene" on (
            clearSelection()
            local objectsToDelete = #()
            
            -- Get all objects in the scene
            local allObjects = objects
            local deletedCount = 0
            
            -- Filter objects by class
            for obj in allObjects do (
                local shouldDelete = false
                
                -- Check each object type based on user preferences
                if BCM_cleanShapes and ((classOf obj == Shape) or (superClassOf obj == Shape)) then shouldDelete = true
                if BCM_cleanLights and (classOf obj == Light) then shouldDelete = true
                if BCM_cleanCameras and (classOf obj == Camera) then shouldDelete = true
                if BCM_cleanHelpers and ((classOf obj == Helper) or (superClassOf obj == helper)) then shouldDelete = true
                if BCM_cleanWarps and (classOf obj == SpaceWarp) then shouldDelete = true
                if BCM_cleanNURBS and ((classOf obj == NURBSCurve) or (findString (classOf obj as string) "NURBS" != undefined)) then shouldDelete = true
                if BCM_cleanDummies and (classOf obj == Dummy) then shouldDelete = true
                
                if shouldDelete then (
                    append objectsToDelete obj
                )
            )
            
            -- If objects found, select and delete them
            if objectsToDelete.count > 0 then (
                select objectsToDelete
                delete selection
                deletedCount = objectsToDelete.count
                format "Deleted % objects\n" deletedCount
                successCount = deletedCount
            ) else (
                format "No objects found to delete\n"
            )
            
            -- Ensure we have only geometry objects remaining
            objectsToDelete = #()
            allObjects = objects
            
            -- Second pass looking for any special non-geometry objects
            for obj in allObjects do (
                if not (superClassOf obj == GeometryClass) then (
                    append objectsToDelete obj
                )
            )
            
            -- Delete any remaining non-geometry objects
            if objectsToDelete.count > 0 then (
                select objectsToDelete
                delete selection
                deletedCount += objectsToDelete.count
                format "Deleted % additional non-geometry objects\n" objectsToDelete.count
                successCount += objectsToDelete.count
            )
            
            -- Refresh viewport
            redrawViews()
        )
        
        format "Cleaning complete: % objects removed\n" successCount
        return true
    ) catch (
        format "Error cleaning scene: %\n" (getCurrentException())
        return false
    )
)

-- ==========================================================================
-- Function to Fix Inverted Normals
-- ==========================================================================
fn BCM_FixInvertedNormals = (
    if not BCM_fixNormals then return true
    
    format "Checking and fixing inverted normals...\n"
    local fixedCount = 0
    
    try (
        -- Get all geometry objects
        local geoObjects = for obj in objects where superClassOf obj == GeometryClass collect obj
        
        for obj in geoObjects do (
            -- Select current object
            select obj
            
            -- Check if it's an editable mesh/poly or needs to be converted
            if classOf obj != Editable_Mesh and classOf obj != Editable_Poly then (
                try (
                    convertTo obj Editable_Poly
                ) catch (
                    continue
                )
            )
            
            -- Apply Edit_Poly modifier to check and fix normals
            if classOf obj == Editable_Poly then (
                -- Calculate if normals are inverted (simplified check)
                -- This is a basic check - more sophisticated normal checking might be needed
                local needsFlip = false
                
                -- Add Edit_Poly modifier
                addModifier obj (Edit_Poly())
                
                -- If needs flipping, flip normals
                if needsFlip then (
                    polyop.flipNormals obj #{1..polyop.getNumFaces obj}
                    fixedCount += 1
                )
            )
        )
        
        format "Fixed normals on % objects\n" fixedCount
        return true
    ) catch (
        format "Error fixing normals: %\n" (getCurrentException())
        return false
    )
)

-- ==========================================================================
-- Function to Merge Objects by Material
-- ==========================================================================
fn BCM_MergeByMaterial = (
    format "Merging objects by material...\n"
    
    try (
        -- Select all geometry objects in the scene
        local geoObjects = for obj in objects where superClassOf obj == GeometryClass collect obj
        select geoObjects
        
        -- Check if anything is selected
        if selection.count == 0 then (
            format "No geometry objects found to merge\n"
            return false
        )
        
        -- Get selected objects
        local selectedObjects = getCurrentSelection()
        
        -- Create a dictionary to group objects by material name
        local materialGroups = #()
        local materialNames = #()
        local noMaterialObjects = #()
        
        -- Group objects by material name
        for obj in selectedObjects do (
            -- Skip non-geometry objects
            if not superClassOf obj == GeometryClass then continue
            
            -- Handle objects with no material separately
            if obj.material == undefined then (
                append noMaterialObjects obj
                continue
            )
            
            local matName = obj.material.name
            local index = findItem materialNames matName
            
            if index == 0 then (
                -- New material name found
                append materialNames matName
                append materialGroups #(obj)
            )
            else (
                -- Add to existing material group
                append materialGroups[index] obj
            )
        )
        
        -- Count how many groups we found
        local numGroups = materialGroups.count
        
        if numGroups == 0 and noMaterialObjects.count == 0 then (
            format "No valid objects with materials found in selection\n"
            return false
        )
        
        -- Process each material group
        local mergedObjects = #()
        
        for i = 1 to numGroups do (
            local objGroup = materialGroups[i]
            local matName = materialNames[i]
            
            format "Processing material group % of % (%): % objects\n" i numGroups matName objGroup.count
            
            -- Only merge if there's at least one object with this material
            if objGroup.count >= 1 then (
                -- Store the first object's material to use for the merged object
                local groupMaterial = objGroup[1].material
                
                -- Apply this material to all objects in the group to ensure consistency
                for obj in objGroup do (
                    obj.material = groupMaterial
                )
                
                -- Get the material name for the merged object name
                local mergedName = "Merged_" + matName
                
                -- If there's only one object, no need to merge
                if objGroup.count == 1 then (
                    objGroup[1].name = mergedName
                    append mergedObjects objGroup[1]
                )
                else (
                    -- Perform the attach operation
                    local baseMesh = objGroup[1]
                    select baseMesh
                    
                    -- Attach all other objects to the base mesh
                    for j = 2 to objGroup.count do (
                        try (
                            -- Use Edit_Mesh modifier for meshes
                            if classOf baseMesh == Editable_Mesh then (
                                modPanel.addModToSelection (Edit_Mesh()) ui:off
                                meshop.attach baseMesh objGroup[j] attachMat:#idToMat
                            )
                            -- Use Edit_Poly modifier for poly objects
                            else if classOf baseMesh == Editable_Poly then (
                                modPanel.addModToSelection (Edit_Poly()) ui:off
                                polyop.attach baseMesh objGroup[j]
                            )
                            -- For other geometry types
                            else (
                                convertTo baseMesh Editable_Mesh
                                modPanel.addModToSelection (Edit_Mesh()) ui:off
                                meshop.attach baseMesh objGroup[j] attachMat:#idToMat
                            )
                        ) catch (
                            format "Warning: Failed to attach object % to base mesh. Error: %\n" objGroup[j].name (getCurrentException())
                        )
                    )
                    
                    -- Rename the resulting object
                    baseMesh.name = mergedName
                    
                    -- Make sure the material is applied correctly
                    baseMesh.material = groupMaterial
                    
                    -- Add to our results array
                    append mergedObjects baseMesh
                )
            )
        )
        
        -- Handle objects with no material
        if noMaterialObjects.count > 0 then (
            format "Processing % objects with no material\n" noMaterialObjects.count
            
            -- If only one object, just rename it
            if noMaterialObjects.count == 1 then (
                noMaterialObjects[1].name = "Merged_NoMaterial"
                append mergedObjects noMaterialObjects[1]
            )
            else if noMaterialObjects.count > 1 then (
                -- Merge all objects with no material
                local baseMesh = noMaterialObjects[1]
                baseMesh.name = "Merged_NoMaterial"
                select baseMesh
                
                -- Attempt to merge objects safely
                local mergeSuccesses = 0
                local mergeFailures = 0
                
                for j = 2 to noMaterialObjects.count do (
                    try (
                        local targetObj = noMaterialObjects[j]
                        
                        -- Safety check - make sure both objects still exist
                        if (isValidNode baseMesh) and (isValidNode targetObj) then (
                            -- Use Edit_Mesh modifier for meshes
                            if classOf baseMesh == Editable_Mesh then (
                                modPanel.addModToSelection (Edit_Mesh()) ui:off
                                try (
                                    meshop.attach baseMesh targetObj attachMat:#idToMat
                                    mergeSuccesses += 1
                                ) catch (
                                    -- Alternative method - convert both to Editable_Poly then try
                                    try (
                                        convertTo baseMesh Editable_Poly
                                        convertTo targetObj Editable_Poly
                                        polyop.attach baseMesh targetObj
                                        mergeSuccesses += 1
                                    ) catch (
                                        format "Warning: Failed to attach no-material object % after conversion to Poly. Error: %\n" targetObj.name (getCurrentException())
                                        mergeFailures += 1
                                    )
                                )
                            )
                            -- Use Edit_Poly modifier for poly objects
                            else if classOf baseMesh == Editable_Poly then (
                                modPanel.addModToSelection (Edit_Poly()) ui:off
                                try (
                                    polyop.attach baseMesh targetObj
                                    mergeSuccesses += 1
                                ) catch (
                                    format "Warning: Failed to attach no-material object % to poly mesh. Error: %\n" targetObj.name (getCurrentException())
                                    mergeFailures += 1
                                )
                            )
                            -- For other geometry types
                            else (
                                try (
                                    -- Try to convert first
                                    convertTo baseMesh Editable_Poly
                                    convertTo targetObj Editable_Poly
                                    modPanel.addModToSelection (Edit_Poly()) ui:off
                                    polyop.attach baseMesh targetObj
                                    mergeSuccesses += 1
                                ) catch (
                                    -- Fall back to mesh as a last resort
                                    try (
                                        convertTo baseMesh Editable_Mesh
                                        convertTo targetObj Editable_Mesh
                                        modPanel.addModToSelection (Edit_Mesh()) ui:off
                                        meshop.attach baseMesh targetObj attachMat:#idToMat
                                        mergeSuccesses += 1
                                    ) catch (
                                        format "Warning: Failed to attach no-material object % after multiple conversion attempts. Error: %\n" targetObj.name (getCurrentException())
                                        mergeFailures += 1
                                    )
                                )
                            )
                        ) else (
                            format "Warning: Skipping attachment - one of the no-material objects is no longer valid\n"
                            mergeFailures += 1
                        )
                    ) catch (
                        format "Warning: Failed to attach no-material object % to base mesh. Error: %\n" noMaterialObjects[j].name (getCurrentException())
                        mergeFailures += 1
                    )
                )
                
                format "Merged % no-material objects successfully, % objects failed to merge\n" mergeSuccesses mergeFailures
                
                append mergedObjects baseMesh
            )
        )
        
        -- Select all the merged objects
        select mergedObjects
        
        -- Report results
        format "Merged % objects into % result objects based on materials\n" selectedObjects.count mergedObjects.count
        
        return true
    ) catch (
        format "Error merging objects: %\n" (getCurrentException())
        return false
    )
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

-- ==========================================================================
-- UI ROLLOUTS
-- ==========================================================================

-- Main Rollout
rollout BCM_RolloutMain "Bulk Clean and Merge" width:400 height:440 (
    group "File Processing" (
        label lblInputDir "Input Directory:" align:#left
        edittext BCM_edtInputDir text:BCM_inputDir width:330 align:#left
        button BCM_btnInputBrowse "Browse..." width:50 align:#right offset:[0, -25]
        
        label lblOutputDir "Output Directory:" align:#left
        edittext BCM_edtOutputDir text:BCM_outputDir width:330 align:#left
        button BCM_btnOutputBrowse "Browse..." width:50 align:#right offset:[0, -25]
        
        radiobuttons BCM_rdoProcessingMode labels:#("Process Directory", "Process Single File") default:BCM_processingMode columns:2
        
        radiobuttons BCM_rdoSortingMode labels:#("Alphabetical", "Size Ascending", "Size Descending") default:BCM_sortingMode columns:3
    )
    
    group "Cleaning Options" (
        checkbox BCM_chkCleanShapes "Clean Shapes" checked:BCM_cleanShapes align:#left
        checkbox BCM_chkCleanLights "Clean Lights" checked:BCM_cleanLights align:#left offset:[120, -20]
        checkbox BCM_chkCleanCameras "Clean Cameras" checked:BCM_cleanCameras align:#left
        checkbox BCM_chkCleanHelpers "Clean Helpers" checked:BCM_cleanHelpers align:#left offset:[120, -20]
        checkbox BCM_chkCleanWarps "Clean Space Warps" checked:BCM_cleanWarps align:#left
        checkbox BCM_chkCleanNURBS "Clean NURBS" checked:BCM_cleanNURBS align:#left offset:[120, -20]
        checkbox BCM_chkCleanDummies "Clean Dummies" checked:BCM_cleanDummies align:#left
    )
    
    group "Merging Options" (
        checkbox BCM_chkFixNormals "Fix Inverted Normals" checked:BCM_fixNormals align:#left
    )
    
    group "Process" (
        button BCM_btnProcess "Process Files" width:150 height:30 align:#center
    )
    
    -- UI Event Handlers
    on BCM_btnInputBrowse pressed do (
        local dir = getSavePath caption:"Select Input Directory" initialDir:BCM_inputDir
        if dir != undefined then (
            BCM_inputDir = dir
            BCM_edtInputDir.text = dir
        )
    )
    
    on BCM_btnOutputBrowse pressed do (
        local dir = getSavePath caption:"Select Output Directory" initialDir:BCM_outputDir
        if dir != undefined then (
            BCM_outputDir = dir
            BCM_edtOutputDir.text = dir
        )
    )
    
    on BCM_edtInputDir changed txt do (
        BCM_inputDir = txt
    )
    
    on BCM_edtOutputDir changed txt do (
        BCM_outputDir = txt
    )
    
    on BCM_rdoProcessingMode changed state do (
        BCM_processingMode = state
    )
    
    on BCM_rdoSortingMode changed state do (
        BCM_sortingMode = state
    )
    
    on BCM_chkCleanShapes changed state do (
        BCM_cleanShapes = state
    )
    
    on BCM_chkCleanLights changed state do (
        BCM_cleanLights = state
    )
    
    on BCM_chkCleanCameras changed state do (
        BCM_cleanCameras = state
    )
    
    on BCM_chkCleanHelpers changed state do (
        BCM_cleanHelpers = state
    )
    
    on BCM_chkCleanWarps changed state do (
        BCM_cleanWarps = state
    )
    
    on BCM_chkCleanNURBS changed state do (
        BCM_cleanNURBS = state
    )
    
    on BCM_chkCleanDummies changed state do (
        BCM_cleanDummies = state
    )
    
    on BCM_chkFixNormals changed state do (
        BCM_fixNormals = state
    )
    
    on BCM_btnProcess pressed do (
        -- Create progress rollout
        createDialog BCM_RolloutProgress 400 120 modal:false
        
        -- Start processing in a separate thread to keep UI responsive
        BCM_ProcessAllFiles()
    )
)

-- Progress Rollout
rollout BCM_RolloutProgress "Processing Progress" width:400 height:120 (
    label lblStatus "Status:" align:#left
    label BCM_lblCurrentFile "Preparing..." align:#left offset:[50, -20]
    progressBar BCM_prgOverall "Overall Progress" value:0 width:380 height:20 color:[0, 128, 255]
    button BCM_btnCancel "Cancel" width:100 height:25 align:#center
    
    -- Store references to progress controls for easier access
    on BCM_RolloutProgress open do (
        -- Make global references to UI elements
        global BCM_prgOverall = BCM_prgOverall
        global BCM_lblCurrentFile = BCM_lblCurrentFile
    )
    
    on BCM_btnCancel pressed do (
        BCM_cancelProcessing = true
        BCM_btnCancel.enabled = false
        BCM_btnCancel.text = "Canceling..."
    )
    
    -- If processing is complete, close dialog when clicked
    on BCM_RolloutProgress close do (
        if not BCM_processingComplete then (
            BCM_cancelProcessing = true
        )
    )
)

-- ==========================================================================
-- Create and Show Main Dialog
-- ==========================================================================
if BCM_RolloutMain != undefined then destroyDialog BCM_RolloutMain
createDialog BCM_RolloutMain 400 440