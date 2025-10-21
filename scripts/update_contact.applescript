on run {firstName, lastName, phoneNumber}
	try
		tell application "Contacts"
			set matchingPersons to (every person whose value of phones contains phoneNumber)
			if (count of matchingPersons) is 0 then
				return "{\"status\":\"not_found\",\"phone\":\"" & phoneNumber & "\"}"
			end if
			
			set targetPerson to item 1 of matchingPersons
			set currentFirstName to first name of targetPerson
			set currentLastName to last name of targetPerson
			
			
			if firstName is not currentFirstName then
				set first name of targetPerson to firstName
			end if
			
			if lastName is not currentLastName then
				set last name of targetPerson to lastName
			end if
			
			save
			
			return "{\"status\":\"updated\",\"first_name\":\"" & firstName & "\",\"last_name\":\"" & lastName & "\",\"phone\":\"" & phoneNumber & "\"}"
		end tell
	on error errMsg number errNum
		return "{\"status\":\"error\",\"message\":\"" & errMsg & "\",\"code\":" & errNum & "}"
	end try
end run
