on run argv
	if (count of argv) is less than 2 then error "usage: style-dmg.applescript <volume-name> <app-name>"

	set volumeName to item 1 of argv
	set appName to item 2 of argv

	set windowLeft to 160
	set windowTop to 120
	set windowWidth to 720
	set windowHeight to 420
	set windowRight to windowLeft + windowWidth
	set windowBottom to windowTop + windowHeight

	set appPosition to {170, 228}
	set applicationsPosition to {548, 228}
	set dsStorePath to quoted form of ("/Volumes/" & volumeName & "/.DS_Store")

	tell application "Finder"
		tell disk (volumeName as string)
			open

			tell container window
				set current view to icon view
				set toolbar visible to false
				set statusbar visible to false
				set the bounds to {windowLeft, windowTop, windowRight, windowBottom}
			end tell

			set opts to the icon view options of container window
			tell opts
				set arrangement to not arranged
				set icon size to 128
				set text size to 14
			end tell
			set background picture of opts to file ".background:installer-background.png"

			set position of item appName to appPosition
			set position of item "Applications" to applicationsPosition
			set extension hidden of item appName to true

			close
			open
			delay 1

			tell container window
				set statusbar visible to false
				set the bounds to {windowLeft, windowTop, windowRight - 8, windowBottom - 8}
			end tell
		end tell

		delay 1

		tell disk (volumeName as string)
			tell container window
				set statusbar visible to false
				set the bounds to {windowLeft, windowTop, windowRight, windowBottom}
			end tell
		end tell

		set waitSeconds to 0
		repeat while waitSeconds < 10
			delay 1
			set waitSeconds to waitSeconds + 1
			if (do shell script "[ -f " & dsStorePath & " ] && echo yes || echo no") is "yes" then exit repeat
		end repeat
	end tell
end run
