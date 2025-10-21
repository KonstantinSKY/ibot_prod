on run {firstName, lastName, phoneNumber}
	try
		tell application "Contacts"
			set existingPersons to (every person whose value of phones contains phoneNumber)
			if (count of existingPersons) > 0 then
				return "{\"status\":\"exists\",\"phone\":\"" & phoneNumber & "\"}"
			end if
			
			set newPerson to make new person with properties {first name:firstName, last name:lastName}
			make new phone at end of phones of newPerson with properties {label:"mobile", value:phoneNumber}
			save
			
			return "{\"status\":\"created\",\"first_name\":\"" & firstName & "\",\"last_name\":\"" & lastName & "\",\"phone\":\"" & phoneNumber & "\"}"
		end tell
	on error errMsg number errNum
		return "{\"status\":\"error\",\"message\":\"" & errMsg & "\",\"code\":" & errNum & "}"
	end try
end run
