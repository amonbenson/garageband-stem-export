property usageText : "Usage: osascript export_stems.applescript [options] OUTPUT_DIRECTORY

Export every track of the open GarageBand project as a 16 bit, 44100 Hz WAV
stem named after the track.

Options:
  -p, --prefix TEXT       Put TEXT in front of each track name
  -s, --suffix TEXT       Put TEXT after each track name
  -P, --project-prefix    Put the project name in front: \"Project - Track.wav\"
  -S, --project-suffix    Put the project name after: \"Track - Project.wav\"
  -t, --track NAME        Export only the track NAME (can be repeated)
  -h, --help              Show this help

Prefix and suffix text is used exactly as given, so include any separator
yourself. A prefix option and its project variant cannot be combined.

Examples:
  osascript export_stems.applescript ~/Desktop/stems
  osascript export_stems.applescript -P ~/Desktop/stems
  osascript export_stems.applescript -p 'Take2_' -S ~/Desktop/stems
  osascript export_stems.applescript -t Alice -t Alfred ~/Desktop/stems"

property exportTimeoutSeconds : 900
property pollIntervalSeconds : 0.5
property mouseClickSource : "import ctypes, sys, time
quartz = ctypes.CDLL('/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices')
class Point(ctypes.Structure):
    _fields_ = [('x', ctypes.c_double), ('y', ctypes.c_double)]
quartz.CGEventCreate.restype = ctypes.c_void_p
quartz.CGEventCreate.argtypes = [ctypes.c_void_p]
quartz.CGEventGetLocation.restype = Point
quartz.CGEventGetLocation.argtypes = [ctypes.c_void_p]
quartz.CGEventCreateMouseEvent.restype = ctypes.c_void_p
quartz.CGEventCreateMouseEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint32, Point, ctypes.c_uint32]
quartz.CGEventPost.argtypes = [ctypes.c_uint32, ctypes.c_void_p]
def post(kind, point):
    quartz.CGEventPost(0, quartz.CGEventCreateMouseEvent(None, kind, point, 0))
original = quartz.CGEventGetLocation(quartz.CGEventCreate(None))
target = Point(float(sys.argv[1]), float(sys.argv[2]))
post(5, target)
time.sleep(0.3)
post(1, target)
time.sleep(0.08)
post(2, target)
time.sleep(0.2)
post(5, original)
"

on run argumentList
	set options to parseArguments(argumentList)
	if wantsHelp of options then return usageText
	set outputDirectory to prepareOutputDirectory(outputDirectory of options)
	bringGarageBandToFront()
	set trackNames to readTrackNamesWhenReady()
	assertTracksExist(requestedNames of options, trackNames)
	set projectLabel to readProjectName()
	set filePrefix to chooseAffix(filePrefix of options, usesProjectPrefix of options, projectLabel & " - ")
	set fileSuffix to chooseAffix(fileSuffix of options, usesProjectSuffix of options, " - " & projectLabel)
	set originalSoloStates to readSoloStates()
	try
		exportRequestedTracks(trackNames, requestedNames of options, outputDirectory, filePrefix, fileSuffix)
	on error errorMessage number errorNumber
		restoreSoloStates(originalSoloStates)
		error errorMessage number errorNumber
	end try
	restoreSoloStates(originalSoloStates)
	return "Exported stems to " & outputDirectory
end run

on parseArguments(argumentList)
	set options to {outputDirectory:"", filePrefix:"", fileSuffix:"", usesProjectPrefix:false, usesProjectSuffix:false, requestedNames:{}, wantsHelp:false}
	set remainingArguments to argumentList
	considering case
		repeat while (count of remainingArguments) > 0
			set currentArgument to item 1 of remainingArguments
			set remainingArguments to rest of remainingArguments
			if currentArgument is in {"-h", "--help"} then
				set options to {wantsHelp:true} & options
			else if currentArgument is in {"-P", "--project-prefix"} then
				set options to {usesProjectPrefix:true} & options
			else if currentArgument is in {"-S", "--project-suffix"} then
				set options to {usesProjectSuffix:true} & options
			else if currentArgument is in {"-p", "--prefix"} then
				set options to {filePrefix:optionValue(currentArgument, remainingArguments)} & options
				set remainingArguments to rest of remainingArguments
			else if currentArgument is in {"-s", "--suffix"} then
				set options to {fileSuffix:optionValue(currentArgument, remainingArguments)} & options
				set remainingArguments to rest of remainingArguments
			else if currentArgument is in {"-t", "--track"} then
				set options to {requestedNames:(requestedNames of options) & {optionValue(currentArgument, remainingArguments)}} & options
				set remainingArguments to rest of remainingArguments
			else if currentArgument starts with "-" then
				error "Unknown option " & currentArgument & ". Use --help for usage."
			else if (outputDirectory of options) is not "" then
				error "Unexpected argument " & currentArgument & ". Use --help for usage."
			else
				set options to {outputDirectory:currentArgument} & options
			end if
		end repeat
	end considering
	validateOptions(options)
	return options
end parseArguments

on optionValue(optionName, remainingArguments)
	if (count of remainingArguments) is 0 then error "Option " & optionName & " needs a value. Use --help for usage."
	return item 1 of remainingArguments
end optionValue

on validateOptions(options)
	if wantsHelp of options then return
	if (outputDirectory of options) is "" then error "Missing OUTPUT_DIRECTORY. Use --help for usage."
	if usesProjectPrefix of options and (filePrefix of options) is not "" then error "Use either --prefix or --project-prefix, not both."
	if usesProjectSuffix of options and (fileSuffix of options) is not "" then error "Use either --suffix or --project-suffix, not both."
end validateOptions

on chooseAffix(customText, usesProjectName, projectAffix)
	if usesProjectName then return projectAffix
	return customText
end chooseAffix

on assertTracksExist(requestedNames, trackNames)
	repeat with requestedName in requestedNames
		if trackNames does not contain (contents of requestedName) then error "No track named \"" & requestedName & "\". Tracks: " & joinText(trackNames, ", ")
	end repeat
end assertTracksExist

on joinText(textList, separator)
	set savedDelimiters to AppleScript's text item delimiters
	set AppleScript's text item delimiters to separator
	set joinedText to textList as text
	set AppleScript's text item delimiters to savedDelimiters
	return joinedText
end joinText

on readProjectName()
	tell application "System Events" to set documentUrl to value of attribute "AXDocument" of my mainWindow()
	set pythonSource to "import pathlib, sys, urllib.parse; print(pathlib.PurePosixPath(urllib.parse.unquote(sys.argv[1]).rstrip('/')).stem)"
	return do shell script "python3 -I -c " & quoted form of pythonSource & " " & quoted form of documentUrl
end readProjectName

on exportRequestedTracks(trackNames, requestedNames, outputDirectory, filePrefix, fileSuffix)
	set usedFileNames to {}
	repeat with trackIndex from 1 to count of trackNames
		set trackName to item trackIndex of trackNames
		set fileName to uniqueFileName(safeFileName(filePrefix & trackName & fileSuffix), usedFileNames)
		set end of usedFileNames to fileName
		if isRequested(trackName, requestedNames) then
			log "Exporting " & trackName
			soloOnly(trackIndex)
			exportStem(outputDirectory, fileName)
		end if
	end repeat
end exportRequestedTracks

on isRequested(trackName, requestedNames)
	if (count of requestedNames) is 0 then return true
	return requestedNames contains trackName
end isRequested

on prepareOutputDirectory(directoryPath)
	return do shell script "mkdir -p " & quoted form of directoryPath & " && cd " & quoted form of directoryPath & " && pwd"
end prepareOutputDirectory

on safeFileName(trackName)
	return do shell script "printf %s " & quoted form of trackName & " | tr '/:' '__'"
end safeFileName

on uniqueFileName(baseName, usedFileNames)
	set candidateName to baseName
	set duplicateCount to 1
	repeat while usedFileNames contains candidateName
		set duplicateCount to duplicateCount + 1
		set candidateName to baseName & " " & duplicateCount
	end repeat
	return candidateName
end uniqueFileName

on mainWindow()
	tell application "System Events"
		return first window of process "GarageBand" whose subrole is "AXStandardWindow"
	end tell
end mainWindow

on trackHeaderScrollArea()
	tell application "System Events"
		set tracksGroup to first UI element of my mainWindow() whose description is "Tracks"
		set lowerSplitGroup to last UI element of UI element 1 of tracksGroup
		return UI element 1 of lowerSplitGroup
	end tell
end trackHeaderScrollArea

on trackHeaderGroup()
	tell application "System Events"
		return first UI element of my trackHeaderScrollArea() whose description is "Tracks header"
	end tell
end trackHeaderGroup

on readTrackNamesWhenReady()
	repeat 20 times
		try
			return readTrackNames()
		end try
		delay pollIntervalSeconds
	end repeat
	return readTrackNames()
end readTrackNamesWhenReady

on readTrackNames()
	tell application "System Events"
		set trackNames to {}
		repeat with trackHeader in UI elements of my trackHeaderGroup()
			set end of trackNames to description of first text field of trackHeader
		end repeat
		return trackNames
	end tell
end readTrackNames

on readSoloStates()
	tell application "System Events"
		set soloStates to {}
		repeat with trackHeader in UI elements of my trackHeaderGroup()
			set end of soloStates to (value of (first checkbox of trackHeader whose description is "Solo")) is 1
		end repeat
		return soloStates
	end tell
end readSoloStates

on bringGarageBandToFront()
	tell application "GarageBand" to activate
	tell application "System Events"
		repeat until frontmost of process "GarageBand"
			delay 0.1
		end repeat
	end tell
end bringGarageBandToFront

on setSolo(trackIndex, shouldSolo)
	if isSoloed(trackIndex) is shouldSolo then return
	selectTrack(trackIndex)
	tell application "System Events" to keystroke "s"
	repeat 20 times
		if isSoloed(trackIndex) is shouldSolo then return
		delay 0.1
	end repeat
	error "Could not change solo state of track " & trackIndex
end setSolo

on isSoloed(trackIndex)
	tell application "System Events"
		set soloCheckbox to first checkbox of UI element trackIndex of my trackHeaderGroup() whose description is "Solo"
		return (value of soloCheckbox) is 1
	end tell
end isSoloed

on selectTrack(trackIndex)
	bringGarageBandToFront()
	tell application "System Events"
		set value of scroll bar 1 of my trackHeaderScrollArea() to 0
		delay 0.3
		set firstHeader to UI element 1 of my trackHeaderGroup()
		set {headerX, headerY} to position of firstHeader
		set {headerWidth, headerHeight} to size of firstHeader
	end tell
	clickMouseAt(headerX + 4, headerY + headerHeight / 2)
	repeat trackIndex - 1 times
		tell application "System Events" to key code 125
		delay 0.1
	end repeat
end selectTrack

on clickMouseAt(screenX, screenY)
	do shell script "python3 -I -c " & quoted form of mouseClickSource & " " & (screenX as integer) & " " & (screenY as integer)
end clickMouseAt

on soloOnly(soloTrackIndex)
	repeat with trackIndex from 1 to count of readSoloStates()
		setSolo(trackIndex, trackIndex is soloTrackIndex)
	end repeat
end soloOnly

on restoreSoloStates(soloStates)
	repeat with trackIndex from 1 to count of soloStates
		setSolo(trackIndex, item trackIndex of soloStates)
	end repeat
end restoreSoloStates

on exportStem(outputDirectory, fileName)
	set targetPath to outputDirectory & "/" & fileName & ".wav"
	openExportDialog()
	chooseFolder(outputDirectory)
	configureExportDialog(fileName)
	confirmExportDialog()
	waitForExport(targetPath)
	convertToCdFormat(targetPath)
end exportStem

on openExportDialog()
	tell application "System Events"
		tell process "GarageBand"
			my bringGarageBandToFront()
			click menu item "Export Song to Disk…" of menu 1 of menu bar item "Share" of menu bar 1
		end tell
	end tell
	waitForWindow("Export Song to Disk")
end openExportDialog

on waitForWindow(windowName)
	tell application "System Events"
		repeat 100 times
			if exists window windowName of process "GarageBand" then return
			delay pollIntervalSeconds
		end repeat
	end tell
	error "Window not found: " & windowName
end waitForWindow

on chooseFolder(folderPath)
	tell application "System Events"
		tell process "GarageBand"
			keystroke "g" using {command down, shift down}
			repeat until exists sheet 1 of window "Export Song to Disk"
				delay pollIntervalSeconds
			end repeat
			set value of text field 1 of sheet 1 of window "Export Song to Disk" to folderPath
			keystroke return
			repeat while exists sheet 1 of window "Export Song to Disk"
				delay pollIntervalSeconds
			end repeat
		end tell
	end tell
end chooseFolder

on configureExportDialog(fileName)
	tell application "System Events"
		set dialogContent to my exportDialogContent()
		click radio button "WAVE" of dialogContent
		set value of (first text field of dialogContent whose description is "text field") to fileName
		my selectUncompressedQuality(dialogContent)
	end tell
end configureExportDialog

on selectUncompressedQuality(dialogContent)
	tell application "System Events"
		set qualityButton to first pop up button of dialogContent whose title is not "Where:"
		if (value of qualityButton) contains "16-bit" then return
		click qualityButton
		click (first menu item of menu 1 of qualityButton whose title contains "16-bit")
	end tell
end selectUncompressedQuality

on confirmExportDialog()
	tell application "System Events"
		click button "Export" of my exportDialogContent()
		delay 1
		my confirmReplaceIfAsked()
	end tell
end confirmExportDialog

on confirmReplaceIfAsked()
	tell application "System Events"
		tell process "GarageBand"
			if not (exists window "Export Song to Disk") then return
			if not (exists sheet 1 of window "Export Song to Disk") then return
			click button "Replace" of sheet 1 of window "Export Song to Disk"
		end tell
	end tell
end confirmReplaceIfAsked

on exportDialogContent()
	tell application "System Events"
		return UI element 1 of window "Export Song to Disk" of process "GarageBand"
	end tell
end exportDialogContent

on waitForExport(targetPath)
	set previousSize to -1
	repeat with elapsedPolls from 1 to (exportTimeoutSeconds / pollIntervalSeconds)
		delay pollIntervalSeconds
		set currentSize to fileSize(targetPath)
		if currentSize > 0 and currentSize is previousSize and onlyMainWindowOpen() then return
		set previousSize to currentSize
	end repeat
	error "Timed out waiting for " & targetPath
end waitForExport

on onlyMainWindowOpen()
	tell application "System Events"
		return (count of windows of process "GarageBand") is 1
	end tell
end onlyMainWindowOpen

on fileSize(filePath)
	return (do shell script "stat -f %z " & quoted form of filePath & " 2>/dev/null || echo 0") as integer
end fileSize

on convertToCdFormat(targetPath)
	set temporaryPath to targetPath & ".converting.wav"
	do shell script "afconvert -f WAVE -d LEI16@44100 " & quoted form of targetPath & " " & quoted form of temporaryPath & " && mv " & quoted form of temporaryPath & " " & quoted form of targetPath
end convertToCdFormat
