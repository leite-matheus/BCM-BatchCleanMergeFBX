-- Delete All Shapes, Lights, Cameras, Helpers, Warps, NURBS and Dummy Objects
-- This script will select and delete all shapes, lights, cameras, helpers, warp objects, NURBS, and dummy objects in the scene

-- Create undo point
undo "Delete All Objects" on (
    clearSelection()
    local objectsToDelete = #()
    
    -- Get all objects in the scene
    local allObjects = objects
    local deletedCount = 0
    
    -- Filter objects by class
    for obj in allObjects do (
        if (classOf obj == GeometryClass) or \
           (classOf obj == Shape) or \
           (classOf obj == Light) or \
           (classOf obj == Camera) or \
           (classOf obj == Helper) or \
           (classOf obj == SpaceWarp) or \
           (classOf obj == NURBSCurve) or \
           (classOf obj == Dummy) or \
           (superClassOf obj == Shape) or \
           (findString (classOf obj as string) "NURBS" != undefined) then (
            append objectsToDelete obj
        )
    )
    
    -- If objects found, select and delete them
    if objectsToDelete.count > 0 then (
        select objectsToDelete
        delete selection
        deletedCount = objectsToDelete.count
        format "Deleted % objects\n" deletedCount
    ) else (
        format "No objects found to delete\n"
    )
    
    -- Get any remaining objects that might be NURBS-related or special helpers
    objectsToDelete = #()
    allObjects = objects
    
    -- Second pass looking for any NURBS objects or special helper objects by name
    for obj in allObjects do (
        local className = classOf obj as string
        if (findString className "NURBS" != undefined) or \
           (className == "NURBSSurface") or \
           (className == "NURBSCVCurve") or \
           (className == "NURBSPointCurve") or \
           (className == "Dummy") or \
           (className == "Point") or \
           (superClassOf obj == helper) then (
            append objectsToDelete obj
        )
    )
    
    -- Delete any remaining special objects
    if objectsToDelete.count > 0 then (
        select objectsToDelete
        delete selection
        deletedCount += objectsToDelete.count
        format "Deleted % additional special objects\n" objectsToDelete.count
    )
    
    -- Refresh viewport
    redrawViews()
    
    format "Total objects deleted: %\n" deletedCount
    format "Operation completed\n"
)