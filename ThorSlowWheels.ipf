#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//This code provides a GUI for controlling Thorlabs FW102 filter wheels
//The user should only have to modify the string 'wheelsList_local' in the tsw_startPanels() function below
//and ensure that the VDT2 XOP is running in their version of Igor (see below)
//Then the filter wheel GUI can be initiated from the top menu bar (Macros --> Start Thor (Slow) Wheels Panel)
//or by running tsw_startPanels() from command line.

//The first time that you start the GUI in an Igor Pro experiment, you will be prompted to choose a path to save a log file that stores the history of filter wheel positions

//To get VDT2 XOP running, copy the VDT2.xop (and/or VDT2-64.xop) from the "more extensions/Data Acquisition" folder 
//(found in Program Files\WaveMetrics\Igor Pro 8 Folder\ for Igor 8) to the "Igor Extensions" folder(s) in the same directory. 
//Also copy the associated help file VDT2.ihf
//On 64-bit computers, I recommend that you copy VDT2.xop and VDT2-64.xop into the 32-bit and 64-bit extension folders, respectively
//This will make VDT2.xop available in 32-bit and 64-bit Igor

//Tips and tricks:

//The FW102 driver must be installed. If this doesn't happen automatically when the USB cable is plugged into the computer, check for directions on the thor labs website.
//Properly installed, on Windows 7, the filter wheels show up under Devices and Printers as FW102C Filter Wheel (Where you can see the com port under properties)

//It is easy to identify the COM ports for your wheel(s) using VDT2 (the GUI panel makes it even easier, but it is not necessary)
//With all the wheels connected, run this line at the command line (CTRL+J brings up the command line): "VDTGetPortList2;print s_VDT"
//this will print all available ports.
//Then turn off or disconnect a single filter wheel whose port you want to identify
//Then run this command: "VDT2 resetPorts". This command gets Igor to update what ports are available.
//Then run again this command: "VDTGetPortList2;print s_VDT". The bench that was disconnected will have dropped out of the list

Menu "Macros"		//add GUI start function to Macros
	"Start Thor (Slow) Wheels Panel",/Q,tsw_startPanels()
end

//GUI start function. Connects to wheels
function tsw_startPanels()		//run to instantiate panel -- fill in appropriate defaults first
	//define defualt settings -- communication ports should be correct at start up
	String panelName = "tsw_panel"			//can change this to get multiple panels running
	//make data folder to store info in
	tsw_SetDataFolderForDevice(panelName,0)
	String pathToTSWFolder = ks_TSW_FolderPath
	String pathToDF = TSW_DataFolderNameForDevice(panelName,1)			//variables stored here
	Variable autoChecksAndLogging = 1 		//(recommend set to true) use tsw_autoChecks background function to check wheel positions and log periodically
	Variable autoCheckFreqSecs=5			//if autoChecksAndLogging, sets frequency of automatic checking
													//this background is paused during processing of user input
	Variable automaticReconnection = 1		//(recommend set to true) use SetIgorHook  to reconnect to wheels on Igor restart (if window still open)
	Variable deleteWinDataOnClose = 1		//(recommend set to true) use window hook to delete all associated Package data 
	String initializeWheelTriggersAs = "output;output;output;output;output;output;"	//as many semicolon-delimited items as wheelsList_local. Specify whether to initialize all filter wheel bnc triggers as "input" or "output". "" items will send nothing. setting entire string to "" will cause it to be ignored entirely
	
	//list of filter wheel sets -- use inf for full stops, 0 for no attenuation. Do not use -inf at all (will cause errors with automated calibration).
	
	//*******************************************************************************************
	//THIS AREA IS CUSTOMIZED DEPENDING ON USER SETUP
	String wheelsList_local = ""
	wheelsList_local += "COM11:B0_ND_C:0,1,2,3,4,inf;"			//add a line for each wheel to define. port_used:user_desc:pos0,pos1,pos2,pos3,pos4,pos5
	wheelsList_local += "COM10:B0_ND_F:0,0.3,0.6,1.0,1.3,2;"	//avoid these characters-- ;,|- (last one is a dash) --except as required by this format
	wheelsList_local += "COM9:B0_WL:0,442-10,460-10,500-10,560-10,588-20;"	//544-10 is actually 543.5-10
	wheelsList_local += "COM12:B1_ND_C:0,1,2,3,4,inf;"			
	wheelsList_local += "COM14:B1_ND_F:0,0.3,0.6,1.0,1.3,2;"
	wheelsList_local += "COM13:B1_WL:530-10,442-10,544-10,500-10,560-10,600-10;"	
	String colorBenchPosKeyList_local = "2:0,1;5:3,4;"	//for automated intensity calcs. keyed list with key of wheelsList index of each color bench
																	//list items are wheelsList index associated with that color (on the same bench as it)
																	
	//END OF AREA THAT IS CUSTOMIZED DEPENDING ON USER SETUP
	//*******************************************************************************************

	//save wheelsList, benchesList, colorBenchPosKeyList
	SVAR/Z wheelsList = $(pathToDF + "wheelsList")
	if (!SVAR_Exists(wheelsList))
		String/G $(pathToDF + "wheelsList")	
		SVAR wheelsList = $(pathToDF + "wheelsList")	
	endif
	wheelsList = wheelsList_local
	
	SVAR/Z colorBenchPosKeyList = $(pathToDF + "colorBenchPosKeyList")
	if (!SVAR_Exists(colorBenchPosKeyList))
		String/G $(pathToDF + "colorBenchPosKeyList")	
		SVAR colorBenchPosKeyList = $(pathToDF + "colorBenchPosKeyList")	
	endif
	colorBenchPosKeyList = colorBenchPosKeyList_local	
			
	//make a string containing list of each panel associated with each com port
	SVAR/Z comPanels = $(pathToTSWFolder + "comPanels")		
	if (!SVAR_Exists(comPanels))
		String/G $(pathToTSWFolder + "comPanels")	
		SVAR comPanels = $(pathToTSWFolder + "comPanels")	
	endif
	comPanels = ""
	//append these com ports 
	String currWheelInfo
	int i,numWheels=itemsinlist(wheelsList)
	for (i=0;i<numWheels;i+=1)
		currWheelInfo = stringfromlist(i,wheelsList)
		comPanels += Stringfromlist(0,currWheelInfo,":") + ":" + panelName +";"
	endfor	
	
	Variable defaultPrintLogging = 0		//default is to have print logging check box checked (1) or not (0)
	//end default setting definitions
		
	//set up and instantiate GUI / main panel
	Variable btnFSize = 9
	Variable cbFontSize = 8
	Variable cbWidth=20
	Variable lbMainFontSize = btnFSize
	Variable lbTitleFontSize=7
	Variable btnWidth=30,btnHeight=18
	Variable panelStartPos_left=btnWidth,panelStartPos_top = 0
	Variable lbWidth=60,lbHeight=104
	Variable extraHeight = 0//96 -- put back to see more options, these are not usually useful ones
	Variable panelPosGap_left =lbWidth //- 20
	Variable panelPos_left,panelPos_top	
	Variable left=0,top=0,width = btnWidth+numWheels*lbWidth,height=lbHeight+extraHeight,right=left+width,bottom=top+height
	Variable loggingCBGap = 5
	
	NewPanel/k=1/N=$panelName /W=(left, top, right, bottom ) as panelName + ": double-click to set positions"
	Button setAllBtn win=$panelName,title="\JLSet",proc=tsw_btnHandling,size={btnWidth,20},pos={0,0*btnHeight},fsize=btnFSize,help={"Set the position of all the wheels to the list box selection (the current selection is displayed in underlined bold or italics)"}
	Button queryAll win=$panelName,title="\JLGet",proc=tsw_btnHandling,size={btnWidth,20},pos={0,1*btnHeight},fsize=btnFSize,help={"Get the position of all wheels as they report them"}
	Button logPathBtn win=$panelName,title="\JLPath",proc=tsw_btnHandling,size={btnWidth,20},pos={0,2*btnHeight},fsize=btnFSize,help={"Change backup file log path"}
	Button forceLogBtn win=$panelName,title="\JLLog",proc=tsw_btnHandling,size={btnWidth,20},pos={0,3*btnHeight},fsize=btnFSize,help={"Record wheel states in backup file log"}
	Checkbox printLoggingCB win=$panelName,value=defaultPrintLogging,title="\rPr",pos={0,3.8*btnHeight+loggingCBGap},fsize=cbFontSize,appearance={os9},size={cbWidth,20},help={"Check to print logging to history (Logging to backup file in any case)"}
	Button printToNotebook win=$panelName,title="\JLNB",proc=tsw_btnHandling,size={btnWidth,20},pos={0,4.8*btnHeight},fsize=btnFSize,help={"Send wheel states to an Igor NoteBook"}
	Checkbox suppressLogDisplayCB win=$panelName,title="\rSL",pos={0,6.2*btnHeight+loggingCBGap},fsize=cbFontSize,appearance={os9},size={cbWidth,20},help={"Suppress automatic changes of pStar values based on actual bench positions\rAllows stationary pStar values based on user selections"}
	Button connectAllPorts win=$panelName,title="\JLInit",proc=tsw_btnHandling,size={btnWidth,20},pos={0,8*btnHeight},fsize=btnFSize,help={"Forces reconnection to all COM ports (almost always unnecessary)"}
	Button closeAllPorts win=$panelName,title="\JLEnd",proc=tsw_btnHandling,size={btnWidth,20},pos={0,9*btnHeight},fsize=btnFSize,help={"Frees (disconnects) all COM ports so they are available to other interfaces/programs"} 
	
	
	setwindow $panelName userdata(wheelsList) = wheelsList		//store wheel list in panel	
	setwindow $panelName userdata(btnWidth)=num2str(btnWidth)
	tsw_changeLogPath(panelName,0)		//check log path
	
	//create save data folder for necessary waves (selLists, etc.)
	tsw_SetDataFolderForDevice(panelName,0)
	
	//add wheel list boxes and connect to each wheel (all handled by tsw_addListBox)
	for (i=0;i<numWheels;i+=1)
		//calc listbox positions
		panelPos_left = panelStartPos_left + i*panelPosGap_left
		panelPos_top = panelStartPos_top
		
		//make wheel
		currWheelInfo = stringfromlist(i,wheelsList)
		tsw_addListBox(currWheelInfo,panelName,panelPos_left,panelPos_top,lbWidth,lbHeight,lbMainFontSize,lbTitleFontSize)
	endfor
	
	if (autoChecksAndLogging)
		String tsw_autoChecksBgName = panelName + ks_autoChecksBgName_AS
		Variable tsw_autoChecksPeriod = autoCheckFreqSecs*60
		Variable tsw_autoChecksDelay = 10*60		//always wait 10 seconds before starting checks
		setwindow $panelName userdata(tsw_autoChecksBgName)=tsw_autoChecksBgName
		setwindow $panelName userdata(tsw_autoChecksPeriod)=num2str(tsw_autoChecksPeriod)
		setwindow $panelName userdata(tsw_autoChecksDelay)=num2str(tsw_autoChecksDelay)
		tsw_startOrStopAutoChecks(panelName,1)
	endif     
	
	if (automaticReconnection)
		SetIgorHook/L AfterCompiledHook=tsw_attemptReconnectAllPanels
	endif	
	
	if (deleteWinDataOnClose)
		setwindow $panelName hook(tsw_hook) = tsw_hook
	endif
	
	
	//initialize BNC trigger status if requested
	if (Strlen(initializeWheelTriggersAs) > 0)
		string triggerMode,wheelCom
		for (i=0;i<numWheels;i+=1)
			triggerMode = stringfromlist(i,initializeWheelTriggersAs)
			if (strlen(triggerMode) > 0)
				currWheelInfo = stringfromlist(i,wheelsList)
				wheelCom = stringfromlist(1,currWheelInfo,":")
				tsw_settriggerMode(triggerMode,panelName,wheelCom,noReport=1)		
			endif
		endfor
	endif
end

//constants that are append strings (AS) usually added after comStr name for specificity to a wheel, or after panel name for specificity to a panel
//also some constants for start strings (SS)
//also constants for TSW package folder
static strconstant ks_listWaveName_AS = "_lw"
static strconstant ks_listBoxName_AS = "_lb"
static strconstant ks_titleWaveName_AS = "_tw"
static strconstant ks_bgName_AS = "_PAUBg"
static strconstant ks_bgStartTime_AS = "_sTime"
static strconstant ks_listWvSelFrmt0 = "\f07\F'Arial Black'"		//bold italics and underline normally
static strconstant ks_listWvSelFrmt1 = "\f05\F'Arial Black'"		//if position is re-checked, toggle between format 0 and format 1, this is currently bold and underlined (no italics)
static strconstant ks_TSW_FolderPath = "root:Packages:TSW:"
static strconstant ks_maxIntensityWv_AS = ks_maxIntensityWv_AS
static strconstant ks_effectiveListWv_AS = "_lwE"
static strconstant ks_altListWv_AS = "_lwA"
static strconstant ks_altTitleWv_AS = "_twA"
static strconstant ks_nomoVals_AS = "_mp"
static strconstant ks_calWvStr_SS = "calWv_"
static strconstant ks_pathName_AS = "_path"
static strconstant ks_logTextFileName_AS = "_log"
static strconstant ks_autoChecksBgName_AS = "_acbg"
static strconstant ks_pStarLbName_AS = "_pLB"
static strconstant ks_pStarListWv_AS = "_pLW"
static strconstant ks_pStarSelWv_AS = "_pSW"
static strconstant ks_flexGateSv_AS = "_fgSV"
static strconstant ks_flexInputSv_AS = "_fiSV"


//From here on: helper functions that the GUI uses. Users can also call some of these for additional functionality


//run=0 stops auto checks in background regardless of run state
//run=1 starts auto checks in background, but only if there are no 
function tsw_startOrStopAutoChecks(panelName,run)
	String panelName; Variable run		//pass run true to run, false to pause
	
	String tsw_autoChecksBgName = GetUserData(panelName, "", "tsw_autoChecksBgName" )
	Variable tsw_autoChecksPeriod = str2num(GetUserData(panelName, "", "tsw_autoChecksPeriod" ))
	Variable tsw_autoChecksDelay = str2num(GetUserData(panelName, "", "tsw_autoChecksDelay" ))
	
	if (run)		
		CtrlNamedBackground $tsw_autoChecksBgName, start=tsw_autoChecksDelay,period=tsw_autoChecksPeriod, proc=tsw_autoChecks,stop=0
	else
		CtrlNamedBackground $tsw_autoChecksBgName, stop=1
	endif
end

//checks Packages folder to see what TSWs have been run from an experiment before
//checks which panels still exist, and then tries to reconnect them if they do
//set up to run on experiment start with SetIgorHook to automatically reconnect to wheels
function tsw_attemptReconnectAllPanels()
			
	String folder = ks_TSW_FolderPath
	SVAR/Z comPanels = $(folder + "comPanels")
	if (!Svar_exists(companels))
		return 0
	endif
	String possiblePanels = ""
	variable i,num = itemsinlist(comPanels)
	String comPanelStr,panel
	for (i=0;i<num;i+=1)
		comPanelStr = stringfromlist(i,comPanels)
		panel = stringfromlist(1,comPanelStr,":")
		if (whichlistitem(panel,possiblePanels) < 0)
			possiblePanels += panel + ";"
		endif
	endfor
	
	num=itemsinlist(possiblePanels)
	for (i=0;i<num;i+=1)
		panel = stringfromlist(i,possiblePanels)
		if (wintype(panel) == 7)		//panel exists by this name
			Print "tsw_attemptReconnectAllPanels(): attempting reconnection to thor labs filter wheels in panel,",panel
			tsw_configureAllPorts(panel,1)
		endif
		
	endfor

end

//returns info on tasks of the type CtrlNamedBackground
function/s bgTask_list(keyStr,matchStr)
	String keyStr		//will return all instances of this key in the S_info list returned by the status query
							//options are NAME:name;PROC:fname;RUN:r;PERIOD:p;NEXT:n;QUIT:q;FUNCERR:e;
							//pass "" for the entire list
	String matchStr		//when a keyStr is passed, pass to filter outputs by matchStr. ignored for keyStr=""

	CtrlNamedBackground _all_, status		//the status variable is poorly documented in use with the _all_ input, but appears \r delimited between ctrls
	
	if (strlen(keyStr) < 1)
		return S_info
	endif
		
	Variable i,num=itemsinlist(S_info,"\r")
	string temp,out=""
	for (i=0;i<num;i+=1)
		temp=stringfromlist(i,S_info,"\r")
		if (stringmatch(temp,matchStr))
			out+=StringByKey(keyStr, temp)+";"
		endif
	endfor
	
	return out
end


//function to handle button GUI button click reactions
function tsw_btnHandling(s) : ButtonControl
	STRUCT WMButtonAction &s
	
	if (s.eventCode != 2)	//mouse up in control
		return 0
	endif
	
	String btnName = s.ctrlname
	String panelStr = s.win
	
	strswitch (btnName)
		case "logPathBtn":
			tsw_changeLogPath(panelStr,1)
			break
		case "queryAll":
			tsw_queryAllWheels(panelStr)
			break
		case "setAllBtn":
			tsw_setAllWheels(panelStr)
			break
		case "closeAllPorts":
			tsw_closeAllPorts(panelStr,0)		//set 1 or 0 to check with user before closing ports. Igor automatically reconnects if prompted so it doesn't really seem necessary to check
			break
		case "connectAllPorts":
			tsw_configureAllPorts(panelStr,1)
			break
		case "printToNotebook":
			Variable shiftDown= (s.eventmod & 2^1)>0
			tsw_printToNotebook(panelStr,shiftDown)
			
		default:
			tsw_log(panelStr)
	endswitch
end

//inititates a background function to check wheel positions. The function ends and updates the GUI
function tsw_queryAllWheels(mainPanelStr)
	String mainPanelStr
	
	String wheelsList = GetUserData(mainPanelStr, "", "wheelsList")
	String wheelInfo,comSTr
	Variable i,numWheels=itemsinlist(wheelsList)	
	for (i=0;i<numWheels;i+=1)
		wheelInfo = stringfromlist(i,wheelsList)
		comSTr = stringfromlist(0,wheelInfo,":")
		tsw_pollForPosAndUpdateLB(comSTr) 
	endfor
end

//set all the wheel positions to the current GUI selections
function tsw_setAllWheels(mainPanelStr)
	String mainPanelStr
	
	String pathToDF = TSW_DataFolderNameForDevice(mainPanelStr,1)
	
	String wheelsList = GetUserData(mainPanelStr, "", "wheelsList")
	String wheelInfo,comSTr,lbName
	Variable i,numWheels=itemsinlist(wheelsList),numPos
	for (i=0;i<numWheels;i+=1)
		wheelInfo = stringfromlist(i,wheelsList)
		numPos = itemsinlist(wheelInfo,",")
		comSTr = stringfromlist(0,wheelInfo,":")
		lbName = comSTr+ ks_listBoxName_AS
		ControlInfo/W=$mainPanelStr $lbName
		if ( (V_Value >= 0) && (V_Value < numPos ) )
			tsw_moveAndUpdateLB(V_Value,comSTr)
		endif
	endfor
end

//have Igor (re)-connect to all ports
function tsw_configureAllPorts(panelName,resetFirst)
	String panelName
	Variable resetFirst
	
	if (resetFirst)
		Print "tsw_configureAllPorts() resetting ports. Will attempt to reconnect to Thor Labs (slow) Filtter Wheels, but OTHER SERIAL I/O WILL BE DISRUPTED. These should be reconnected separately"
		vdt2 resetPorts
	endif
	
	string wheelsList = GetUserData(panelName, "", "wheelsList")
	string wheelInfo,comStr
	variable i,num=itemsinlist(wheelsList),portWasSet,resetAttempted = 0
	for (i=0;i<num;i+=1)
		wheelInfo = stringfromlist(i,wheelsList)
		comstr = stringfromlist(0,wheelInfo,":")
		portWasSet = tsw_configurePort(comStr)
		if (!portwasset)
			if (!resetAttempted)		//already tried to reset
				print "tsw_configureAllPorts() failed to connect to com port",comStr,"attempting reconnection by port reset but OTHER SERIAL I/O WILL BE DISRUPTED. These should be reconnected separately"
				vdt2 resetPorts
				i=0							//restart loop because now we have to reconnect to all ports again
				resetAttempted = 1		//dont try this more than once
			else		//reset was attempted already
				print "tsw_configureAllPorts() was unable to reach com ports and will abort. Wheels may be powered down or their port number changed."
			endif
		endif
	endfor
end

//have Igor reconnect to a com port
function tsw_configurePort(comStr)
	String comStr
	
		//set each port, error will occur if port not appopriately accessible
	try 
		VDTOperationsPort2 $comStr
		AbortOnRTE
	catch 
		Variable err = GetRTError(1)		// Gets error code and clears error
		String errMessage = GetErrMessage(err)
		return 0
	endtry
		
	VDT2/P=$comStr baud=115200, databits=8, parity=0, stopbits=1	
	return 1
end

//have Igor disconnect from all ports
function tsw_closeAllPorts(mainPanelStr,queryUserFirst)
	String mainPanelStr
	Variable queryUserFirst
	
	if (queryUserFirst)
		Variable reallyClosePorts = 1
		Prompt reallyClosePorts, "really close ALL TSW ports?"
		doprompt "tsw_closeAllPorts() cmd check", reallyClosePorts
		if (!reallyClosePorts)
			return 0
		endif
	endif
	
	String wheelsList = GetUserData(mainPanelStr, "", "wheelsList")
	variable numWheels = itemsinlist(wheelsList)
	String wheelInfo,comSTr	
	Variable i
	for (i=0;i<numWheels;i+=1)
		wheelInfo = stringfromlist(i,wheelsList)
		comSTr = stringfromlist(0,wheelInfo,":")
		sio_closePort(comSTr,0)
	endfor
end

//have Igor disconnect from a port
function sio_closePort(comStr,queryUserFirst)
	String comStr
	Variable queryUserFirst
	
	if (queryUserFirst)
		Variable reallyClosePort = 1
		Prompt reallyClosePort, "really close port="+comStr+"?"
		doprompt comStr+" close port cmd check", reallyClosePort
		if (!reallyClosePort)
			return 0
		endif
	endif
	
	VDTClosePort2 $comStr
	Print "sio_closePort(): closed port",comStr
end

//change the path that Igor logs the wheel position history to
function/S tsw_changeLogPath(mainPanelStr,forceOverwrite)
	STring mainPanelStr
	Variable forceOverwrite		//true to force user prompt to choose path, 0 to do so only if path doesn't already exist
	
	String logPathName = mainPanelStr + ks_pathName_AS
	String logTextFileName = mainPanelStr+ ks_logTextFileName_AS
	
	
	PathInfo/S $logPathName			//should direct new path to go to this first.. otherwise use  [, pathToFolderStr] in newpath
	
	if (V_flag && !forceOverwrite)		//0 if path exists
		return logPathName
	endif
	
	NewPath/M="Set new path to store log txt file"/O/Q/Z $logPathName
	if (V_flag)
		Print "tsw_changeLogPathBtn(): new path set failed! V_flag=",V_flag
	else
		PathInfo/S $logPathName
		if (!V_flag)
			Print "tsw_changeLogPathBtn(): new path set failed! V_flag=",V_flag
		else
			Print "Logging path for wheel panel,",mainPanelStr,"set to",S_path+logTextFileName+".txt"
		endif
	endif	
	
	return logPathName
end

//main logging function: prints positions at each filter wheel with dates and times
//assumes filter wheel positions are up to date
//this will fail if the logging text file is open in another program (e.g., notepad)!
function tsw_log(mainPanelStr)
	String mainPanelStr
	
	Variable linLen=60		//in characters
	
	String endOfLogLine = "\r\n"
		
	String logPathName = tsw_changeLogPath(mainPanelStr,0)		//check that path is good -- should be
	STring logTextFileName = mainPanelStr+ks_logTextFileName_AS+".txt"
	
	String posInfo = tsw_getPositions(mainPanelStr)
	
	ControlInfo/W=$mainPanelStr suppressLogDisplayCB
	Variable suppressLogDisplay=V_Value
	
	String saveStr = notes_getNBTimeStamp(1,"") + posInfo + "|"
	//alter to change length ...
	Variable i,len=strlen(saveStr),tally=0,endPos
	Variable fileRefNum
	Open/P=$logPathName/A fileRefNum as logTextFileName
	for (tally=0;tally<len;tally+=linLen)
		endPos=min(tally+linLen-1,len-1)
		fprintf fileRefNum,"%s",saveStr[tally,endPos]
	endfor
	fprintf fileRefNUm,"%s",endOfLogLine
	close fileRefNum
	
	ControlInfo/W=$mainPanelStr printLoggingCB
	if (V_Value)
		Print "TSW_LOG:",saveStr
	endif
end

//get current filter wheel positions
function/S tsw_getPositions(mainPanelStr)
	String mainPanelStr
	
	String pathToDF = TSW_DataFolderNameForDevice(mainPanelStr,1)
	
	String wheelsList = GetUserData(mainPanelStr, "", "wheelsList")
	Variable i,numWheels=itemsinlist(wheelsList)
	String reportedPos = "",comSTr,wheelInfo,listWvRef
	String commandedPos = ""
	for (i=0;i<numWheels;i+=1)
		wheelInfo = stringfromlist(i,wheelsList)	
		comSTr = stringfromlist(0,wheelInfo,":")		
		listWvRef = pathToDF + comSTr + ks_listWaveName_AS
		WAVE listWv = $listWvRef		//if exists, set positions are stored in lastReportedPos, lastCommandPos
		if (!WaveExists(listWv))
			reportedPos += comSTr+":ERR_NW;"
			commandedPos += comSTr+":ERR_NW;"
		else
			reportedPos += comSTr+":"+StringByKey("lastReportedPos", note(listWv)) + ";"
			commandedPos	 += comSTr+":"+StringByKey("lastCommandPos", note(listWv)) + ";"
		endif		
	endfor
	
	return "reportedPos-"+reportedPos + "|commandedPos-" + commandedPos + "|wheelsList-" + wheelsList
end

//returns current wheel positions on all panels
function/s tsw_getPositions_all(normalShortVeryShort)
	Variable normalShortVeryShort	//pass 0 for full length, 1 for short length, 2 for very short length

	String panels = tsw_listPanels()
	if (strlen(panels) < 1)
		return ""
	endif
	Variable i,num=itemsinlist(panels)
	if (num==0)
		return ""
	endif
	
	String panelName
	if (num==1)
		panelName=stringfromlist(0,panels)
		if (normalShortVeryShort==0)
			return tsw_getPositions(panelName)
		else
			return tsw_getPositionsShort(panelName,0,normalShortVeryShort==2)
		endif	
	endif
	
	//num > 1 need to differentiate different panels in output
	String out="",curr
	for (i=0;i<num;i+=1)
		panelName=stringfromlist(i,panels)
		if (normalShortVeryShort==0)
			curr=tsw_getPositions(panelName)
		else
			curr=tsw_getPositionsShort(panelName,0,normalShortVeryShort==2,preAppendStr=panelName)
		endif
		out+=curr
	endfor
	
	return out
end


//returns a shorter or much shorter version of the report on current wheel positions
function/s tsw_getPositionsShort(mainPanelStr,appendTimeStamp,veryShort,[preAppendStr])
	String mainPanelStr
	Variable appendTimeStamp
	Variable veryShort	//pass 0 for standard length, 1 for very short length
	String preAppendStr	//for veryShort=1, optionally pass a preAppend str that allows benches to be identified with a panel number (e.g., p0_ p1_)
	
	String posInfo=tsw_getPositions(mainPanelStr)
	String reportedPosList=replacestring("reportedPos-",stringfromlist(0,posInfo,"|"),"")
	String wheelsList=replacestring("wheelsList-",stringfromlist(2,posInfo,"|"),"")
	
	String reportedPosStr,wheelInfo,positionValuesStr,reportedValue,out="",comName,wheelName
	variable i,num=itemsinlist(reportedPosList),reportedPos
	for (i=0;i<num;i+=1)
		reportedPosStr=stringfromlist(i,reportedPosList)
		wheelInfo=stringfromlist(i,wheelsList)
		comName=stringfromlist(0,wheelInfo,":")
		wheelName=stringfromlist(1,wheelInfo,":")
		positionValuesStr=stringfromlist(2,wheelInfo,":")
		reportedPos=str2num(stringfromlist(1,reportedPosStr,":"))
		reportedValue=stringfromlist(reportedPos,positionValuesStr,",")
		
		if (veryShort)
			reportedValue=stringfromlist(0,reportedValue,"-")		//remove indication of half width if present
			if (ParamIsDefault(preAppendStr))
				out+="B"+num2str(i)+":"+reportedValue+";"
			else
				out+=preAppendStr+"B"+num2str(i)+":"+reportedValue+";"
			endif
		else
			out+=wheelName+"@"+comName+"P"+num2str(reportedPos)+"="+reportedValue+";"
		endif
	endfor
	
	if (appendTimeStamp)
		out+="[["+notes_getNBTimeStamp(0,"")+"]]"
	endif
	
	return out
end

//as the GUI is created, inserts a list box providing control over one filter wheel
function/S tsw_addListBox(wheelInfo,mainPanelName,lbLeft,lbTop,lbWidth,lbHeight,lbMainFontSize,lbTitleFontSize)
	String wheelInfo //PORT:user_desc:wheelVal0,wheelVal1,wheelVal2,... e.g. COM11:colors0:530,590,..."
	String mainPanelName
	Variable lbLeft,lbTop,lbWidth,lbHeight		//specify position to place list box on mainPanel
	Variable lbMainFontSize,lbTitleFontSize	//font size
	
	String pathToDF = TSW_DataFolderNameForDevice(mainPanelName,1)			//call variables by e.g., NVAR localName = $(pathToDF+globalName)
																					//variables can often be made this same way
	
	//inputs are stored as named user data in the listbox, named by their string variable names here
	
	String comStr = stringfromlist(0,wheelInfo,":")		//name of com port
	String posStr = ReplaceString(",",stringfromlist(2,wheelInfo,":"),";") //list of filter wheel position values from 0 to 6; e.g. "0;1;2;3;4;inf" for ODs or "440;500;560;600;650;0" for colors
	String userInfo = stringfromlist(1,wheelInfo,":") 		//e.g. colors wheel 
	
	String listWvRef = pathToDF + comStr + ks_listWaveName_AS
	String titleWvRef = pathToDF + comStr + ks_titleWaveName_AS
	String lbName = comStr + ks_listBoxName_AS
	
	Variable numPos = Itemsinlist(posStr)
	Make/O/T/N=(numPos) $listWvRef/wave=listWv		//used to control display of position lists
	Make/O/T/N=(1) $titleWvRef/wave=titleWv
	listWv = num2str(p) + "|" + stringfromlist(p,posStr)
	if (lbTitleFontSize < 10)
		titleWv = "\Z0"+num2str(lbTitleFontSize)+userInfo
	else
		titleWv = "\Z"+num2str(lbTitleFontSize)+userInfo
	endif
	
	listbox $lbName win=$mainPanelName,listWave=$listWvRef,titleWave=$titleWvRef,proc=tsw_lbAction,pos={lbLeft,lbTop},size={lbWidth,lbHeight},mode=1,help={comStr},focusRing=0,fsize=lbMainFontSize
	listbox $lbName win=$mainPanelName,userdata(wheelInfo)=wheelInfo,userdata(mainPanelName)=mainPanelName,userData(comStr)=comStr		//too annoying to use in some cases
	Note/nocr listWv, "comStr:"+comStr+";wheelInfo:"+replacestring(";",wheelInfo,"|")+";mainPanelName:"+mainPanelName
	
	//set port
	tsw_configurePort(comStr)
	
	//run first check of filter wheel positions
	tsw_pollForPosAndUpdateLB(comStr)
	
	return comStr
end

//reacts to list box interaction via the GUI
function tsw_lbAction(s) : ListboxControl
	STRUCT WMListboxAction &s
	
	if ( s.eventcode == 4)	//cell selection
		//tsw_updateLightInfo(s.win)		//not implemented at present
		//tsw_pStarUpdate(s.win,1,0,1)
	endif
	
	if ( s.eventCode != 3)		//double clicks only
		return 0
	endif
	
	WAVE listWv = s.listWave
	String comStr = stringbykey("comStr",note(listWv))
	
	//special case -- check for shift/cntrl/alt all down with double click
	//in this case, disconnect from port 
	Variable m = s.eventmod
	if ( (m & 2^1) && (m & 2^2) && (m & 2^3) )
		sio_closePort(comStr,1)
		return 0
	endif
		
	if (s.row < 0)		//in title box, do update and also reconfigure port. See whether to toggle trigger mode
		tsw_configurePort(comStr)
		tsw_pollForPosAndUpdateLB(comStr)
	elseif (s.row < dimsize(listWv,0))		//in bounds selection
		tsw_moveAndUpdateLB(s.row,comStr)	//calls tsw_pollForPosAndUpdateLB after
	else		//beyond listWv bounds, toggle trigger mode
		print "toggling"		//needs double click
		String triggerMode = tsw_getTriggerMode(s.win,comStr)
		if (stringmatch(triggerMode,"input"))
			triggerMode = "output"
		elseif (stringmatch(TriggerMode,"output"))
			triggerMode = "input"
		else	//likely never set before, could be either. default to change to output.
			triggerMode = "output"		//default to set to output first
		endif
		tsw_setTriggerMode(triggerMode,s.win,comStr)		//quick dirty addition
	endif
	
	return 0
end

//Commands filter wheels to move to a new position, then calls a background function that updates the GUI when the movement is complete
function tsw_moveAndUpdateLB(newPosRow,comStr)
	Variable newPosRow
	String comStr

	Variable printErrors = 1
	
	String pathToTSWFolder = ks_TSW_FolderPath
	SVAR comPanels = $(pathToTSWFolder + "comPanels")
	String panelName = StringByKey(comStr, comPanels)
	String pathToDF = TSW_DataFolderNameForDevice(panelName,1)
	String listWvRef = pathToDF + comStr + ks_listWaveName_AS; WAVE/T listWv=$listWvRef
	String titleWvRef = pathToDF + comStr + ks_titleWaveName_AS; WAVE/T titleWv=$titleWvRef
	
	String outCommand = "pos=" + num2str(newPosRow+1) + "\r"		//add one because we count pos 0-5 and wheel uses 1-6
	
	vdtoperationsport2 $comStr	
	
	VDT2/P=$comStr  killio	//clear anything in buffer already
	
	VDTWrite2/O=1/Q outCommand
	if (!V_VDT)
		titleWv = StringfromList(0,titleWv[0],":") + ":PosWriteFail"
		if (printErrors) 
			Print "tsw_moveAndUpdateLB(): PosWriteFail"
		endif
	else
		titleWv = StringfromList(0,titleWv[0],":") + ":"
	endif
	
	//read off the repeated back command (appears to come back instantly, does not wait for move to end)
	String out
	vdtread2/O=1/T="\r"/Q out //may need error handling
	
	Variable lastReportedPos = str2num(StringByKey("lastReportedPos", note(listWv)))
	
	String outNote = ReplaceStringByKey("lastCommandPos",note(listWv), num2str(newPosRow))
	Note/k listWv, outNote
	String mainPanelStr = StringByKey("mainPanelName", outNote)
	//tsw_log(mainPanelStr)	
	tsw_pollForPosAndUpdateLB(comStr)
	
	return lastReportedPos != newPosRow		//returns whether move was likely to occur: true if the last reported position does not equal the newly commanded position
end

//initiates a background function (tsw_pollPosBackground) that asks the filter wheel to report its position. Calling this after commanding the filter wheel to move, the function waits until information is returned from the wheel
//testing indicates that this information is always returned after the movement is complete
function tsw_pollForPosAndUpdateLB(comStr)
	String comStr
	
	//this local must match the local of the same name in tsw_autoChecks!
	String bgNameAppendStr=ks_bgName_AS		//for poll and update background
	String bgName=comStr+bgNameAppendStr
	
	Variable printErrors = 1
	Variable intervalDur_ticks = 30
	
	String pathToTSWFolder = ks_TSW_FolderPath
	SVAR comPanels = $(pathToTSWFolder + "comPanels")
	String panelName = StringByKey(comStr, comPanels)	
	
	String pathToDF = TSW_DataFolderNameForDevice(panelName,1)
	String listWvRef = pathToDF + comStr + ks_listWaveName_AS; WAVE/T listWv=$listWvRef
	String titleWvRef = pathToDF + comStr + ks_titleWaveName_AS; WAVE/T titleWv=$titleWvRef
	
	Variable sendResult = tsw_promptForPos(comStr)
	if (sendResult == -2)		//couldn't set port for use, probably com in comStr is not accessible
		titleWv = StringfromList(0,titleWv[0],":") + ":PortSetFail1"
		if (printErrors) 
			Print "tsw_pollForPosAndUpdateLB(): PortSetFail1"
		endif
		return 0
	endif
	if (sendResult == -1)		//send of command timed out
		titleWv = StringfromList(0,titleWv[0],":") + ":TimeOutOnSend"
		if (printErrors) 
			Print "tsw_pollForPosAndUpdateLB(): TimeOutOnSend"
		endif
		return 0
	endif	

	String bgStartTimeStr = bgName + ks_bgStartTime_AS
	Variable/G $(pathToDF + bgStartTimeStr) 
	NVAR bgStartTime = $(pathToDF + bgStartTimeStr) 
	bgStartTime = ticks
	CtrlNamedBackground $bgName, start=intervalDur_ticks,period=intervalDur_ticks, proc=tsw_pollPosBackground,stop=0
end

//actual background function that gets information from the filter wheel (like its position) as it becomes available (sometimes it is not immediately available if a movement is not complete)
function tsw_pollPosBackground(s)
	STRUCT WMBackgroundStruct &s
	
	Variable printErrors = 1
	
	String inStr = s.name
	String comStr = stringfromlist(0,inStr,"_")
	String pathToTSWFolder = ks_TSW_FolderPath
	SVAR comPanels = $(pathToTSWFolder + "comPanels")
	String panelName = StringByKey(comStr, comPanels)
	String pathToDF = TSW_DataFolderNameForDevice(panelName,1)
		
	Variable statusMinForData = 3
	Variable maxTicks = 360 	//time limit in ticks (~60 ticks per second) -- needs to be long because return is delayed for longer movements it seems
	
	String listWvRef = pathToDF + comStr + ks_listWaveName_AS; WAVE/T listWv=$listWvRef
	String titleWvRef = pathToDF + comStr + ks_titleWaveName_AS; WAVE/T titleWv=$titleWvRef
	
	//how long has it been? quit if too long
	String bgStartTimeStr = pathToDF + s.name + ks_bgStartTime_AS
	NVAR bgStartTime = $bgStartTimeStr
	if (ticks > (bgStartTime + maxTicks))
		titleWv = StringfromList(0,titleWv[0],":") + ":pollPosTimeOut!!"
		if (printErrors && wintype(panelName)) //sometimes getting this error when panel has just been closed so no surprise poll timed out
			Print "tsw_pollPosBackground(): pollPosTimeOut!!"
		endif
		CtrlNamedBackground $s.name,kill
	endif
		
	vdtoperationsport2 $comStr
		
	VDTGetStatus2 0,0,0		//queries for any read info

	if (V_VDT > 3)			//data ready for reading
		String out; variable pos,num=dimsize(listWv,0)
		VDTRead2/O=1/T="\r"/q out;	//good chance to check that last command was position as expected, could prevent some errors
		if ( (V_VDT < 1) && wintype(panelName) )
			Print "tsw_pollPosBackground(): Attempt to read data from panelName",panelName,"comStr",comStr,"failed. Try 'Connect All' button to recover function."
		endif
		
		VDTRead2/O=1/T="\r"/q out;
		
		pos = str2num(out) - 1		//because filter wheel is 1-6 instead of 0-5
		if ( (pos>=0) && (pos<num) )
			String match0=ks_listWvSelFrmt0+"*"
			String match1=ks_listWvSelFrmt1+"*"
			String str=listWv[pos]
			Variable frmt0=StringMatch(str,match0)		//does string contain format 0?
			Variable frmt1=StringMatch(str,match1)		//does string contain format 1?
			if (frmt0)		// if either, we're already at this position, so just toggle between them to let user know communication occured
				listWv[pos]=replacestring(ks_listWvSelFrmt0,str,ks_listWvSelFrmt1)
			elseif (frmt1)
				listWv[pos]=replacestring(ks_listWvSelFrmt1,str,ks_listWvSelFrmt0)
			else			//otherwise it's a new position, so we have to clear the old position and set the new position in the list
				listWv[pos] = ks_listWvSelFrmt0 + listWv[pos]		//label the new set position
				Variable i
				for (i=0;i<num;i+=1)		//scan for any settings to clear .. not sure if it would just be faster to run replacestring?
					if (i==pos)	
						continue	//should be no need to check the position itself
					endif
					if (stringmatch(listWv[i],match0))
						listWv[i]=replacestring(ks_listWvSelFrmt0,listWv[i],"")
					endif
					if (stringmatch(listWv[i],match1))
						listWv[i]=replacestring(ks_listWvSelFrmt1,listWv[i],"")
					endif					
				endfor
			endif
		endif
		//stop checking by deleting calls to this background function
		CtrlNamedBackground $s.name,kill
		
		//log status
		String outNote = ReplaceStringByKey("lastReportedPos",note(listWv), num2str(pos))
		Note/k listWv, outNote
		String mainPanelStr = StringByKey("mainPanelName", outNote)
		//tsw_log(mainPanelStr)
		
		titleWv = StringfromList(0,titleWv[0],":") + ":"
	endif						//data not ready--may still be coming or never come

	return 0		//return 0 continues
end

//the GUI holds the current "trigger mode" of  the filter wheel (input, i.e., moves when BNC set to 5V, or output, i.e., sets BCN to 5V briefly when the wheel is told to move by other means) in user data
//this function returns that
function/S tsw_getTriggerMode(winN,comStr)
	STring winN,comStr
	
	return getuserdata(winN,"",comStr+"_triggerMode")
	
	//note that we could also ask the the filter wheel for its status over the com port, but I haven't implemented this as it doesnt seem necessary
	
end

//sets the trigger mode of the filter wheel (see the comments above tsw_getTriggerMode())
//and stores the commaned trigger mode in user data for reference
function tsw_setTriggerMode(triggerMode,winN,comStr,[noReport])
	String triggerMode		//"input" or "output". Input presumably moves wheel on BNC command, output reports movement with a ~10 ms BNC pulse
	STring winN		//window containing listbox for wheel
	String comStr		//comStr of wheel
	int noReport		//pass as true to avoid printing that trigger mode was set
	
	String cmdStr = "trig="
	if (stringmatch(triggerMode,"input"))
		cmdStr += "0"		//according to manual, 0 is input
	elseif (stringmatch(triggerMode,"output"))
		cmdStr += "1"		//according to manual, 1 is output
	else
		return 0
	endif
	cmdStr+="\r"
	
	vdtoperationsport2 com12;VDTWrite2/O=1/Q cmdStr
	
	setwindow $winN, userdata($(comStr+"_triggerMode"))=triggerMode
	
	if (PAramIsdefault(noReport) || !noReport)
		print "tsw_setTriggerMode() comStr",comStr,"now has trigger set to",triggerMode+".","Scroll its listbox and double click the blank cell to change"
	endif
	
	return 1
end

//starts a background function that periodically asks the filter wheels there positions.
//This is especially useful if one ever hits the physical movement buttons on a filter wheel
//I also notice that sometimes the filter wheels move one position spontanteously, which prompted me to write this 
function tsw_autoChecks(s)
	STRUCT WMBackgroundStruct &s
	
	//this local must match the local of the same name in tsw_pollForPosAndUpdateLB!
	String bgNameAppendStr=ks_bgName_AS		//for poll and update background
	
	String inStr = s.name
	String comStr = stringfromlist(0,inStr,"_")
	String pathToTSWFolder = ks_TSW_FolderPath
	SVAR comPanels = $(pathToTSWFolder + "comPanels")
	String panelName = StringByKey(comStr, comPanels)
	if (wintype(panelName) != 7)		//window no longer exists (probably at all, but at least as a panel), so kill this background
		CtrlNamedBackground $s.name,kill
		Print "tsw_autoChecks(): tsw panel",s.name," does not exist. Auto checks ending"
		return 1		//return 1 ends
	endif
	
	String pauBgTaskList = bgTask_list("NAME","*"+bgNameAppendStr) //format of this is poorly documented
	if (itemsinlist(pauBgTaskList) < 1)
		tsw_queryAllWheels(panelName)	
	endif
		
	return 0		//return 0 continues 
	
end

//write to the filter wheel com to ask the filter wheel its position
function tsw_promptForPos(comStr)
	String comStr
		
	vdtoperationsport2 $comStr	
	VDT2/P=$comStr  killio	//clear anything in buffer already

	VDTWrite2/O=1/Q "pos?\r"
	if (!V_VDT)
		return -1		//-1 == time out on sending command
	endif
	return 1			//1 == prompt ok
end	

//the next few functions handle the directory architecture for Igor variables used by the panel

// sets the current datafolder to the one for a particular panel device, creating it if necessary
// returns a string containing the path of the previous current DF
Function/S tsw_SetDataFolderForDevice(panelName,moveToSetFolder)
	String panelName
	Variable moveToSetFolder		//pass to move to new folder, otherwise returns to working folder at call of this function

	String SavedFolder = GetDataFolder(1)
	String folderName = tsw_DataFolderNameForDevice(panelName, 0)
	NewDataFolder/O/S root:Packages
	NewDataFolder/O/S TSW
	NewDataFolder/O/S $folderName
	
	if (!moveToSetFolder)
		SetDataFolder savedFolder
	endif
	
	return SavedFolder
end

Function/S TSW_DataFolderNameForDevice(panelName, FullPath)
	String panelName
	Variable FullPath
	
	panelName = CleanupName(panelName, 0)		// folder names can be liberal, but we encode the DF name in a control name, and control names can't be liberal.
	if (FullPath)
		return ks_TSW_FolderPath+PossiblyQuoteName(panelName)+":"
	else
		return panelName
	endif
end

//returns list of current tsw panels. looks in TSW folder in Packages folder
//that should be enough, but it also checks that the panels found based on folders there really exist
//if garbage handling is properly handled on panel window closing (hopefully it is), this shouldnt be an issue, but just in case
function/s tsw_listPanels()
	String SavedFolder = GetDataFolder(1)
	
	if (!datafolderexists(ks_TSW_FolderPath))
		return ""
	endif
		
	setdatafolder ks_TSW_FolderPath

	String possiblePanels = stringbykey("FOLDERS",datafolderdir(1))
	
	String out="",possiblePanel
	Variable i,num=itemsinlist(possiblePanels)
	for (i=0;i<num;i+=1)
		possiblePanel=stringfromlist(i,possiblePanels)
		if (wintype(possiblePanel) == 7)		//is a panel
			out+=possiblePanel+";"
		endif
	endfor	
	SetDataFolder savedFolder
	
	return out
end

//a hook that reacts to killing of the GUI and deletes the associated Igor variables
function tsw_hook(s)
	STRUCT WMWinHookStruct &s

	if (s.eventCode != 2)		// window kill  (2) only
		return 0
	endif	
	
	Print "killing window"
	doupdate
	tsw_delete(s.winName)
end

//deletes the variables associated 
function tsw_delete(tswPanelName)
	String tswPanelName
	
	//kill automatic background check function
	String tsw_autoChecksBgName = GetUserData(tswPanelName, "", "tsw_autoChecksBgName" )
	CtrlNamedBackground $tsw_autoChecksBgName,kill
	
	//close com ports
	tsw_closeAllPorts(tswPanelName,0)
	
	//kill GUI data folders
	String pathToTSWFolder = ks_TSW_FolderPath  
	killdatafolder/Z $pathToTSWFolder
end

//returns currently selected index in a listbox
function tsw_getLBSel(panelName,comStr,wheelNum)
	String panelName,comStr;Variable wheelNum		//may pass either comStr or wheelNum, comstr supercedes

	if (!strlen(comStr))
		String wheelsList = GetUserData(panelName, "", "wheelsList")
		String wheelInfo = stringfromlist(wheelNum,wheelsList)
		comStr = stringfromlist(0,wheelInfo,":")
	endif 
	
	String lbName = comSTr+ ks_listBoxName_AS
	ControlInfo/W=$panelName $lbName	
	return V_Value
end

//this function is useful with GB's notebook.ipf. It can print the wheel positions the chosen notebook
function tsw_printToNotebook(panelStr,setNotebookName)
	String panelStr
	Variable setNotebookName	//pass 1 for a prompt to set notebook name, which is stored as a userdata in the panel window
	
	String notebookWindowName = GetUserData(panelStr, "", "notebookWindowName" )
	
	//prompt for NB name if asked or if a valid window name cant be found
	Variable doNBNamePrompt=setNotebookName || ((strlen(notebookWindowName) < 1) || !wintype(notebookWindowName) )
	
	if (doNBNamePrompt)	
		prompt notebookWindowName,"Notebook Window",popup,winlist("*",";","WIN:16")
		doprompt "Choose a notebook for copying wheel status to",notebookWindowName
		if (V_flag)
			Print "Aborting selection of notebook, wheel status not printed to notebook"
			return 0
		endif
		
		setwindow $panelStr, userdata(notebookWindowName)=notebookWindowName
		Print "NB button notebook name set to",notebookWindowName
	endif
	
	//String posInfo = tsw_getPositions(panelStr)		//USE THIS FOR EXTRA INFO
	String posInfo = tsw_getPositionsShort(panelStr,1,0)	//use this for a more reasonable amount of info
	Notebook $notebookWindowName,text=posInfo
	dowindow/f notebookWindowName;delayupdate
end