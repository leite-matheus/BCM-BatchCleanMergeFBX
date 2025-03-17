/*
 * BCM_UI_Main.ms
 * 
 * Description: Main UI rollout for the Bulk Clean and Merge tool.
 * 
 * Created: March 17, 2025
 */

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