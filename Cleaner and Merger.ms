/*
 * Scene Optimizer Tool
 * Combined functionality for scene cleaning and merging by material
 * Provides a unified interface for optimizing 3ds Max scenes
 * 
 * Features:
 * - Scene cleaning (remove non-geometry objects)
 * - Merge objects by material
 * - Fix inverted normals
 * - Selection or scene-wide operations
 * - Progress tracking and detailed feedback
 */

-- Global configuration variables
global gSceneOptimizerRollout
global gSceneOptimizerFloater
global gProcessingSelection = true
global gCleanTypes = #(true, true, true, true, true, true) -- Shapes, Lights, Cameras, Helpers, SpaceWarps, NURBS
global gMergeSettings = #(true, false) -- Use material name, Keep original objects
global gNormalSettings = #(true, 80.0) -- Fix inverted normals, Angle threshold

-- Utility functions
fn logMessage msg = 
(
    format "%\n" msg
    if gSceneOptimizerRollout != undefined and gSceneOptimizerRollout.statusLog != undefined then
    (
        gSceneOptimizerRollout.statusLog.text = msg + "\n" + gSceneOptimizerRollout.statusLog.text
    )
)

fn updateProgress value =
(
    if gSceneOptimizerRollout != undefined and gSceneOptimizerRollout.progressBar != undefined then
    (
        gSceneOptimizerRollout.progressBar.value = value
    )
)

fn getObjectsToProcess = 
(
    if gProcessingSelection then 
        getCurrentSelection() 
    else 
        objects
)

-- Scene Cleaning Function
fn cleanScene = 
(
    undo "Clean Scene" on
    (
        try
        (
            local objectsToProcess = getObjectsToProcess()
            if objectsToProcess.count == 0 then
            (
                logMessage "No objects found to process."
                return false
            )
            
            logMessage ("Processing " + objectsToProcess.count as string + " objects...")
            
            local objectsToDelete = #()
            local deletedCount = 0
            
            -- Collection pass - gather objects to delete based on settings
            for i = 1 to objectsToProcess.count do
            (
                local obj = objectsToProcess[i]
                updateProgress (100.0 * i / objectsToProcess.count)
                
                local shouldDelete = false
                
                -- Check object type based on user selections
                if gCleanTypes[1] and (superClassOf obj == Shape or classOf obj == Shape) then shouldDelete = true
                if gCleanTypes[2] and (superClassOf obj == Light or classOf obj == Light) then shouldDelete = true
                if gCleanTypes[3] and (superClassOf obj == Camera or classOf obj == Camera) then shouldDelete = true
                if gCleanTypes[4] and (superClassOf obj == Helper or classOf obj == Helper) then shouldDelete = true
                if gCleanTypes[5] and (superClassOf obj == SpaceWarp or classOf obj == SpaceWarp) then shouldDelete = true
                if gCleanTypes[6] and ((classOf obj == NURBSCurve) or (findString (classOf obj as string) "NURBS" != undefined)) then shouldDelete = true
                
                -- Add to delete list if it matches criteria
                if shouldDelete then 
                    append objectsToDelete obj
            )
            
            -- Deletion pass
            if objectsToDelete.count > 0 then
            (
                select objectsToDelete
                delete selection
                deletedCount = objectsToDelete.count
                logMessage ("Deleted " + deletedCount as string + " objects")
            )
            else
            (
                logMessage "No objects found matching the deletion criteria"
            )
            
            -- Reset progress bar
            updateProgress 0
            redrawViews()
            return true
        )
        catch
        (
            local errorMsg = "Error during scene cleaning: " + (getCurrentException())
            logMessage errorMsg
            return false
        )
    )
)

-- Fix Inverted Normals Function
fn fixInvertedNormals angleThreshold:80.0 =
(
    undo "Fix Inverted Normals" on
    (
        try
        (
            local objectsToProcess = getObjectsToProcess()
            local fixedObjects = 0
            local processedObjects = 0
            local thresholdAngle = angleThreshold
            
            logMessage ("Checking normals for " + objectsToProcess.count as string + " objects...")
            
            for i = 1 to objectsToProcess.count do
            (
                local obj = objectsToProcess[i]
                updateProgress (100.0 * i / objectsToProcess.count)
                
                -- Only process mesh and poly objects
                if (classOf obj == Editable_Mesh) or (classOf obj == Editable_Poly) then
                (
                    processedObjects += 1
                    
                    -- For mesh objects
                    if classOf obj == Editable_Mesh then
                    (
                        -- Count faces with normals exceeding threshold angle
                        local invertedFaces = 0
                        local faceCount = getNumFaces obj
                        
                        for f = 1 to faceCount do
                        (
                            local faceNormal = getFaceNormal obj f
                            local faceCenter = meshop.getFaceCenter obj f
                            local viewDirection = normalize(faceCenter - (getViewMatrix()).translation)
                            local angle = acos(dot faceNormal viewDirection)
                            
                            if angle > thresholdAngle then
                                invertedFaces += 1
                        )
                        
                        -- If more than 50% faces appear inverted, flip normals
                        if (invertedFaces > (faceCount * 0.5)) then
                        (
                            meshop.flipNormals obj #{1..faceCount}
                            fixedObjects += 1
                            logMessage ("Fixed normals on: " + obj.name)
                        )
                    )
                    -- For poly objects
                    else if classOf obj == Editable_Poly then
                    (
                        -- Count faces with normals exceeding threshold angle
                        local invertedFaces = 0
                        local faceCount = polyop.getNumFaces obj
                        
                        for f = 1 to faceCount do
                        (
                            local faceNormal = polyop.getFaceNormal obj f
                            local faceCenter = polyop.getFaceCenter obj f
                            local viewDirection = normalize(faceCenter - (getViewMatrix()).translation)
                            local angle = acos(dot faceNormal viewDirection)
                            
                            if angle > thresholdAngle then
                                invertedFaces += 1
                        )
                        
                        -- If more than 50% faces appear inverted, flip normals
                        if (invertedFaces > (faceCount * 0.5)) then
                        (
                            polyop.flipNormals obj #{1..faceCount}
                            fixedObjects += 1
                            logMessage ("Fixed normals on: " + obj.name)
                        )
                    )
                )
            )
            
            logMessage ("Processed " + processedObjects as string + " mesh objects. Fixed " + fixedObjects as string + " objects with inverted normals.")
            updateProgress 0
            return true
        )
        catch
        (
            local errorMsg = "Error during normal fixing: " + (getCurrentException())
            logMessage errorMsg
            return false
        )
    )
)

-- Merge by Material Function
fn mergeByMaterial keepOriginals:false =
(
    undo "Merge by Material" on
    (
        try
        (
            -- Store the original selection
            local objectsToProcess = getObjectsToProcess()
            
            -- Check if anything is selected
            if objectsToProcess.count == 0 then
            (
                logMessage "No objects found to process."
                return false
            )
            
            -- Create arrays to group objects by material name
            local materialGroups = #()
            local materialNames = #()
            local objectsWithoutMaterial = #()
            local geometryCount = 0
            
            logMessage ("Analyzing materials for " + objectsToProcess.count as string + " objects...")
            
            -- First pass: analyze and group objects
            for i = 1 to objectsToProcess.count do
            (
                local obj = objectsToProcess[i]
                updateProgress (50.0 * i / objectsToProcess.count) -- First 50% for analysis
                
                -- Skip non-geometry objects
                if not superClassOf obj == GeometryClass then continue
                
                geometryCount += 1
                
                -- Handle objects with no material
                if obj.material == undefined then
                (
                    append objectsWithoutMaterial obj
                    continue
                )
                
                local matName = obj.material.name
                local index = findItem materialNames matName
                
                if index == 0 then
                (
                    -- New material name found
                    append materialNames matName
                    append materialGroups #(obj)
                )
                else
                (
                    -- Add to existing material group
                    append materialGroups[index] obj
                )
            )
            
            -- Count how many groups we found
            local numGroups = materialGroups.count
            
            if numGroups == 0 then
            (
                if objectsWithoutMaterial.count > 0 then
                    logMessage ("Found " + objectsWithoutMaterial.count as string + " objects without materials. No objects with materials to merge.")
                else
                    logMessage "No valid objects with materials found to merge."
                return false
            )
            
            -- Report initial analysis
            logMessage ("Found " + numGroups as string + " material groups among " + geometryCount as string + " geometry objects.")
            if objectsWithoutMaterial.count > 0 then
                logMessage ("Note: " + objectsWithoutMaterial.count as string + " objects have no materials and will not be merged.")
            
            -- Process each material group
            local mergedObjects = #()
            local originals = #()
            
            for i = 1 to numGroups do
            (
                local objGroup = materialGroups[i]
                local matName = materialNames[i]
                
                updateProgress (50 + (50.0 * i / numGroups)) -- Second 50% for merging
                
                logMessage ("Processing material group " + i as string + " of " + numGroups as string + " (" + matName + "): " + objGroup.count as string + " objects")
                
                -- Only merge if there's more than one object with this material
                if objGroup.count > 1 then
                (
                    -- Store the first object's material to use for the merged object
                    local groupMaterial = objGroup[1].material
                    
                    -- Store originals if requested
                    if keepOriginals then
                    (
                        for obj in objGroup do
                        (
                            maxOps.cloneNodes #(obj) cloneType:#copy newNodes:&clonedNodes
                            for clone in clonedNodes do
                            (
                                clone.name = clone.name + "_orig"
                                append originals clone
                            )
                        )
                    )
                    
                    -- Apply this material to all objects in the group to ensure consistency
                    for obj in objGroup do
                    (
                        obj.material = groupMaterial
                    )
                    
                    -- Get the material name for the merged object name
                    local mergedName = "Merged_" + matName
                    
                    -- Perform the attach operation
                    local baseMesh = objGroup[1]
                    select baseMesh
                    
                    -- Attach all other objects to the base mesh
                    for j = 2 to objGroup.count do
                    (
                        try
                        (
                            -- Use Edit_Mesh modifier for meshes
                            if classOf baseMesh == Editable_Mesh then
                            (
                                modPanel.addModToSelection (Edit_Mesh()) ui:off
                                meshop.attach baseMesh objGroup[j] attachMat:#idToMat
                            )
                            -- Use Edit_Poly modifier for poly objects
                            else if classOf baseMesh == Editable_Poly then
                            (
                                modPanel.addModToSelection (Edit_Poly()) ui:off
                                polyop.attach baseMesh objGroup[j]
                            )
                            -- For other geometry types
                            else
                            (
                                convertTo baseMesh Editable_Mesh
                                modPanel.addModToSelection (Edit_Mesh()) ui:off
                                meshop.attach baseMesh objGroup[j] attachMat:#idToMat
                            )
                        )
                        catch
                        (
                            logMessage ("Warning: Failed to attach object " + objGroup[j].name + " to base mesh. Error: " + (getCurrentException()))
                        )
                    )
                    
                    -- Rename the resulting object
                    baseMesh.name = mergedName
                    
                    -- Make sure the material is applied correctly
                    baseMesh.material = groupMaterial
                    
                    -- Add to our results array
                    append mergedObjects baseMesh
                )
                else
                (
                    -- Just one object with this material, no merging needed
                    logMessage ("Skipping material " + matName + ": only one object")
                    append mergedObjects objGroup[1]
                )
            )
            
            -- Select all the merged objects
            select mergedObjects
            
            -- If keeping originals, hide them
            if keepOriginals and originals.count > 0 then
            (
                for obj in originals do obj.isHidden = true
                logMessage ("Created " + originals.count as string + " backup copies (hidden)")
            )
            
            -- Report results
            logMessage ("Merged objects into " + mergedObjects.count as string + " result objects based on materials.")
            updateProgress 0
            return true
        )
        catch
        (
            local errorMsg = "Error during merge operation: " + (getCurrentException())
            logMessage errorMsg
            return false
        )
    )
)

-- Run all optimization steps
fn runFullOptimization = 
(
    logMessage "=== Starting Full Scene Optimization ==="
    
    if gNormalSettings[1] then
    (
        logMessage "--- Step 1: Fix Inverted Normals ---"
        fixInvertedNormals angleThreshold:gNormalSettings[2]
    )
    
    logMessage "--- Step 2: Clean Scene ---"
    cleanScene()
    
    logMessage "--- Step 3: Merge By Material ---"
    mergeByMaterial keepOriginals:(gMergeSettings[2])
    
    logMessage "=== Scene Optimization Complete ==="
)

-- User Interface
rollout gSceneOptimizerRollout "Scene Optimizer" width:400 height:560
(
    -- Main groupboxes
    groupBox grpMode "Operation Mode" pos:[10,10] width:380 height:60
    groupBox grpClean "Scene Cleaning Options" pos:[10,80] width:380 height:120
    groupBox grpNormals "Normal Fixing Options" pos:[10,210] width:380 height:80
    groupBox grpMerge "Merge Options" pos:[10,300] width:380 height:80
    groupBox grpExecute "Execute" pos:[10,390] width:380 height:80
    groupBox grpStatus "Status" pos:[10,480] width:380 height:70
    
    -- Mode selection
    radioButtons rdoMode "Process:" pos:[20,30] width:360 height:30 labels:#("Selected Objects Only", "All Scene Objects") default:1
    
    -- Clean options
    checkBox chkShapes "Shapes" pos:[20,100] width:80 height:20 checked:true
    checkBox chkLights "Lights" pos:[105,100] width:80 height:20 checked:true
    checkBox chkCameras "Cameras" pos:[190,100] width:80 height:20 checked:true
    checkBox chkHelpers "Helpers" pos:[20,125] width:80 height:20 checked:true
    checkBox chkWarps "SpaceWarps" pos:[105,125] width:80 height:20 checked:true
    checkBox chkNURBS "NURBS" pos:[190,125] width:80 height:20 checked:true
    button btnClean "Clean Scene Now" pos:[20,155] width:360 height:30
    
    -- Normal options
    checkBox chkFixNormals "Fix Inverted Normals" pos:[20,230] width:150 height:20 checked:true
    spinner spnAngle "Angle Threshold:" pos:[180,230] width:120 height:20 range:[0,180,80] type:#float
    button btnFixNormals "Fix Normals Now" pos:[20,255] width:360 height:25
    
    -- Merge options
    checkBox chkKeepOriginals "Keep Original Objects (Hidden)" pos:[20,320] width:200 height:20 checked:false
    button btnMerge "Merge by Material Now" pos:[20,345] width:360 height:25
    
    -- Execute all button
    button btnRunAll "Run Full Optimization" pos:[20,415] width:360 height:45
    
    -- Status and progress
    editText statusLog "" pos:[20,500] width:360 height:40 readOnly:true
    progressBar progressBar "" pos:[20,545] width:360 height:15 value:0
    
    -- Event handlers
    on rdoMode changed state do
    (
        gProcessingSelection = (state == 1)
    )
    
    on chkShapes changed state do gCleanTypes[1] = state
    on chkLights changed state do gCleanTypes[2] = state
    on chkCameras changed state do gCleanTypes[3] = state
    on chkHelpers changed state do gCleanTypes[4] = state
    on chkWarps changed state do gCleanTypes[5] = state
    on chkNURBS changed state do gCleanTypes[6] = state
    
    on chkFixNormals changed state do gNormalSettings[1] = state
    on spnAngle changed val do gNormalSettings[2] = val
    
    on chkKeepOriginals changed state do gMergeSettings[2] = state
    
    on btnClean pressed do
    (
        statusLog.text = ""
        cleanScene()
    )
    
    on btnFixNormals pressed do
    (
        statusLog.text = ""
        fixInvertedNormals angleThreshold:spnAngle.value
    )
    
    on btnMerge pressed do
    (
        statusLog.text = ""
        mergeByMaterial keepOriginals:chkKeepOriginals.checked
    )
    
    on btnRunAll pressed do
    (
        statusLog.text = ""
        runFullOptimization()
    )
)

-- Create dialog
if gSceneOptimizerFloater != undefined then closeRolloutFloater gSceneOptimizerFloater
gSceneOptimizerFloater = newRolloutFloater "Scene Optimizer" 420 580
addRollout gSceneOptimizerRollout gSceneOptimizerFloater

-- Show initial status message
logMessage "Scene Optimizer loaded. Select operation mode and options, then click a button to perform operations."