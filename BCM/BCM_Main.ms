/*
 * BCM_Main.ms
 * 
 * Description: Main script that loads all components for the Bulk Clean and Merge tool.
 * This script initializes the application by loading all necessary modules.
 * 
 * Created: March 17, 2025
 */

-- Clear any existing globals and rollouts with the same name to avoid conflicts
if BCM_RolloutMain != undefined do destroyDialog BCM_RolloutMain
if BCM_RolloutProgress != undefined do destroyDialog BCM_RolloutProgress

-- Script folder path
global BCM_ScriptPath = getFilenamePath (getThisScriptFilename())

-- Load components in the correct order
fileIn (BCM_ScriptPath + "BCM_Globals.ms")           -- Global variables first
fileIn (BCM_ScriptPath + "BCM_FileFunctions.ms")     -- File handling functions
fileIn (BCM_ScriptPath + "BCM_ProcessingFunctions.ms") -- Scene processing functions
fileIn (BCM_ScriptPath + "BCM_UI_Main.ms")           -- Main UI components
fileIn (BCM_ScriptPath + "BCM_UI_Progress.ms")       -- Progress UI components

-- Create and display the main dialog
if BCM_RolloutMain != undefined then destroyDialog BCM_RolloutMain
createDialog BCM_RolloutMain 400 440 style:#(#style_titlebar, #style_border, #style_sysmenu)

-- Print initialization message to listener
format "Bulk Clean and Merge Tool initialized.\n"
format "Version: 1.0\n"
format "Created: March 17, 2025\n"