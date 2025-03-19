/*
 * Material-based Merge Module
 * Merges objects by material in optimal batches to manage memory
 */

-- Reference to the global updateProgress function
global updateProgress

fn mergeByMaterial inputObjects = (
    -- If no objects passed, use current selection
    local selectedObjects = if inputObjects != undefined then inputObjects else getCurrentSelection()
    
    -- Check if anything is selected
    if selectedObjects.count == 0 then (
        messageBox "No objects available for merging. Run cleanup first or manually select objects." title:"No Selection"
        return false
    )
    
    -- Create progress dialog rollout
    local progressDialog = rollout progressDialog "Merge Progress" width:400 height:100 (
        progressBar pbMerge "Progress" pos:[10,10] width:380 height:20 value:0 color:(color 0 128 255)
        label lblStatus "Initializing..." pos:[10,40] width:380 height:30
        
        -- Flag dialog as created
        local created = true
    )
    
    -- Try to destroy existing dialog first
    try (destroyDialog progressDialog) catch()
    
    -- Create the dialog
    createDialog progressDialog
    
    -- Create arrays to group objects by material name 
    local materialNames = #()
    local materialGroups = #()
    local validObjectCount = 0
    
    -- Group objects by material name with pre-filtering of invalid objects
    for obj in selectedObjects do (
        -- Skip non-geometry objects and objects with no material immediately
        if (not superClassOf obj == GeometryClass) or (obj.material == undefined) then continue
        
        validObjectCount += 1
        local matName = obj.material.name
        
        -- Find index of this material name
        local index = findItem materialNames matName
        
        if index == 0 then (
            -- New material name found
            append materialNames matName
            append materialGroups #(obj)
        ) else (
            -- Add to existing material group
            append materialGroups[index] obj
        )
        
        -- Force garbage collection periodically to free memory
        if (mod validObjectCount 100) == 0 then gc()
    )
    
    -- Count how many groups we found
    local numGroups = materialGroups.count
    
    if numGroups == 0 then (
        messageBox "No valid objects with materials found in selection." title:"Nothing to Merge"
        try (destroyDialog progressDialog) catch()
        return false
    )
    
    -- Set default batch size for chunk processing
    local batchSize = 25
    
    -- Allow user to configure batch size for very large scenes
    if validObjectCount > 1000 then (
        local batchSizeResponse = inputBox "Enter batch size for processing (smaller = less memory used but slower):" "25" title:"Configure Processing"
        if batchSizeResponse != undefined then (
            try (
                batchSize = batchSizeResponse as integer
                if batchSize < 5 then batchSize = 5
                if batchSize > 100 then batchSize = 100
            ) catch (
                batchSize = 25
            )
        )
    )
    
    -- Display a simple progress message to user
    local startTime = timestamp()
    format "Starting merge process for % material groups using batch size of %...\n" numGroups batchSize
    
    -- Process each material group
    local mergedObjects = #()
    local logMessages = #()
    
    for i = 1 to numGroups do (
        -- Update progress dialog
        local percent = 100.0 * i / numGroups
        updateProgress progressDialog percent ("Processing material group " + i as string + " of " + numGroups as string)
        
        local matName = materialNames[i]
        local objGroup = materialGroups[i]
        
        format "Processing material group % of % (%): % objects\n" i numGroups matName objGroup.count
        append logMessages ("Group " + i as string + ": " + matName + " - " + objGroup.count as string + " objects")
        
        -- Only merge if there's at least one object with this material
        if objGroup.count >= 1 then (
            -- Store the first object's material
            local groupMaterial = objGroup[1].material
            local mergedName = "Merged_" + matName
            
            -- If there's only one object, no need to merge
            if objGroup.count == 1 then (
                objGroup[1].name = mergedName
                append mergedObjects objGroup[1]
            ) else (
                -- Always use batch processing regardless of group size
                local baseMesh = objGroup[1]
                select baseMesh
                
                -- Convert base mesh to Editable_Poly
                if classOf baseMesh != Editable_Poly then (
                    convertTo baseMesh Editable_Poly
                )
                
                -- Calculate number of batches needed
                local numBatches = ceil((objGroup.count - 1) / batchSize as float)
                
                for batchNum = 1 to numBatches do (
                    -- Calculate start and end indices for this batch
                    local startIdx = (batchNum - 1) * batchSize + 2
                    local endIdx = if (startIdx + batchSize - 1) < objGroup.count then (startIdx + batchSize - 1) else objGroup.count
                    
                    -- Update batch progress
                    local batchProgress = percent + (100.0 / numGroups * batchNum / numBatches)
                    updateProgress progressDialog batchProgress ("Material " + i as string + "/" + numGroups as string + " - Batch " + batchNum as string + "/" + numBatches as string)
                    
                    -- Show batch info in listener
                    format "  Processing batch % of % (objects % to %)\n" batchNum numBatches startIdx endIdx
                    
                    -- Process this batch
                    for j = startIdx to endIdx do (
                        try (
                            polyop.attach baseMesh objGroup[j]
                        )
                        catch (
                            local errorMsg = "Warning: Failed to attach object " + objGroup[j].name
                            format "%\n" errorMsg
                            append logMessages ("  - " + errorMsg)
                        )
                    )
                    
                    -- Force garbage collection after each batch
                    gc()
                    
                    -- Allow UI to update
                    windows.processPostedMessages()
                )
                
                -- Rename and apply material
                baseMesh.name = mergedName
                baseMesh.material = groupMaterial
                append mergedObjects baseMesh
            )
        )
        
        -- Force garbage collection after each material group
        gc()
    )
    
    -- Calculate time taken
    local endTime = timestamp()
    local totalTime = (endTime - startTime) / 1000.0
    
    -- Close progress dialog
    try (destroyDialog progressDialog) catch()
    
    -- Select all the merged objects
    select mergedObjects
    
    -- Report results
    local resultMessage = "Merged " + validObjectCount as string + " objects into " + mergedObjects.count as string + " result objects.\n"
    resultMessage += "Process completed in " + totalTime as string + " seconds using batch size of " + batchSize as string + "."
    
    messageBox resultMessage title:"Merge Complete"
    format "%\n" resultMessage
    
    -- Write log to MAXScript listener
    format "\n--- Merge Log ---\n"
    for msg in logMessages do format "% \n" msg
    format "---------------\n"
    
    return true
)