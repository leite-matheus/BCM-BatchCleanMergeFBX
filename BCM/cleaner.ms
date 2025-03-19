/*
 * Scene Cleaner Module
 * Deletes all unnecessary objects and returns remaining geometry
 */

fn deleteAllUnwantedObjects = (
    -- Create undo point
    undo "Delete All Objects" on (
        clearSelection()
        local objectsToDelete = #()
        local remainingGeometry = #()
        
        -- Get all objects in the scene
        local allObjects = objects
        local deletedCount = 0
        
        -- First pass: identify objects to delete and objects to keep
        for obj in allObjects do (
            local shouldDelete = (
                classOf obj == Light or \
                classOf obj == Camera or \
                classOf obj == Helper or \
                classOf obj == SpaceWarp or \
                classOf obj == NURBSCurve or \
                classOf obj == Dummy or \
                classOf obj == Point or \
                classOf obj == Subentity or \
                (superClassOf obj == Shape and classOf obj != Editable_Poly and classOf obj != Editable_Mesh) or \
                (findString (classOf obj as string) "NURBS" != undefined)
            )
            
            if shouldDelete then (
                append objectsToDelete obj
            ) else if (superClassOf obj == GeometryClass) then (
                append remainingGeometry obj
            )
        )
        
        -- Delete unnecessary objects
        if objectsToDelete.count > 0 then (
            select objectsToDelete
            delete selection
            deletedCount = objectsToDelete.count
            format "Deleted % unnecessary objects\n" deletedCount
        )
        
        -- Refresh viewport
        redrawViews()
        
        -- Select remaining geometry for merging
        if remainingGeometry.count > 0 then (
            select remainingGeometry
            format "Selected % geometry objects for merging\n" remainingGeometry.count
        ) else (
            format "No geometry objects found to merge\n"
        )
        
        remainingGeometry
    )
)