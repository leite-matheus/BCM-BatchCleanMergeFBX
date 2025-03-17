/*
 * Improved Merge Geometries by Material
 * This script merges 3D objects based on shared materials, handling identically named materials
 * Usage: Select objects you want to merge and run the script
 */

fn improvedMergeByMaterial = 
(
	-- Store the original selection
	local selectedObjects = getCurrentSelection()
	
	-- Check if anything is selected
	if selectedObjects.count == 0 then
	(
		messageBox "Please select some objects to merge." title:"No Selection"
		return false
	)
	
	-- Create a dictionary to group objects by material name
	local materialGroups = #()
	local materialNames = #()
	
	-- Group objects by material name instead of material instance
	for obj in selectedObjects do
	(
		-- Skip non-geometry objects
		if not superClassOf obj == GeometryClass then continue
		
		-- Skip objects with no material
		if obj.material == undefined then continue
		
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
		messageBox "No valid objects with materials found in selection." title:"Nothing to Merge"
		return false
	)
	
	-- Display a simple progress message to user
	local startTime = timestamp()
	format "Starting merge process for % material groups...\n" numGroups
	
	-- Process each material group
	local mergedObjects = #()
	
	for i = 1 to numGroups do
	(
		local objGroup = materialGroups[i]
		local matName = materialNames[i]
		
		format "Processing material group % of % (%): % objects\n" i numGroups matName objGroup.count
		
		-- Only merge if there's at least one object with this material
		if objGroup.count >= 1 then
		(
			-- Store the first object's material to use for the merged object
			-- This ensures we're using a single material instance
			local groupMaterial = objGroup[1].material
			
			-- Apply this material to all objects in the group to ensure consistency
			-- This step addresses the issue with multiple instances of identically named materials
			for obj in objGroup do
			(
				obj.material = groupMaterial
			)
			
			-- Get the material name for the merged object name
			local mergedName = "Merged_" + matName
			
			-- If there's only one object, no need to merge
			if objGroup.count == 1 then
			(
				objGroup[1].name = mergedName
				append mergedObjects objGroup[1]
			)
			else
			(
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
	
	-- Calculate time taken
	local endTime = timestamp()
	local totalTime = (endTime - startTime) / 1000.0
	
	-- Select all the merged objects
	select mergedObjects
	
	-- Report results
	local resultMessage = "Merged " + selectedObjects.count as string + " objects into " + mergedObjects.count as string + " result objects based on materials.\n"
	resultMessage += "Process completed in " + totalTime as string + " seconds."
	
	messageBox resultMessage title:"Merge Complete"
	format "%\n" resultMessage
	
	return true
)

-- Execute the function
improvedMergeByMaterial()