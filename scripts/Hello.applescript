-- Minimal headless Hello message sender
on run {serviceName, contactFirstName, targetBuddy}
	-- Формируем текст
	set helloMessage to "Hi " & contactFirstName & "!👋 C-Bus Delivery. " & return & ¬
		"We have received your order and it is now being prepared. " & return & ¬
		"We’ll update you soon. Thank you for choosing us!💚"

	-- Отправляем через Messages без UI
	tell application "Messages"
		try
			set targetService to first service whose service type is serviceName
			set theChat to make new text chat with properties {service:targetService, participants:{targetBuddy}}
			send helloMessage to theChat
			return "{\"status\":\"ok\"}"
		on error errMsg number errNum
			return "{\"status\":\"error\",\"message\":\"" & errMsg & "\",\"code\":" & errNum & "}"
		end try
	end tell
end run
