;;	Examples:
/* 
msgbox % sOutput := Run("ping.exe localhost")							;just grab the output
msgbox % sOutput := Run("ping.exe localhost", "", "", "OnOutput")		;with stream handler
msgbox % sOutput := Run("cmd.exe /c dir /a /o", A_WinDir)				;with working dir
msgbox % sOutput := Run("sort.exe", "", "abc`r`nefg`r`nhijk`r`n0123" )	;with stdin input
if ErrorLevel
	msgbox Program failed with exit code %ErrorLevel%
OnOutput(s){
	OutputDebug %s%
  } 
*/

/*
	Function: Run
			  Retreive and be notified about output from the console programs.

	Parameters:
			Cmd		 - Command to execute.
			Dir		 - Working Directory, optional.
			Input	 - Program input (stdin).
			Stream	 - If set to TRUE it will create a console window and display output line-by-line, in addition to returning the result as a whole.
  					   If string, name of the function to be called as output updates (stream handler). The function accepts one argument.

	Remarks:
			After the function finishes, ErrorLevel will be set to programs exit code.
			You can't use function names for stream handler that consist only of numbers.

	About:	
			o v1.0
			o Developed by Sean. Modified and documented by majkinetor.
			o Licenced under GNU GPL <http://creativecommons.org/licenses/GPL/2.0/> 
 */
Run(Cmd, Dir = "", Input = "", Stream = "")
{
	DllCall("CreatePipe", "UintP", hStdInRd , "UintP", hStdInWr , "Uint", 0, "Uint", 0)
	DllCall("CreatePipe", "UintP", hStdOutRd, "UintP", hStdOutWr, "Uint", 0, "Uint", 0)
	DllCall("SetHandleInformation", "Uint", hStdInRd , "Uint", 1, "Uint", 1)
	DllCall("SetHandleInformation", "Uint", hStdOutWr, "Uint", 1, "Uint", 1)
	VarSetCapacity(pi, 16, 0)
	NumPut(VarSetCapacity(si, 68, 0), si)	; size of si
	NumPut(0x100	, si, 44)		; STARTF_USESTDHANDLES
	NumPut(hStdInRd	, si, 56)		; hStdInput
	NumPut(hStdOutWr, si, 60)		; hStdOutput
	NumPut(hStdOutWr, si, 64)		; hStdError
	If !DllCall("CreateProcess", "Uint", 0, "Uint", &Cmd, "Uint", 0, "Uint", 0, "int", True, "Uint", 0x08000000, "Uint", 0, "Uint", Dir ? &Dir : 0, "Uint", &si, "Uint", &pi)	; bInheritHandles and CREATE_NO_WINDOW
		return A_ThisFunc "> Can't create process:`n" Cmd 
	
	hProcess := NumGet(pi,0)
    DllCall("CloseHandle", "Uint", NumGet(pi,4)),  DllCall("CloseHandle", "Uint", hStdOutWr),  DllCall("CloseHandle", "Uint", hStdInRd)

	If Input !=
		DllCall("WriteFile", "Uint", hStdInWr, "Uint", &Input, "Uint", StrLen(Input), "UintP", nSize, "Uint", 0)

	DllCall("CloseHandle", "Uint", hStdInWr)
	Stream+0 ? (bAlloc:=DllCall("AllocConsole"),hCon:=DllCall("CreateFile","str","CON","Uint",0x40000000,"Uint",bAlloc ? 0 : 3,"Uint",0,"Uint",3,"Uint",0,"Uint",0)) : ""
	VarSetCapacity(sTemp, nTemp:=Stream ? 64-nTrim:=1 : 4095)
	Loop
		If	DllCall("ReadFile", "Uint", hStdOutRd, "Uint", &sTemp, "Uint", nTemp, "UintP", nSize:=0, "Uint", 0) && nSize
		{
			NumPut(0,sTemp,nSize,"Uchar"), VarSetCapacity(sTemp,-1), sOutput.=sTemp
			If	Stream
				Loop
					If	RegExMatch(sOutput, "S)[^\n]*\n", sTrim, nTrim)
						Stream+0 ? DllCall("WriteFile", "Uint", hCon, "Uint", &sTrim, "Uint", StrLen(sTrim), "UintP", 0, "Uint", 0) : %Stream%(sTrim), nTrim+=StrLen(sTrim)
					Else	Break
		}
		Else	Break	
	DllCall("CloseHandle", "Uint", hStdOutRd)
	Stream+0 ? (DllCall("Sleep","Uint",1000),hCon+1 ? DllCall("CloseHandle","Uint",hCon) : "",bAlloc ? DllCall("FreeConsole") : "") : ""
	DllCall("GetExitCodeProcess", "uint", hProcess, "intP", ExitCode)
	DllCall("CloseHandle", "Uint", hProcess)
	ErrorLevel := ExitCode
	return	sOutput
}