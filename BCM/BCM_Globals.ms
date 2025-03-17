/*
 * BCM_Globals.ms
 * 
 * Description: Global variables and configuration for the Bulk Clean and Merge tool.
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

-- Script version information
global BCM_Version = "1.0"
global BCM_CreationDate = "March 17, 2025"