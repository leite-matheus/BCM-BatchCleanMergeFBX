/*
 * BCM_UI_Progress.ms
 * 
 * Description: Progress UI rollout for the Bulk Clean and Merge tool.
 * 
 * Created: March 17, 2025
 */

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