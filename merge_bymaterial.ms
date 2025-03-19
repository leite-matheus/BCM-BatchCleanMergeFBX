/*
 * Simplified Merge Geometries by Material
 * This script merges 3D objects based on shared materials with improved memory management
 * Optimized for large scenes to prevent freezing and excessive memory usage
 * Uses minimal UI elements to avoid potential crashes
 */

fn simplifiedMergeByMaterial = 
(
	-- Declare progress dialog as a local variable within the function
	local progressDialog = undefined
	
	-- This function will update the progress dialog if it exists
	fn updateProgress progressDialog percent statusText =
	(
		if progressDialog != undefined and progressDialog.created then
		(
			try
			(
				progressDialog.pbMerge.value = percent
				progressDialog.lblStatus.text = statusText
				windows.processPostedMessages()
			)
			catch ()
		)
	)
	
	-- Store the original selection
	local selectedObjects = getCurrentSelection()
	
	-- Check if anything is selected
	if selectedObjects.count == 0 then
	(
		messageBox "Please select some objects to merge." title:"No Selection"
		return false
	)
	
	-- Create arrays to group objects by material name 
	-- Using arrays instead of dictionary for maximum compatibility
	local materialNames = #()
	local materialGroups = #()
	local validObjectCount = 0
	
	-- Group objects by material name with pre-filtering of invalid objects
	for obj in selectedObjects do
	(
		-- Skip non-geometry objects and objects with no material immediately
		if (not superClassOf obj == GeometryClass) or (obj.material == undefined) then continue
		
		validObjectCount += 1
		local matName = obj.material.name
		
		-- Find index of this material name
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
		
		-- Force garbage collection periodically to free memory
		if (mod validObjectCount 100) == 0 then gc()
	)
	
	-- Count how many groups we found
	local numGroups = materialGroups.count
	
	if numGroups == 0 then
	(
		messageBox "No valid objects with materials found in selection." title:"Nothing to Merge"
		return false
	)
	
	-- Ask user about batch size preference for very large scenes
	local batchSize = 50
	local processingType = 1
	
	if validObjectCount > 1000 then
	(
		local response = queryBox "Large scene detected with " + validObjectCount as string + " objects.\nProcess in batches to reduce memory usage?" title:"Performance Options"
		
		if response then processingType = 2
	)
	
	-- Display a simple progress message to user
	local startTime = timestamp()
	format "Starting merge process for % material groups...\n" numGroups
	
	-- Create simple progress dialog rollout
	rollout progressDialog "Merge Progress" width:400 height:100
	(
		progressBar pbMerge "Progress" pos:[10,10] width:380 height:20 value:0 color:(color 0 128 255)
		label lblStatus "Initializing..." pos:[10,40] width:380 height:30
		
		-- Flag dialog as created
		local created = true
	)
	
	-- Try to destroy existing dialog first
	try (destroyDialog progressDialog) catch()
	
	-- Create the dialog
	createDialog progressDialog
	
	-- Process each material group
	local mergedObjects = #()
	local logMessages = #()
	
	for i = 1 to numGroups do
	(
		-- Update progress dialog
		local percent = 100.0 * i / numGroups
		updateProgress progressDialog percent ("Processing material group " + i as string + " of " + numGroups as string)
		
		local matName = materialNames[i]
		local objGroup = materialGroups[i]
		
		format "Processing material group % of % (%): % objects\n" i numGroups matName objGroup.count
		append logMessages ("Group " + i as string + ": " + matName + " - " + objGroup.count as string + " objects")
		
		-- Only merge if there's at least one object with this material
		if objGroup.count >= 1 then
		(
			-- Store the first object's material
			local groupMaterial = objGroup[1].material
			local mergedName = "Merged_" + matName
			
			-- If there's only one object, no need to merge
			if objGroup.count == 1 then
			(
				objGroup[1].name = mergedName
				append mergedObjects objGroup[1]
			)
			else
			(
				-- Batch processing for large groups
				if processingType == 2 and objGroup.count > batchSize then
				(
					-- Simple copy first object approach
					local baseMesh = objGroup[1]
					select baseMesh
					
					-- Convert base mesh to Editable_Poly
					if classOf baseMesh != Editable_Poly then
					(
						convertTo baseMesh Editable_Poly
					)
					
					-- Process in batches
					local numBatches = ceil((objGroup.count - 1) / batchSize as float)
					
					for batchNum = 1 to numBatches do
					(
						-- Calculate start and end indices for this batch
						local startIdx = (batchNum - 1) * batchSize + 2
						local endIdx = min (startIdx + batchSize - 1) objGroup.count
						
						-- Update batch progress
						updateProgress progressDialog percent ("Batch " + batchNum as string + " of " + numBatches as string)
						
						-- Process this batch
						for j = startIdx to endIdx do
						(
							try
							(
								polyop.attach baseMesh objGroup[j]
							)
							catch
							(
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
				else -- Standard processing for smaller groups
				(
					local baseMesh = objGroup[1]
					select baseMesh
					
					-- Convert to Editable_Poly for better performance
					if classOf baseMesh != Editable_Poly then
					(
						convertTo baseMesh Editable_Poly
					)
					
					-- Attach all other objects to the base mesh
					for j = 2 to objGroup.count do
					(
						try
						(
							polyop.attach baseMesh objGroup[j]
						)
						catch
						(
							local errorMsg = "Warning: Failed to attach object " + objGroup[j].name
							format "%\n" errorMsg
							append logMessages ("  - " + errorMsg)
						)
						
						-- Periodically update UI to prevent freezing
						if (mod j 10) == 0 then windows.processPostedMessages()
					)
					
					-- Rename the resulting object
					baseMesh.name = mergedName
					baseMesh.material = groupMaterial
					append mergedObjects baseMesh
				)
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
	resultMessage += "Process completed in " + totalTime as string + " seconds."
	
	messageBox resultMessage title:"Merge Complete"
	format "%\n" resultMessage
	
	-- Write log to MAXScript listener
	format "\n--- Merge Log ---\n"
	for msg in logMessages do format "% \n" msg
	format "---------------\n"
	
	return true
)

-- Execute the function
simplifiedMergeByMaterial()