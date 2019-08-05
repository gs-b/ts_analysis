#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

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
	String currWheelInfo;variable i
	for (i=0;i<itemsinlist(wheelsList);i+=1)
		currWheelInfo = stringfromlist(i,wheelsList)
		comPanels += Stringfromlist(0,currWheelInfo,":") + ":" + panelName +";"
	endfor	
	
	Variable defaultPrintLogging = 0		//default is to have print logging check box checked (1) or not (0)
	//end default setting definitions
	
	Variable numWheels = itemsinlist(wheelsList)
	
	//set up and instantiate GUI / main panel
	Variable btnFSize = 9
	Variable cbFontSize = 8
	Variable cbWidth=20
	Variable lbMainFontSize = btnFSize
	Variable lbTitleFontSize=7
	Variable btnWidth=30,btnHeight=18
	Variable panelStartPos_left=btnWidth,panelStartPos_top = 0
	Variable lbWidth=60,lbHeight=104
	Variable extraHeight = 96
	Variable panelPosGap_left =lbWidth //- 20
	Variable panelPos_left,panelPos_top	
	Variable left=0,top=0,width = btnWidth+numWheels*lbWidth,height=lbHeight+extraHeight,right=left+width,bottom=top+height
	Variable loggingCBGap = 5
	
	NewPanel/k=1/N=$panelName /W=(left, top, right, bottom ) as panelName + ": extend to ad-hoc add manual ND filters"
	Button setAllBtn win=$panelName,title="\JLSet",proc=tsw_btnHandling,size={btnWidth,20},pos={0,0*btnHeight},fsize=btnFSize,help={"Set the position of all the wheels to the list box selection (the current selection is displayed in underlined bold or italics)"}
	Button queryAll win=$panelName,title="\JLGet",proc=tsw_btnHandling,size={btnWidth,20},pos={0,1*btnHeight},fsize=btnFSize,help={"Get the position of all wheels as they report them"}
	Button logPathBtn win=$panelName,title="\JLPath",proc=tsw_btnHandling,size={btnWidth,20},pos={0,2*btnHeight},fsize=btnFSize,help={"Change backup file log path"}
	Button forceLogBtn win=$panelName,title="\JLLog",proc=tsw_btnHandling,size={btnWidth,20},pos={0,3*btnHeight},fsize=btnFSize,help={"Record wheel states in backup file log"}
	Checkbox printLoggingCB win=$panelName,value=defaultPrintLogging,title="\rPr",pos={0,3.8*btnHeight+loggingCBGap},fsize=cbFontSize,appearance={os9},size={cbWidth,20},help={"Check to print logging to history (Logging to backup file in any case)"}
	Button printToNotebook win=$panelName,title="\JLNB",proc=tsw_btnHandling,size={btnWidth,20},pos={0,4.8*btnHeight},fsize=btnFSize,help={"Send wheel states to an Igor NoteBook"}
	Checkbox showCalsCB win=$panelName,title="\rCA",proc=tsw_calsCBHandling,pos={0,5.6*btnHeight+loggingCBGap},fsize=cbFontSize,appearance={os9},size={cbWidth,20},help={"Check to view effective (calibrated) ND Values"}
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
	
	//new: generates listboxes for each color set; these can display the effective P*/receptor/s for requested lambda and CAs
	String initLambdas="430;531;561;491;480;"		//add new pigments here!
	String initCAs="0.6;0.6;0.6;0.6;0.6;"			//or here!	
	String initNames="s;m;l;rod;mel;"				//of here!
	Variable numInit=max(max(itemsinlist(initLambdas),itemsinlist(initCAs)),itemsinlist(initNames))
	String colLbls="lbl;λ\\Bmax;CA;rel;P*/S;"
	String colsAreEditable="1;1;1;0;0;"
	Variable cols=itemsinlist(colLbls)
	String pStarLbName
	Variable numColorBenches=itemsinlist(colorBenchPosKeyList),colorPos,firstAssociatedPos,numAssocPos,pStarWidth,pStarHeight
	String colorInfo,assocPositions,colorWheelInfo,colorWheelCompStarLWName,colorWheelCom,pStarLWName,pStarSWName
	Variable pos_left,pos_top
	Variable gateProp=0.3		//how much space is devoted to the "gate" set var
	Variable flexSvStart_left,flexSvStart_top,flexSv_width,flexSv_height,gate_width,input_start,input_width
	String flexGateSvName,flexInputSvName,colorWheelName
	String gateHelpStr="Flexibly insert OD vals to the light path here (ideally, pre-calibrated)\r"
	gateHelpStr+="Each potential filter is \"gated\" in this semicolon-delimited list. In the setVariable to the right,\r"
	gateHelpStr+="ND values are entered for each position in "
	String inputHelpStr="Semi-colon delimited list of OD values for each potential filter. Filtered are only applied\r"
	inputHelpStr+="if the corresponding position in the gate list is 1. Each item in the list is\r"
	inputHelpStr+="itself a comma-delim. w/ an OD value for each (bandpass filter) position in "
	for (i=0;i<numColorBenches;i+=1)
		colorInfo=stringfromlist(i,colorBenchPosKeyList)
		colorPos=str2num(stringfromlist(0,colorInfo,":"))
		colorWheelInfo=stringfromlist(colorPos,wheelsList)
		colorWheelCom=stringfromlist(0,colorWheelInfo,":")
		colorWheelName=stringfromlist(1,colorWheelInfo,":")
		assocPositions=stringfromlist(1,colorInfo,":")		//comma delim!
		firstAssociatedPos=str2num(stringfromlist(0,assocPositions,","))
		numAssocPos=itemsinlist(assocPositions,",")
		pos_left = panelStartPos_left + firstAssociatedPos*panelPosGap_left
		pos_top = lbHeight
		pStarWidth=(numAssocPos+1)*lbWidth
		pStarHeight=height-pos_top
		pStarLbName=colorWheelCom+ks_pStarLbName_AS
		pStarLWName=colorWheelCom+ks_pStarListWv_AS
		pStarSWName=colorWheelCom+ks_pStarSelWv_AS
		make/o/t/n=(numInit,cols) $pStarLWName/wave=lw
		make/o/n=(numInit,cols) $pStarSWName/wave=sw
		sw=str2num(stringfromlist(q,colsAreEditable)) ? 2^1 : 0	//sets cols as editable
		dl_assignLblsFromList(lw,1,0,colLbls,"",0)
		lw[][0]=stringfromlist(p,initNames)
		lw[][1]=stringfromlist(p,initLambdas)
		lw[][2]=stringfromlist(p,initCAs)
		listbox $pStarLbName win=$panelName,listwave=lw,selwave=sw,proc=tsw_pStarLbAction,widths={5,5,5,8,10},size={pStarWidth,pStarHeight},pos={pos_left,pos_top},fsize=lbMainFontSize
		note/nocr lw,"pStarLbName:"+pStarLbName+";colorInfo:"+colorInfo+";colorPos:"+num2str(colorPos)+";colorWheelInfo:"+colorWheelInfo+";colorWheelCom:"+colorWheelCom+";assocPositions:"+assocPositions+";"
	
		//handling of flexible additional OD values
		flexSvStart_left=pos_left
		flexSvStart_top=pos_top+pStarHeight
		flexSv_width=pStarWidth
		flexSv_height=10
		gate_width=flexSv_width*gateProp
		input_start=flexSvStart_left+gate_width
		input_width=flexSv_width-gate_width
		flexGateSvName=colorWheelCom+ks_flexGateSv_AS
		flexInputSvName=colorWheelCom+ks_flexInputSv_AS
		SetVariable $flexGateSvName win=$panelName,value=_STR:"0;0;",pos={flexSvStart_left,flexSvStart_top},size={gate_width,flexSv_height},fsize=lbMainFontSize,help={gateHelpStr+colorWheelName}
		SetVariable $flexInputSvName win=$panelName,value=_STR:"0,0,0,0,0,0;0,0,0,0,0,0;",pos={input_start,flexSvStart_top},size={input_width,flexSv_height},fsize=lbMainFontSize,help={inputHelpStr+colorWheelName}
	endfor
end

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
			tsw_configureAllPorts(panel)
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
			tsw_configureAllPorts(panelStr)
			break
		case "printToNotebook":
			Variable shiftDown= (s.eventmod & 2^1)>0
			tsw_printToNotebook(panelStr,shiftDown)
			
		default:
			tsw_log(panelStr)
	endswitch
end

function tsw_calsCBHandling(s) : CheckBoxControl
	STRUCT WMCheckboxAction &s

	//for now only associated with showCalsCB
	if (s.eventcode == 2)
		tsw_setEffectiveNdDispState(s.win,s.checked)
	endif
end

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

function tsw_configureAllPorts(panelName)
	String panelName
	
	string wheelsList = GetUserData(panelName, "", "wheelsList")
	string wheelInfo,comStr
	variable i,num=itemsinlist(wheelsList)
	for (i=0;i<num;i+=1)
		wheelInfo = stringfromlist(i,wheelsList)
		comstr = stringfromlist(0,wheelInfo,":")
		tsw_configurePort(comStr)
	endfor
end

function tsw_configurePort(comStr)
	String comStr
	
		//set each port, error will occur if port not appopriately accessible
	VDTOperationsPort2 $comStr
	Variable err = getrterror(1)
	if (err)
		Print "tsw_configurePort caught error, possibly port is not available. See message. Aborting"
		Print geterrmessage(err)
		return 0
	endif
	VDT2/P=$comStr baud=115200, databits=8, parity=0, stopbits=1	
end

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
	String fullStatusStr=tsw_pStarUpdate(mainPanelStr,1,0,suppressLogDisplay)	//tsw_pStarUpdate(mainPanelStr,1,1,suppressLogDisplay)
	
	String saveStr = notes_getNBTimeStamp(1,"") + posInfo + "|" + fullStatusStr
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

function/S tsw_getPositions(mainPanelStr)
	String mainPanelStr
	
	String pathToDF = TSW_DataFolderNameForDevice(mainPanelStr,1)
	
	String wheelsList = GetUserData(mainPanelStr, "", "wheelsList")
	Variable i,numWheels=itemsinlist(wheelsList)
	String reportedPos = "",comSTr,wheelInfo,listWvRef
	String commandedPos = ""
	for (i=0;i<numWheels;i+=1)
		wheelInfo = stringfromlist(i,wheelsList)		//had been zero in first shared version, so only first wheel was being logged
		comSTr = stringfromlist(0,wheelInfo,":")		//had been zero in first shared version, so only first wheel was being logged
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

//returns current info on all panels
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

function tsw_lbAction(s) : ListboxControl
	STRUCT WMListboxAction &s
	
	if ( s.eventcode == 4)	//cell selection
		//tsw_updateLightInfo(s.win)
		tsw_pStarUpdate(s.win,1,0,1)
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
		
	if (s.row < 0)		//in title box, do update and also reconfigure port
		tsw_configurePort(comStr)
		tsw_pollForPosAndUpdateLB(comStr)
	elseif (s.row < dimsize(listWv,0))		//in bounds selection
		tsw_moveAndUpdateLB(s.row,comStr)	//calls tsw_pollForPosAndUpdateLB after
	endif
	
	return 0
end

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
		Print "tsw_autoChecks() ending"
		return 1		//return 1 ends
	endif
	
	String pauBgTaskList = bgTask_list("NAME","*"+bgNameAppendStr) //format of this is poorly documented
	if (itemsinlist(pauBgTaskList) < 1)
		tsw_queryAllWheels(panelName)	
	endif
		
	return 0		//return 0 continues 
	
end

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


// sets the current datafolder to the one for a particular DAQ device, creating it if necessary
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

function tsw_hook(s)
	STRUCT WMWinHookStruct &s

	if (s.eventCode != 2)		// window kill  (2) only
		return 0
	endif	
	
	Print "killing window"
	doupdate
	tsw_delete(s.winName)
end

function tsw_delete(tswPanelName)
	String tswPanelName
	
	tsw_closeAllPorts(tswPanelName,0)
	String pathToTSWFolder = ks_TSW_FolderPath  
	killdatafolder/Z $pathToTSWFolder
end


//HELPER FUNCTIONS FOR AUTOMATIC RADIOMETER CALIBRATION
//generates a "calPositions" wave that contains command positions to test in calibration with udt radiometer
function udt_genCommandWv(tswPanelName)
	String tswPanelName
	
	Variable minWavelength = 150		//will ignore wavelengths below 150, recommend using 0,-1,-2 etc to specify wavelengths to ignore because they are not band pass

	//wheelsList, benchesList, colorBenchPosKeyList
	String pathToTSWFolder = ks_TSW_FolderPath
	String pathToDF = TSW_DataFolderNameForDevice(tswPanelName,1)	

	SVAR wheelsList = $(pathToDF + "wheelsList")	
	SVAR colorBenchPosKeyList = $(pathToDF + "colorBenchPosKeyList")
	
	Variable numWheels=itemsinlist(wheelsList)
	Variable i,numColorBenches=itemsinlist(colorBenchPosKeyList)
	
	String dfSav = getdatafolder(1)
	setdatafolder(pathToDF)
	Variable initNumRows=1000	//not worth pre-calculating total num rows, will adjust if necessary
	Make/o/n=(1000, numWheels) calPositions; calPositions=0
	
	//colorBenchPosKeyList is benchNum0:bench0ColorWheelPos;benchNum1:bench1ColorWheelPos;...
	
	Variable colorWheelPos
	String colorWheelStr
	String associatedIndices
	String colorWheelInfoStr		//wheelList info for the color wheel
	String colors			//color info for the color wheel (listed values on tsw_panel)
	Variable j,numColors
	String colorStr
	variable color
	Variable k,numAssociated
	Variable row_ind=0,assocStartCol=0,colorBenchStartRow,colorStartRow,minNumNDs
	Variable associatedWheelPos
	Variable infRow,openRow,infPos,infCol,targetCol,z
	String associatedWheelInfoStr
	String associatedNDs,allAssociatedNDs
	String noAttenuationTestInds
	Variable numNDs,ndInd,ndVal
	String ndValStr,rowLbl
	Variable rowTemp
	for (i=0;i<numColorBenches;i+=1)
		colorWheelStr=stringfromlist(i,colorBenchPosKeyList)
		colorWheelPos=str2num(stringfromlist(0,colorWheelStr,":"))
		colorWheelInfoStr=stringfromlist(colorWheelPos,wheelsList)
		colors=replacestring(",",stringfromlist(2,colorWheelInfoStr,":"),";")
		numColors=itemsinlist(colors)
		colorBenchStartRow=row_ind;
		for (j=0;j<numColors;j+=1)
			colorStr=stringfromlist(j,colors)
			color=str2num(colorStr)
			if (color < minWavelength)
				continue
			endif
			
			colorStartRow=row_ind
			allAssociatedNDs=""
			infRow=nan
			infCol=nan
			openRow=nan
			infPos=nan
			minNumNDs=inf
			associatedIndices=replaceSTring(",",stringfromlist(1,colorWheelStr,":"),";")
			numAssociated=itemsinlist(associatedIndices)
			
			for (k=0;k<numAssociated;k+=1)
				associatedWheelPos=str2num(stringfromlist(k,associatedIndices))
				associatedWheelInfoStr=stringfromlist(associatedWheelPos,wheelsList)
				associatedNDs=stringfromlist(2,associatedWheelInfoStr,":")
				allAssociatedNDs+= associatedNDs+";"		//store to find index where all have ND0 for unattenated row
				associatedNDs=replacestring(",",associatedNDs,";")
				numNDs=itemsinlist(associatedNDs)
				if (numNDs < minNumNDs)
					minNumNDs = numNDs
				endif
				
				//anything associated with other color wheels remains zero for now .. later we go in and set to the inf row
				
				for (ndInd=0;ndInd<numNDs;ndInd+=1)
					//fill in zero for columns other than targetCol (assocStartcol + k)
					targetCol = assocStartCol+k	;
					calPositions[row_ind][assocStartCol,assocStartCol+numAssociated-1] = (q==targetCol) ? ndInd : 0
					
					//find first instance of a full stop for this color
					ndVal=str2num(stringfromlist(ndInd,associatedNDs))
					if (numtype(infRow) && numtype(ndVal) == 1)		//look for inf row if havent found yet; assumes +/- inf indicates full stop
						infRow=row_ind
						infPos=ndInd
						infCol=targetCol
					endif
					
					row_ind+=1
				endfor	//endfor for positions in associated wheel
				
			endfor	//endfor for associated wheels
			
			//find position where all wheels are open for this color.. where the sum of NDs is zero
			for (z=0;z<minNumNDs;z+=1)
				for (k=0;k<numAssociated;k+=1)
					associatedNDs=stringfromlist(k,allAssociatedNDs)
					ndValStr=stringfromlist(z,associatedNDs,",")
					if (!stringmatch(ndValStr,"0"))
						break
					endif
				endfor
				
				if (k==numAssociated)	//this index finished inner loop, so all ndVals were "0"
					openRow=colorStartRow+z
				endif
			endfor
			
			//assign labels to rows for this color
			rowLbl = colorStr + "_" + num2str(i) + "_" + num2str(infRow) + "_" + num2str(openRow)
			for (rowTemp=colorStartRow;rowTemp<row_ind;rowTemp+=1)		
				SetDimLabel 0,rowTemp,$rowLbl,calPositions
			endfor
			calPositions[colorStartRow,row_ind-1][colorWheelPos]=j
			
		endfor	//endfor for this color
		
		//make sure this color bench is closed for rows that are not calibrating it.. set those outside to inf
		calPositions[][infCol]= (p <colorBenchStartRow) || (p >= row_ind) ? infPos : calPositions[p][infCol]
		
		//iterate column index
		assocStartCol+=numAssociated+1			//move over by the number of columns used by this past color: numAssociated + one for the color itself
	endfor		//endfor for all colors
	
	
	Redimension/n=(row_ind+1,-1) calPositions		//leave an extra row, which will have been set to inf positions for all color benches
															//so that the default end state is both benches closed
	edit/k=1 calPositions.ld
	
	setdatafolder(dfSav)
end

//only handles two OD benches
function tsw_setCalWv3(panelName,summaryWv,[newCalPosWvToSet,forceDfSav,noPhPerSqUmPerSCheck])
	String panelName
	WAVE summaryWv		//summary results from UDT cal
	WAVE newCalPosWvToSet	//optionally pass a new calibration pos wv, overwrites the one stored for the panel, pass "" to keep current one
	String forceDfSav			//pass a data folder to move to after completion -- used in recursive instance with prompt (user shouldnt need to pass)
	Variable noPhPerSqUmPerSCheck	//optionally pass true to suppress phPerSqUmPerS value recovery (passed by this function to avoid infinite loop)
	
	Variable skipLastCalRow=1		//set this if last row is a placeholder to end calibration with both benches closed
	
	Variable infReplaceVal = 1e8			//must match variable of same name in flash_getCalVal2()
	
	String pathToTSWFolder = ks_TSW_FolderPath
	String pathToDF = TSW_DataFolderNameForDevice(panelName,1)	
	String dfSav
	if (PAramIsDefault(forceDfSav))
		dfSav = getdatafolder(1)
	else
		dfSav = forceDfSav
	endif
	setdatafolder(pathToDF)
	WAVE calPositions		//commanded positions generated by udt_genCommandWv() and used in calibration
	SVAR colorBenchPosKeyList		//color bench sets
	SVAR wheelsList
	Duplicate/o summaryWv, calSummary;
	
	if (!PAramIsDefault(newCalPosWvToSet))
		Duplicate/o newCalPosWvToSet,calPositions
	endif
	
	//generate output calibration waves (one for each color bench)
	//format of columns are wavelength,OD bench 0, OD bench 1, OD bench 2, ... , photons per micron sq per s
	//one row per calibration
	Variable i,numColorBenches=itemsinlist(colorBenchPosKeyList)
	Variable numAssociated		//num associated non-color wheels
	String colorBenchInfo
	String associatedWheelsList
	Variable j,numAssociatedWheels
	String calWvList="",calWvRef
	String calWvStartStr=ks_calWvStr_SS
	for (i=0;i<numColorBenches;i+=1)
		calWvRef=calWvStartStr+num2str(i)
		calWvList+=calWvRef+";"
		
		colorBenchInfo=stringfromlist(i,colorBenchPosKeyList)		///ordered wheelNumOfColorBench:wheelNumOfFirstAssociated,wheelNumOfSecondAssociated,...
		associatedWheelsList=replacestring(",",stringfromlist(1,colorBenchInfo,":"),";")
		numAssociatedWheels=itemsinlist(associatedWheelsList)
		make/o/d/n=(1,numAssociatedWheels+2) $calWvRef
		SetDimLabel 1,0,cw,$calWvRef 
		for (j=0;j<numAssociatedWheels;j+=1)
			setdimlabel 1,1+j,$("OD"+num2str(j)),$calWvRef
		endfor
		SetDimLabel 1,1+numAssociatedWheels,phPerUmSqPerS,$calWvRef 
	endfor
	
	Variable num=dimsize(summaryWv,0) - skipLastCalRow
	
	//find all rows for each color, then iterate through them and record the necessary info
	String rowsForEachColor="",rowsForColor
	String infoStr,colorBenchNumStr
	Variable colorBenchNum
	Variable currRow
	String colorInfoStr
	Variable cw,associatedWheelNum
	Variable photonsPerSqUmPerSWarned=0
	Variable noChecking = !ParamIsDefault(noPhPerSqUmPerSCheck) && noPhPerSqUmPerSCheck
	String wheelInfo,associatedVals
	make/o/n=(numColorBenches)/free rowCountForEachColor
	rowCountForEachColor=0		//iterates rows found for each color
	for(i=0;i<num;i+=1)
		infoStr=GetDimLabel(calPositions, 0, i )
		colorInfoStr=stringfromlist(0,infoStr,"_")
		cw=str2num(colorInfoStr)
		colorBenchNumStr=stringfromlist(1,infoStr,"_")
		colorBenchNum=str2num(colorBenchNumStr)
		currRow=rowCountForEachColor[colorBenchNum]
		rowCountForEachColor[colorBenchNum]+=1
		calWvRef=calWvStartStr+num2str(colorBenchNum)
		WAVE calWv=$calWvRef
		redimension/n=(currRow+1,-1) calWv
		SetDimLabel 0,currRow,$infoStr,calWv
		
		colorBenchInfo=stringfromlist(colorBenchNum,colorBenchPosKeyList)		///ordered wheelNumOfColorBench:wheelNumOfFirstAssociated,wheelNumOfSecondAssociated,...
		associatedWheelsList=replacestring(",",stringfromlist(1,colorBenchInfo,":"),";")
		numAssociatedWheels=itemsinlist(associatedWheelsList)
		
		calWv[currRow][0]=cw
		for (j=0;j<numAssociatedWheels;j+=1)
			associatedWheelNum=str2num(stringfromlist(j,associatedWheelsList))
			wheelInfo=stringfromlist(associatedWheelNum,wheelsList)
			associatedVals=replacestring(",",stringfromlist(2,wheelInfo,":"),";")
			calWv[currRow][1+j]=str2num(stringfromlist(summaryWv[i][associatedWheelNum],associatedVals))
			calWv[currRow][1+j]= numtype(calWv[currRow][1+j]) == 1 ? infReplaceVal : calWv[currRow][1+j]			//
		endfor
		calWv[currRow][1+numAssociatedWheels]=summaryWv[i][%photonsPerSqUmPerS]
		
		if (!noChecking && !photonsPerSqUmPerSWarned && numtype(summaryWv[i][%photonsPerSqUmPerS]))
			photonsPerSqUmPerSWarned = 1
			print "tsw_setCalWv3() Warning photonsPerSqUmPerS column at row",num2str(i),"has no value. likely need to set a spot size for calibration. seeking user input..."
			Double spotDiaOrArea
			Variable spotSizeIsArea=0
			prompt spotDiaOrArea,"Cal spot dia. (um) or area (um^2):"
			prompt spotSizeIsArea,"set true for area, false for dia."
			doprompt "Enter spot dia or area",spotDiaOrArea,spotSizeIsArea
			
			if (V_Flag || numtype(spotDiaOrArea))
				continue						// User canceled or passed a non-number
			else
				//calculate area if necessary
				if (!spotSizeIsArea)
					spotDiaOrArea = pi*(spotDiaOrArea/2)^2
				endif				
				summaryWv[][%photonsPerSqUmPerS]=summaryWv[p][%photonsPerS]/spotDiaOrArea
				note/nocr summaryWv,"calibrationAreaSqMicron:"+num2str(spotDiaOrArea)+";"
			
				tsw_setCalWv3(panelName,summaryWv,forceDfSav=dfSav,noPhPerSqUmPerSCheck=1)
				return 0
			endif
		endif
	endfor
	
	//sort by wavelength, which makes determination of intensity easier ( see flash_getCalVal2() )
	//reverse order so ODs end up brightest to dimmest
	Variable sortCols
	for (i=0;i<numColorBenches;i+=1)
		calWvRef=stringfromlist(i,calWvList)
		switch (numAssociatedWheels)
			case 1:
				SortColumns/kndx={0,1}/r/diml sortWaves={$calWvRef}
				break
			case 2:
				SortColumns/kndx={0,1,2}/r/diml sortWaves={$calWvRef}
				break	
			case 3:
				SortColumns/kndx={0,1,2,3}/r/diml sortWaves={$calWvRef}
				break
			case 4:
				SortColumns/kndx={0,1,2,3,4}/r/diml sortWaves={$calWvRef}
				break			
			case 5:
				SortColumns/kndx={0,1,2,3,4,5}/r/diml sortWaves={$calWvRef}
				break
			case 6:
				SortColumns/kndx={0,1,2,3,4,5,6}/r/diml sortWaves={$calWvRef}
				break			
			default:
				SortColumns/kndx={0}/r/diml sortWaves={$calWvRef}
		endswitch
	endfor
	
	setdatafolder(dfSav)
	
end

//calculates effective NDs for every color-associated bench
//must already have
//0) have a tsw_panel running with tsw_startpanels()
//1) generated a calPositions wv (e.g., with udt_getCommandWv() or manually)
//2) calibrated the bench with udt_start() and thereby generated a calSummaryWv
//3) stored the calibration results via tsw_setCalWv3()
function tsw_calcEffectiveNDs(panelName)
	String panelName
	
	String pathToTSWFolder = ks_TSW_FolderPath
	String pathToDF = TSW_DataFolderNameForDevice(panelName,1)	
	String dfSav  = getdatafolder(1)
	setdatafolder(pathToDF)
	WAVE calPositions		//commanded positions generated by udt_genCommandWv() and used in calibration
	SVAR colorBenchPosKeyList		//color bench sets
	SVAR wheelsList	
	
	Variable i,j,numColorBenches=itemsinlist(colorBenchPosKeyList)
	String zeroRows = ""
	String maxIntensityWvAppendStr=ks_maxIntensityWv_AS		//for color benches, a wave storing the unattenuated photon flux
	String effectiveListWaveAppendStr = ks_effectiveListWv_AS		//for list wave effective OD. must match tsw_setEffectiveNdDispState() variable of same name
	String calWvStartStr=ks_calWvStr_SS
	String colorBenchInfo,associatedBenchPositions,colorBenchWheelInfo,colorBenchCom,colorBenchLWRef,colorBenchVals
	Variable numAssociated,numPossibleColors,numColorBenchLWRows,colorBenchPos
	String associatedInfo,associatedCom,associatedLWRef,associatedEffLwRef,unattenuatedNDList,tNdList,associatedVals,intensityStr,maxIntensityRef
	Variable associatedPos,numAssocPos,numRemaining
	Variable y,z
	Double currSum,currCount,val
	String currCW
	String associatedEffLwList	//tracks associated waves for each color bench, stored in maxIntensityRef wave note
	for (i=0;i<numColorBenches;i+=1)
		String calWvRef=calWvStartStr+num2str(i)
		WAVE calWv=$calWvRef
		colorBenchInfo=stringfromlist(i,colorBenchPosKeyList)
		colorBenchPos=str2num(stringfromlist(0,colorBenchInfo,":"))
		associatedBenchPositions=replacestring(",",stringfromlist(1,colorBenchInfo,":"),";")
		numAssociated=itemsinlist(associatedBenchPositions)
		colorBenchWheelInfo=stringfromlist(colorBenchPos,wheelsList)
		colorBenchCom=stringfromlist(0,colorBenchWheelInfo,":")
		colorBenchVals=replacestring(",",stringfromlist(2,colorBenchWheelInfo,":"),";")
		numPossibleColors=itemsinlist(colorBenchVals)
		
		//get max unattenuated intensities for all wavelendths on this bench
		maxIntensityRef=colorBenchCom+maxIntensityWvAppendStr
		make/o/d/n=(numPossibleColors) $maxIntensityRef/wave=miWv
		for (y=0;y<numPossibleColors;y+=1)		//probably redundent with the other call to this below where it is printed to a string ..
			currCW=stringfromlist(y,colorBenchVals)
			miWv=flash_getCalVal2(calWv,str2num(currCW),text_getRepeatedStr("0;",numAssociated),1,0)
		endfor
		associatedEffLwList=""
		for (j=0;j<numAssociated;j+=1)
			associatedPos=str2num(stringfromlist(j,associatedBenchPositions))
			associatedInfo=stringfromlist(associatedPos,wheelsList)
			associatedCom=stringfromlist(0,associatedInfo,":")
			associatedVals=replacestring(",",stringfromlist(2,associatedInfo,":"),";")
			numAssocPos=itemsinlist(associatedVals)
			associatedEffLwRef=associatedCom+"_"+colorBenchCom+effectiveListWaveAppendStr
			associatedEffLwList+=associatedEffLwRef+","
			make/o/t/n=(numAssocPos,numPossibleColors) $associatedEffLwRef/wave=aELW
			dl_assignLblsFromList(aELW,0,0,associatedVals,"",0)
			dl_assignLblsFromList(aELW,1,0,colorBenchVals,"",0)
			numRemaining=numAssociated-j-1
			unattenuatedNDList=text_getRepeatedStr("0;",numAssociated)
			tNdList=text_getRepeatedStr("0;",j)+"1;"+=text_getRepeatedStr("0;",numRemaining)		//template ND list
			aeLW=num2str( flash_getCalVal2(calWv,str2num(stringfromlist(0,stringfromlist(q,colorBenchVals),"-")),replaceString("1",tNdList,stringfromlist(p,associatedVals)),1,1) )
			
			//calculate max intensity and store in wave note, semi-colon delim list same order as columns (colors).. will be displayed in title box
			String noteStr=""
			for (y=0;y<numPossibleColors;y+=1)
				currCW=stringfromlist(0,GetDimLabel(aeLW, 1, y),"-")
				if (stringmatch(currCW,"0"))	//no bandpass .. cant compute
					noteStr+="White,"
				else
					sprintf intensityStr, "%1.1e", flash_getCalVal2(calWv,str2num(currCW),text_getRepeatedStr("0;",numAssociated),1,0)
					noteStr+=intensityStr + ","
				endif
			endfor
			
			note/nocr aeLW, "tsw_phPerSqUmPerS:"+noteStr+";"
		
			//calculate averages for white light .. pain in the ass because of NaNs
			Make/o/d/n=(numAssocPos)/free avgs
			for (y=0;y<numAssocPos;y+=1)
				currSum=0
				currCount=0
				for (z=0;z<numPOssibleColors;z+=1)
					val = str2num(aeLW[y][z])
					if (numtype(val) != 2)		//count all non-NaNs; one inf will ruin them all!
						currSum+=val
						currCount+=1
					endif
				
				endfor
				
				avgs[y] = currSum / currCount
			endfor
			
			//copy avg into any white light conditions (cw = 0)
			for (z=0;z<numPOssibleColors;z+=1)
				currCW = stringfromlist(0,GetDimLabel(aeLW, 1, z),"-")
				if (stringmatch(currCw,"0"))
					aeLW[][z] = num2str(avgs[p])
				endif
			endfor
		endfor
		note/nocr miWv, "associatedEffLwList:"+associatedEffLwList+";"		//associatedEffLwList is comma delim
		
	
	endfor
	
	
	setdatafolder(dfSav)
end

function/D flash_getCalVal2(calWv,cw,odListWvRefOrListStr,strListNotListWv,returnEffectiveND)
	WAVE calWv		//must be grouped by wavelength: all rows of one center wavelength (cw) must be contiguous
	Double cw			//cw to check
	String odListWvRefOrListStr	//list of ODs for wheels associated with wavelength e.g., if wave ref "{2,3}" or "2;3;4;" if string
	Variable strListNotListWv		//determines whether to treat odListWvRefOrListStr as a wave list (if zero is passed) or as a string list (if 1 is passed)
	Variable returnEffectiveND	//pass 1 to return effective ND instead of intensity, which is returned otherwise
	
	Variable numPassedODs
	if (strListNotListWv)
		numPassedODs=itemsinlist(odListWvRefOrListStr)
		make/o/free/n=(numPassedODs)/free odListWv
		odListWv=str2num(stringfromlist(p,odListWvRefOrListStr))
	else
		WAVE odListWv = $odListWvRefOrListStr
		numPassedODs=dimsize(odListWv,0)
	endif
	
	Variable infReplaceVal = 1e8			//cant do integer search for infs, replace them .. should match variable of same name in tsw_setCalWv3()
	odListWv = numtype(odListWv[p]) == 1 ? 1e8 : odListWv[p]	

	variable i,calRows=dimsize(calwv,0),calCols=dimsize(calwv,1)
	Variable maxNumODsInCalWv=calCols-2		//two columns are not related to associated wheel ODs, cw col and intensity col
	Variable intensityCol=calCols-1		//last row is always intensity column (phPerUmSqPerS)
	Double cw_tol=0.4
	Double odTol=0.0025		//figure no one is using an od lower than this
	Double zeroIntensityTol = 1e-8			//intensity in phPerSqUmPerS tolerance.. below this the intensity is considered zero
	
	if (cw < cw_tol)
		return nan
	endif
	
	//sort out center wavelengths
	matrixop/free/o cws=col(calwv,0);redimension/n=(-1) cws
	
	//find start of cw
	findvalue/T=(cw_tol)/V=(cw)/Z cws
	Variable firstCwRow=V_value
	
	if (firstCwRow < 0)
		Print "flash_getCalVal FAILED calWv FAILED TO FIND cw in CALVAL",nameofwave(calWv),"cw",cw,"odListWv",odListWv
		return nan
	endif
	
	//find end of cw
	matrixop/free/o cws=reverseCol(cws,0);redimension/n=(-1) cws
	findvalue/T=(cw_tol)/V=(cw)/Z cws

	if (v_Value < 0)
		Print "flash_getCalVal FAILED calWv FAILED TO FIND cw in CALVAL, when looking in reverse (this should never happen!)",nameofwave(calWv),"cw",cw,"odListWv",odListWv		//never should happen bc if no cw of this value it would have returned on the first search
		return nan
	endif	

	Variable lastCwRow=calRows-1-v_Value
	
	//find out which case we are in: no filters attenuated, just one filter attenuated, multiple attenuated, all attenuated
	Variable numAttenuated=0,od,isAttenuated,firstAttenuatedPos=-1
	make/o/n=(numPassedODs)/free isAttenuatedList
	for (i=0;i<numPassedODs;i+=1)
		od=odListWv[i]
		isAttenuated=od >= odTol
		numAttenuated+=isAttenuated
		isAttenuatedList[i]=isAttenuated
		
		if (isAttenuated && (firstAttenuatedPos < 0))
			firstAttenuatedPos = i
		endif
	endfor
	
	if (returnEffectiveND && (numAttenuated < 1) )
		return 0
	endif
	
	Variable checkCol,nonZeroColFound,findCol,j
	Double findVal
	
	if ((numAttenuated == 1) && !returnEffectiveND)		//case A: all attenuation is set by one filter .. if effectiveND is wanted, skip this and do comparison to unattenuated
		findVal = odListWv[firstAttenuatedPos]
		findCol = 1+firstAttenuatedPos		//one spacer col before ODs begin in calWv (that is the cw col)
		
		for (i=firstCwRow;i<=lastCwRow;i+=1)
			if ( abs(calWv[i][findCol]-findVal) < odTol )		//find rows that match the findVal
				//then check that all other columns are truly zero
				nonZeroColFound=0
				for (j=0;j<maxNumODsInCalWv;j+=1)
					checkCol=1+j
					if (checkCol != findCol)		//found a column that is not the findCol, make sure its zero
						if ( calWv[i][checkCol] > odTol )
							nonZeroColFound=1
							break
						endif
					endif	
				endfor
				
				if (!nonZeroCOlFound)			//all other columns were indeed zero
					return calWv[i][intensityCol]
				endif
		
			endif
		endfor
		
		Print "flash_getCalVal FAILED calWv FAILED TO FIND single OD with other site attenuated in CALVAL",nameofwave(calWv),"cw",cw,"odListWv",odListWv
		return nan
	endif
	
	
	//other cases: neither is attenuated or more than one is. these cases require finding the totally unattenuated row
	Variable unattenuatedRow=-1
	for (i=firstCwRow;i<=lastCwRow;i+=1)
		nonZeroColFound=0
		for (j=0;j<maxNumODsInCalWv;j+=1)
			checkCol=1+j
			if ( calWv[i][checkCol] > odTol )
				nonZeroColFound=1
				break
			endif	
		endfor
		
		if (!nonZeroColFound)
			unattenuatedRow = i
			break
		endif
	endfor
	
	if (unattenuatedRow < 0)		//failed to find an unattenuated row!
		Print "flash_getCalVal FAILED calWv FAILED TO FIND unattenuated row in calwave",nameofwave(calWv),"cw",cw,"odListWv",odListWv
		return nan
	endif
		
	//case B: no attenuation, we can just return the value in the unattenuated row
	//in case of returnEffectiveND request, this case has been dealt with because numAttenuated < 1
	if (numAttenuated < 1)
		return calWv[unattenuatedRow][intensityCol]
	endif
		
	//case C: attenuation in two or more, we need to find the transmittance through all individual filters and then sum up
	//(or effectiveND was requested and need to compare 1 or more vs unattenuated)
	Double unattenuatedVal=calWv[unattenuatedRow][intensityCol]
		
	Variable odNum
	Double transmittance,totalTransmittance=1,intensity
	make/o/d/free/n=(numPassedODs) transmittances; transmittances=nan
	for (odNum=0;odNum<numPassedODs;odNum+=1)
		if (!isAttenuatedList[odNum])	
			transmittance=1			//no attenuation, assumes transmits 100% of light
					
		else
			//this part is much like for the case of just one being attenuated .. would be better to fold both into a new function
			
			findVal=odListWv[odNum]
			findCol=1+odNum
			
			for (i=firstCwRow;i<=lastCwRow;i+=1)			//for all possible rows
				if ( abs(calWv[i][findCol]-findVal) < odTol )		//find rows that match the findVal
					//then check that all other columns are truly zero
					nonZeroColFound=0
					for (j=0;j<maxNumODsInCalWv;j+=1)
						checkCol=1+j
						if (checkCol != findCol)		//found a column that is not the findCol, make sure its zero
							if ( calWv[i][checkCol] > odTol )
								nonZeroColFound=1
								break
							endif
						endif	
					endfor
					
					if (!nonZeroCOlFound)			//all other columns were indeed zero
						intensity=calWv[i][intensityCol]
						if (intensity < zeroIntensityTol)		//likely zero because we are looking at a full stop .. we can return at this point
							
							if (returnEffectiveND)
								return inf
							else
								return 0
							endif
							
						endif
						transmittance=intensity / unattenuatedVal
						break
					endif
			
				endif
			endfor		
		endif
				
		transmittances[odNum]=transmittance
		totalTransmittance*=transmittance
	endfor
	
	double totalOD=-log(totalTransmittance)
	intensity=unattenuatedVal * totalTransmittance
	
	if (numtype(totalTransmittance))
		Print "flash_getCalVal failed to final unattenuated vals for all OD wheels! in calwv",nameofwave(calWv),nameofwave(calWv),"cw",cw,"odListWv",odListWv,"totalTransmittance",totalTransmittance
	endif
	
	if (returnEffectiveND)
		return totalOD
	else
		return intensity
	endif
end

//sets whether effective NDs from calibrations are shown or standard names/values
function tsw_setEffectiveNdDispState(panelName,showEffective)
	String panelName
	Variable showEffective //zero to hide, one to show
	
	String effectiveListWaveAppendStr = ks_effectiveListWv_AS		//for list wave effective OD. Must match tsw_calcEffectiveNDs() variable of same name
	String altListWaveAppendStr = ks_altListWv_AS		//alternative list wave stored in com#_appendStr .. subbed in when showEffective=true
	String altTitleWaveAppendStr = ks_altTitleWv_AS
	String maxIntensityWvAppendStr=ks_maxIntensityWv_AS		//for color benches, a wave storing the unattenuated photon flux
	
	String pathToTSWFolder = ks_TSW_FolderPath
	String pathToDF = TSW_DataFolderNameForDevice(panelName,1)	
	String dfSav  = getdatafolder(1)
	setdatafolder(pathToDF)
	SVAR colorBenchPosKeyList		//color bench sets
	SVAR wheelsList	
	
	Variable i
	if (showEffective)
		Variable j,numColorBenches=itemsinlist(colorBenchPosKeyList),numPos,colorWheelSelectedPos,numAssocPositions,assocPos,colorBenchPos
		String colorBenchInfo,colorWheelInfo,colorWheelCom,colorWheelLBName,assocPositions,assocWheelInfo,assocCom,assocLbName,effectiveLWRef,altListWaveRef,altTitleWaveRef,effectiveLwNote,effectiveIntensities
		String associatedEffLwRef,associatedEffLwList,maxIntensityRef
		for (i=0;i<numColorBenches;i+=1)
			colorBenchInfo=stringfromlist(i,colorBenchPosKeyList)
			colorBenchPos=str2num(stringfromlist(0,colorBenchInfo,":"))
			colorWheelInfo=stringfromlist(colorBenchPos,wheelsList)
			numPos = itemsinlist(colorWheelInfo,",")
			colorWheelCom=stringfromlist(0,colorWheelInfo,":")
			maxIntensityRef=colorWheelCom+maxIntensityWvAppendStr
			associatedEffLwList = replacestring(",",stringbykey("associatedEffLwList",note($maxIntensityRef)),";")
			colorWheelLBName=colorWheelCom+ks_listBoxName_AS
			controlinfo/w=$panelName $colorWheelLBName
			colorWheelSelectedPos=V_Value
			if ( (colorWheelSelectedPos < 0) || (colorWheelSelectedPos >= numPos ) )
				continue		//move onto another color because no selection here
			endif
			assocPositions=replacestring(",",stringfromlist(1,colorBenchInfo,":"),";")
			numAssocPositions=itemsinlist(assocPositions)
			for (j=0;j<numAssocPositions;j+=1)
				assocPos=str2num(stringfromlist(j,assocPositions))
				assocWheelInfo=stringfromlist(assocPos,wheelsList)
				assocCom=stringfromlist(0,assocWheelInfo,":")
				assocLbName=assocCom+ks_listBoxName_AS
				effectiveLWRef=stringfromlist(j,associatedEffLwList)
				if (waveExists($effectiveLWRef))
					altListWaveRef=assocCom+altListWaveAppendStr
					altTitleWaveRef=assocCom+altTitleWaveAppendStr
					Duplicate/o/r=[*][colorWheelSelectedPos] $effectiveLWRef, $altListWaveRef
					make/o/t/n=(1) $altTitleWaveRef/wave=altTitleWv
					effectiveLwNote=note($effectiveLWRef)
					effectiveIntensities=stringbykey("tsw_phPerSqUmPerS",effectiveLwNote)
					altTitleWv="\Z08"+stringfromlist(colorWheelSelectedPos,effectiveIntensities,",")
					listbox $assocLbName win=$panelname,listwave=$altListWaveRef,titleWave=altTitleWv
				endif
			endfor
		
		
		endfor
		
	else
		
		Variable num=itemsinlist(wheelsList)
		String wheelInfo,com,lbName,lwName,title,twName
		for (i=0;i<num;i+=1)
			wheelInfo = stringfromlist(i,wheelsList)
			com=stringfromlist(0,wheelInfo,":")
			title=stringfromlist(1,wheelInfo,":")
			lbName=com+ks_listBoxName_AS
			lwName=com+ks_listWaveName_AS
			twName=com+ks_titleWaveName_AS
			listbox $lbName win=$panelname,listwave=$lwName,titlewave=$twName
			
		endfor
	
	endif

	setdatafolder (dfSav)
	
end

function tsw_pStarLbAction(s) : ListboxControl
	STRUCT WMListboxAction &s
	
	if (s.eventcode == 7)		//end edit
		tsw_pStarCalcs(s.win,s.listwave,0,0,1)
	endif
end

function/S tsw_pStarCalcs(panelName,listWave,displayOnly,doLogging,suppressLogDisplays)
	String panelName
	WAVE/T listwave		//wave in question
	Variable displayOnly		//pass to update display (cases where no editing to listbox has been done)
	Variable doLogging		//uses ACTUAL BENCH POSITIONS instead of USER SELECTIONS 
	Variable suppressLogDisplays
	
	
	Variable doDisplay= !doLogging || !suppressLogDisplays
	
	String benchIntensityStateAppendStr="_is"
	String benchIntensityStateRef=panelName+benchIntensityStateAppendStr
	String nomoValsAppendStr=ks_nomoVals_AS				//calculates adjusted maximal flux for all colors
	String maxIntensityWvAppendStr=ks_maxIntensityWv_AS		//for color benches, a wave storing the unattenuated photon flux
	String effectiveListWaveAppendStr = ks_effectiveListWv_AS		//for list wave effective OD. must match tsw_setEffectiveNdDispState() variable of same name
	
	String pathToTSWFolder = ks_TSW_FolderPath
	String pathToDF = TSW_DataFolderNameForDevice(panelName,1)	
	String dfSav  = getdatafolder(1)
	setdatafolder(pathToDF)
	SVAR colorBenchPosKeyList		//color bench sets
	SVAR wheelsList	
	
	Variable lblCol=0
	Variable lambdaCol=1		//is set upon instantiating the listbox
	Variable caCol=2
	Variable relCol=3
	Variable pStarCol=4
	
	String lwInfo=note(listwave)
	Variable colorPos=str2num(stringbykey("colorPos",lwInfo))
	String colorWheelCom=stringbykey("colorWheelCom",lwInfo)
	String assocPositions=replacestring(",",stringbykey("assocPositions",lwInfo),";")
	String colorWheelInfo=stringbykey("colorWheelInfo",lwInfo)
	String colorWheelName=stringfromlist(1,colorWheelInfo,":")
	String colorWheelVals=replacestring(",",stringfromlist(2,colorWheelInfo,":"),";")
	Variable i,numColorVals=itemsinlist(colorWheelVals)
	
	String statusStr="colorWheelName:"+colorWheelName+";"
	
	Variable numLambdas=dimsize(listwave,0)
	String maxPStarRef=colorWheelCom+nomoValsAppendStr
	Make/o/free/n=(numColorVals) colorWheelValsWv
	make/o/free/n=(numLambdas) lambdasWv
	colorWheelValsWv=str2num(stringfromlist(0,stringfromlist(p,colorWheelVals),"-"))
	lambdasWv=str2num(listwave[p][lambdaCol])
	
	if (!displayOnly || !WaveExists($maxPStarRef) || (dimsize($maxPStarRef,0) != numLambdas) )
		make/o/d/n=(numLambdas,numColorVals) $maxPStarRef/wave=maxPStarWv
		for (i=0;i<numLambdas;i+=1)
			SetDimLabel 0,i,$listwave[i][lblCol],maxPStarWv
		endfor
		dl_assignLblsFromList(maxPStarWv,1,0,colorWheelVals,"",0)
		maxPStarWv= (colorWheelValsWv[q] > 0) ? nomo_x(lambdasWv[p],colorWheelValsWv[q]) : Nan 	
	else
		WAVE maxPStarWv = $maxPStarRef
	endif
	
	//first find what color is SELECTED (display) or ACTUALLY SET IN WHEEL POS (log)
	if (doLogging)
		String benchPositions=tsw_getPositions(panelName)
		String reportedPositions=stringbykey("reportedPos",benchPositions,"-","|")
		Variable actColorPos=numberbykey(colorWheelCom,reportedPositions)
		if (numtype(actColorPos))
			setdatafolder (dfSav); return statusStr
		endif
	else	
		String colorWheelComLB=colorWheelCom+ks_listBoxName_AS
		ControlInfo/w=$panelname $colorWheelComLB
		Variable row = V_Value
		if ( (row<0) || (row>=numColorVals) )
			print "faila";setdatafolder (dfSav); return statusStr
		endif
	endif
	
	Variable lookupColorCol= doLogging ? actColorPos : row
	
	if (doLogging)
		statusStr+="colorPos:"+num2str(lookupColorCol)+";"
	endif
	
	Variable colorVal=colorWheelValsWv[lookupColorCol]
	Variable isWhite = colorVal < 1
	if (isWhite)		//cant calculate for white as not sure of spectrum
		if (doDisplay)
			listwave[][relCol]="white"
			listwave[][pStarCol]="white"
		endif
		if (doLogging)
			statusStr+="colorVal:"+num2str(colorVal)+";"
		endif
		setdatafolder (dfSav); return statusStr
	endif
	
	String relStr,statusLbl
	for (i=0;i<numLambdas;i+=1)
		if (doDisplay)
			sprintf relStr, "%1.3f" , maxPStarWv[i][lookupColorCol]
			listwave[i][relCol]=relStr
		endif
		
		if (doLogging)
			sprintf relStr,"%1.10f",maxPStarWv[i][lookupColorCol]
			statusLbl=listwave[i][lblCol]+"_rel:"
			statusStr+=statusLbl+relStr+";"
		endif
	endfor
		
	//now need to get info from last light calibration, if available
	String maxIntensityRef=colorWheelCom+maxIntensityWvAppendStr
	String unattenuatedIntensity
	WAVE/D/Z miWv=$maxIntensityRef
	if (!WaveExists(miWv))		//if not accessible, we are done here
		//PLACE OF FAILURE / ABORT WHEN NO CALIBRATIONS HAVE BEEN ENTERED
		setdatafolder (dfSav); return statusStr
	endif
	
	if (doLogging)
		sprintf unattenuatedIntensity,"%2.20e",miWv[lookupColorCol]
		statusStr+="unattenuatedIntensity:"+unattenuatedIntensity+";"
	endif
	
		//get the relative attenuation from associated wheels
	string associatedEffLwRef,assocWheelInfo,associatedCom,associatedLB
	String associatedEffLwList = replacestring(",",stringbykey("associatedEffLwList",note(miWv)),";")
	String assocWheelNDVals
	Variable numAssoc=itemsinlist(associatedEffLwList),assocWheelPos
	double calOD=0,totalOD
	String nomNDStr,associatedName
	Variable nomND,nominalTotalOD=0		//only calc'd if logging for now
	for (i=0;i<numAssoc;i+=1)
		//get calibrated OD values
		assocWheelPos=str2num(stringfromlist(i,assocPositions))
		assocWheelInfo=stringfromlist(assocWheelPos,wheelsList)
		associatedCom=stringfromlist(0,assocWheelInfo,":")
		associatedName=stringfromlist(1,assocWheelInfo,":")
		
		associatedEffLwRef=stringfromlist(i,associatedEffLwList)
		WAVE/Z/T aeLW = $associatedEffLwRef		//rows are rows in the associated wheel, cols are rows in the color wheel, values are OD
		if (!WAveExists(aeLW))
			print "faild";setdatafolder (dfSav); return statusStr
		endif
		
		//find selection
		if (doLogging)
			row=numberbykey(associatedCom,reportedPositions)
			if (numtype(row))
				setdatafolder (dfSav); return statusStr
			endif
			statusStr+=associatedName+"_pos:"+num2str(row)+";"
			assocWheelNDVals=replacestring(",",stringfromlist(2,assocWheelInfo,":"),";")
			nomNDStr=stringfromlist(row,assocWheelNDVals)
			statusStr+=associatedName+"_nomOD:"+nomNDStr+";"			//nominal OD
			nominalTotalOD+=str2num(nomNDStr)
		else
			associatedLB=associatedCom+ks_listBoxName_AS
			controlinfo/w=$panelname $associatedLB
			row = V_Value
		endif
		if ( (row<0) || (row>=numColorVals) )
			statusStr+=associatedName+"_calOD:NaN;"
			calOD+=0
		else
			calOD+=str2num(aeLW[row][lookupColorCol])
			
			if (doLogging)
				statusStr+=associatedName+"_pos:"+aeLW[row][lookupColorCol]+";"
			endif
		endif
	endfor
	
	//handle any flexible manual NDs added
	String gateSvName=colorWheelCom+	ks_flexGateSv_AS
	String inputSvName=colorWheelCom+ks_flexInputSv_AS
	ControlInfo/W=$panelName $gateSvName 
	String gateStr=S_Value
	ControlInfo/W=$panelName $inputSvName 
	String inputStr=S_Value,currInputVals
	Variable numPotentialFlex=itemsinlist(gateStr),currNumInputs
	Variable use,flexOD=0
	for (i=0;i<numPotentialFlex;i+=1)
		use=str2num(stringfromlist(i,gateStr))
		if (use)
			currInputVals=replacestring(",",stringfromlist(i,inputStr),";")
			currNumInputs=itemsinlist(currInputVals)
			if (lookupColorCol>=currNumInputs)		//fewer inputs than color being used, try to use first
				flexOD+=str2num(stringfromlist(0,currInputVals))
			else
				flexOD+=str2num(stringfromlist(lookupColorCol,currInputVals))
			endif
		endif
	endfor
	
	totalOD=calOD + flexOD
	
	if (doLogging)
		statusStr+="nomTotalOD:"+num2str(nominalTotalOD)+";"
		statusStr+="calTotalOD:"+num2str(calOD)+";"
		statusStr+="flexTotalOD:"+num2str(flexOD)+";"
		statusStr+="totalOD:"+num2str(totalOD)+";"
	endif
	
	String pStarStr; Double val,unattenuatedVal,noCAVal
	for (i=0;i<numLambdas;i+=1)
		unattenuatedVal=maxPStarWv[i][lookupColorCol]*str2num(listwave[i][caCol])*miWv[lookupColorCol]
		val=unattenuatedVal*10^(-totalOD)
		if (doDisplay)
			sprintf pStarStr, "%1.1e" , val
			listwave[i][pStarCol]=pStarStr
		endif
		
		if (doLogging)
			noCAVal=maxPStarWv[i][lookupColorCol]*miWv[lookupColorCol]*10^(-totalOD)
			
			sprintf pStarStr,"%2.20e",val
			statusLbl=listwave[i][lblCol]+"_pStar:"
			statusStr+=statusLbl+pStarStr+";"
			
			sprintf pStarStr,"%2.20e",unattenuatedVal
			statusLbl=listwave[i][lblCol]+"_pStarUn:"		//pStar unattenuated
			statusStr+=statusLbl+pStarStr+";"	
			
			sprintf pStarStr,"%2.20e",noCAVal
			statusLbl=listwave[i][lblCol]+"_pStarNC:"		//pStar no collecting area factor
			statusStr+=statusLbl+pStarStr+";"
		endif
	endfor
	
	if (doLogging)
		statusStr+="gateStr:"+replacestring(";",gateStr,"<>")+";"
		statusStr+="inputStr:"+replacestring(";",gateStr,"<>")+";"
	endif
	
	setdatafolder (dfSav)
	
	return statusStr
end

function/S tsw_pStarUpdate(panelName,displayOnly,doLogging,suppressLogDisplays)
	String panelName
	Variable displayOnly		//pass to update display (cases where no editing to listbox has been done)
	Variable doLogging		//uses ACTUAL BENCH POSITIONS instead of USER SELECTIONS 
	Variable suppressLogDisplays
	
	return ""
	
	String pathToDF = TSW_DataFolderNameForDevice(panelName,1)	
	
	String pStarLBs=ControlNameList(panelName,";","*"+ks_pStarLbName_AS),pStarLB
	Variable i,num=itemsinlist(pStarLBs)
	String fullStatusStr="",statusStr
	for (i=0;i<num;i+=1)
		pStarLB=stringfromlist(i,pStarLBs)
		ControlInfo/w=$panelName  $pStarLB
		statusStr=tsw_pStarCalcs(panelName,$(pathToDF+S_value),displayOnly,doLogging,suppressLogDisplays)	
		fullStatusStr += statusStr+"|"
	endfor
	
	return fullStatusStr
end

//RELATED TO AUTOMATIC CALIBRATION WITH UDT RADIOMETER
//commmandWave should have one column for each wheel, one row for each measurement
//row dimension labels must start with the wavelength at which the radiometer should read
//row dimension labels should also have the bench number, from 0 on, of each bench, in order of where the wheels occur in the commandWv columns (which should match the control GUI)
//finally, row dim labels should also have the row that is being used as a dark control, or nan for no dark control. This is a measurement that will be taken with a full-stop in the light path
//These items in the row dim label are separated by "_". so to measure on bench 1 at 480 with row 15 as the dark control, the label is: 480_1_15
//in each row, specify the position each wheel should be at (0 to 5) during the measurement
//that's all that's needed to get started

//my standard setup for using this function is to have the radiometer on calibration 2 (meant for uncapped measurement) with averaging set to 2 seconds
//udt_apertureArea_umSq is not strictly necessary (just pass 1 or nan to ignore it). It's just used in calculating the flux density (per micron square) automatically. 

//further analysis is performed after this function completes with udt_analyze(), which is called automatically
//it can also be called at any time on its on using the output wave of this function (udt_lastCalWv, or a copy of it)
function udt_start(tswPanelName,comStr,commandWave,udt_apertureArea_umSq)
	String tswPanelName	//name of tsw panel containing benches to calibrate, e.g. "tsw_panel" which is my default. Pass "" to use this automatically
	String comStr
	WAVE commandWave			//wave containing one 
	Variable udt_apertureArea_umSq	//pass for automated conversion to photons per micron sq per s (or pass something like 1 to deal with it later)
	
	Variable tsw_waitTime_move = 9		//number of seconds to wait for movement completion. 10 is safe. could make it a closed loop, but adds complexity
	Variable averagingDur = 2			//how many seconds of averaging the radiometer is set to do (options are 0,1,2,5 I believe) -- my standard is 2. check for stability at time of reads
	Variable tsw_waitTime_range = averagingDur + 1	//number of seconds to wait for range change to ready steady state .. can be zero if no averaging, usually set equal to amount of averaging
	Variable udt_rangeStart = 3	//include range start, min is 3 -- as of now no error handling for outside range
	Variable udt_rangeEnd = 10	//inclusive range end, max is 10 -- as of now no error handling for outside range
	Variable numReads = 6		//num reads at sampling rate for each test condition; it doesn't add much time to read more
	
	if (!Strlen(tswPanelName))
		tswPanelName = "tsw_panel"
	endif
		
	vdt2/P=$comStr baud=115200
	
	//SET UP: ADJUST DEPENDING ON YOUR BENCHES
	
	//COPY THIS FROM tsw_startPanel() function -- note, must specify inf for a full stop to get background subtraction
			//if you don't, I recommend either subtracting it on the UDT GUI or writing it down seperately
			//alternatively, you could pair this with an arduino and a shutter, but that would take some 
			//modifications
	String wheelsList = ""
	wheelsList += "COM11:B0_ND_C:0,1,2,3,4,inf;"			//add a line for each wheel to define. port_used:user_desc:pos0,pos1,pos2,pos3,pos4,pos5
	wheelsList += "COM10:B0_ND_F:0,0.3,0.6,1.0,1.3,2;"	//avoid these characters-- ;,|- (last one is a dash) --except as required by this format
	wheelsList += "COM9:B0_WL:0,442-10,460-10,500-10,560-10,588-20;"	//544-10 is actually 543.5-10
	
	wheelsList += "COM12:B1_ND_C:0,1,2,3,4,inf;"			
	wheelsList += "COM14:B1_ND_F:0,0.3,0.6,1.0,1.3,2;"
	wheelsList += "COM13:B1_WL:530-10,442-10,544-10,500-10,560-10,600-10;"	
					
	doupdate;ToCommandLine "//CtrlNamedBackground udt_calBG kill 	//run this to stop calibration"				//give user a way to escape the madness!										
	doupdate
	
	//make the output wave	
	Variable numBenchesInCal = dimsize(commandWave,1)		//one column for each bench involved (any other should be set as desired beforehand)
	Variable numBenchCols = numBenchesInCal * 3						//output wave: 3 columns per bench, requested position (copied from commandWave), set position (what the bench reports), set value (the value for the set position based on wheelsList)
	Variable numRows = dimsize(commandWave,0)				//one row for each test case
	Variable numRanges = udt_rangeEnd - udt_rangeStart + 1			//add one bc inclusive
	Variable numNonReadCols = 4	//for each range: keep the actual range (1) keep all the reads (numReads), plus the mean, SD, and SEM of those reads (3)
	Variable numMeasurementCols = numRanges * (numReads + numNonReadCols)	
	Variable numCols = numBenchCols +  numMeasurementCols
	String commandWvRef = nameofwave(commandWave)
	Make/O/D/N=(numRows,numCols) udt_lastCalWv
	udt_lastCalWv = nan
	note udt_lastCalWv,""	//just make sure we are starting fresh
	Variable i,j; string benchStr,benchCom,benchLbl
	
	//label wave for clarity -- first bench values
	for (i=0;i<numBenchesInCal;i+=1)
		benchStr = Stringfromlist(i,wheelsList)
		benchCom = stringfromlist(0,benchStr,":")
		benchLbl = stringfromlist(1,benchStr,":")
		SetDimLabel 1,3*i,$(benchLbl+"_reqPos"),udt_lastCalWv
		SetDimLabel 1,3*i+1,$(benchLbl+"_setPos"),udt_lastCalWv
		SetDimLabel 1,3*i+2,$(benchLbl+"_setVal"),udt_lastCalWv
	endfor
	
	//then range values
	Variable startCol,range; string lblStr
	for (i=0;i<numRanges;i+=1)
		startCol = 3*numBenchesInCal + i*(numReads+4)
		range = udt_rangestart + i
		lblStr = "rng" + num2str(range) 
		setDimlabel 1,startCol,$(lblStr+"_actual"),udt_lastCalWv
		for (j=0;j<numReads;j+=1)
			setdimlabel 1,startCol+1+j,$(lblStr+"_rep"+num2str(j)),udt_lastCalWv
		endfor
		setdimlabel 1,startCol+1+numReads+0,$(lblStr+"_avg"),udt_lastCalWv
		setdimlabel 1,startCol+1+numReads+1,$(lblStr+"_sd"),udt_lastCalWv
		setdimlabel 1,startCol+1+numReads+2,$(lblStr+"_sem"),udt_lastCalWv
	endfor
	
	String noteStr="comStr:"+comStr+"|numReads:"+num2str(numReads)+"|averagingDur:"+num2str(averagingDur)+"|"
	noteStr+= "tswPanelName:"+tswPanelName+"|"
	noteStr+= "commandWvRef:"+commandWvRef+"|"
	noteStr+= "|wheelsList:"+wheelsList+"|numCols:"+num2str(numCols)+"|"
	noteStr+= "numRows:"+num2str(numRows)+"|"
	noteStr+= "udt_rangeStart:"+num2str(udt_rangeStart)+"|"
	noteStr+= "udt_rangeEnd:"+num2str(udt_rangeEnd)+"|"
	noteStr+= "numBenchCols:"+num2str(numBenchCols)+"|"
	noteStr+= "numRanges:"+num2str(numRanges)+"|"
	noteStr+= "numMeasurementCols:"+num2str(numMeasurementCols)+"|"
	noteStr+= "numNonReadCols:"+num2str(numNonReadCols)+"|"
	noteStr+= "readAttempts:"+num2str(0)+"|"		//tracks number of read attempts	..moves on after a limit specified in in udt_calBGFunc
	noteStr+= "tsw_waitTime_move:"+num2str(tsw_waitTime_move)+"|"
	noteStr+= "averagingDur:"+num2str(averagingDur)+"|"
	noteStr+= "tsw_waitTime_range:"+num2str(tsw_waitTime_range)+"|"
	noteStr+= "tsw_ticksAtLastMove:"+num2str(nan)+"|"	//will hold time of last movement command for wait times
	noteStr+= "tsw_ticksAtLastRngChg:"+num2str(nan)+"|"	//will hold time of last range change command for wait times
	noteStr+= "row:"+num2str(0)+"|"		//tracks position in the wave, updated each time a new measure is completed
	noteStr+= "currRangeNum:"+num2str(0)+"|" //tracks reads into the wave, updated each time a new measure is completed
	noteStr+= "status:"+num2str(0)+"|"		//status in control loop:
													//0 means move to next setting
													//1 means read once movement is complete
													
	noteStr+= "setWavelength:"+num2str(nan)+"|"		//track what wavelength the udt has been set to, so we can avoid setting it again if its already set
	noteStr+= "moveJustOccured:"+num2str(0)+"|"		//track whether a move has occured, which allows program to determine whether to use tsw_waitTime_move or tsw_waitTime_range for a wait time
	noteStr+= "udt_apertureArea_umSq"+Num2str(udt_apertureArea_umSq)+"|"												
	note udt_lastCalWv, noteStr
	
	edit/k=1 udt_lastCalWv.ld
	
	CtrlNamedBackground udt_calBG, start=120,period=45, proc=udt_calBGFunc,stop=0
end

function udt_calBGFunc(s)
	STRUCT WMBackgroundStruct &s
	
	Variable maxreadAttempts = 5		//moves on to next measurement after this many read attempts
	
	WAVE/D udt_lastCalWv
	
	String noteStr = note(udt_lastCalWv)
	String udt_comStr=stringbykey("comStr",noteStr,":","|")
	Variable wi,status = NumberByKey("status",noteStr,":","|")
	Variable numWheels
	String tswPanelName = stringbykey("tswPanelName",noteStr,":","|")
	String commandWvRef = stringbykey("commandWvRef",noteStr,":","|")
	String wheelsList = stringbykey("wheelsList",noteStr,":","|")
	Variable row = NumberByKey("row",noteStr,":","|")
	Variable currRangeNum = NumberByKey("currRangeNum",noteStr,":","|")
	Variable udt_rangeStart = NumberByKey("udt_rangeStart",noteStr,":","|")
	Variable numRanges = NumberByKey("numRanges",noteStr,":","|")
	Variable numReads = NumberByKey("numReads",noteStr,":","|")
	Variable readAttempts = NumberByKey("readAttempts",noteStr,":","|")
	Variable numBenchCols = NumberByKey("numBenchCols",noteStr,":","|")
	Variable numMeasurementCols = NumberByKey("numMeasurementCols",noteStr,":","|")
	Variable tsw_ticksAtLastMove=NumberByKey("tsw_ticksAtLastMove",noteStr,":","|")
	Variable tsw_ticksAtLastRngChg=NumberByKey("tsw_ticksAtLastRngChg",noteStr,":","|")
	Variable numNonReadCols=NumberByKey("numNonReadCols",noteStr,":","|")
	Variable setWavelength = numberbykey("setWavelength",noteStr,":","|")
	Variable udt_apertureArea_umSq = numberbykey("udt_apertureArea_umSq",noteStr,":","|")	//beware of precision issues with text converting! better to call analysis function separately
	Variable moveJustOccured = nan
	String cmdRangeStr
	WAVE commandWv = $commandWvRef
	Make/O/N=(numReads)/D udt_reads
	
	Variable waiting = 0
		
	if (status == 0)		//start a new measurement, go to positions
		numWheels = dimsize(commandWv,1)
		Variable cmdWheelPos, moveLikelyOccured = 0		//moveOccured will track whether movement actually had to be made
		String wheelStr,comStr,wheelCom,colorValStr
		for (wi=0;wi<numWheels;wi+=1)
			//get filter positions
			wheelStr=stringfromlist(wi,wheelsList)
			wheelCom = stringfromlist(0,wheelStr,":")
			cmdWheelPos=commandWv[row][wi]
			//write filter positions
			moveLikelyOccured += tsw_moveAndUpdateLB(cmdWheelPos,wheelCom)
		endfor
		
		//handle timing for movement
		if (moveLikelyOccured)		//if a move occured update move time
			tsw_ticksAtLastMove=ticks;noteStr=ReplaceStringByKey("tsw_ticksAtLastMove", noteStr, num2str(tsw_ticksAtLastMove),":", "|")	//note when last move occured for proper waiting
			noteStr=ReplaceStringByKey("moveJustOccured", noteStr, num2str(1),":", "|")	
		else							//if not, leave ticksAtLastMove as is, so when it is checked it will be past time, so the program can move on immediately
			noteStr=ReplaceStringByKey("moveJustOccured", noteStr, num2str(0),":", "|")	
		endif
		
		//get color read value
		colorValStr=stringfromlist(0,GetDimLabel(commandWv, 0, row),"_")	//new format for label -- used to just be lambda, now it's lambda_benchOfInterest
		colorValStr=stringfromlist(0,colorValStr,"-")
		Variable colorVal = str2num(colorValStr)
		//print "colorValStr",colorValStr,"colorVal",colorVal
		if (numtype(setWavelength) || (colorVal != setWavelength)) //if wavelength not set, set it then wait to clear that command and response from buffer
			vdt2/P=$udt_comStr killio; vdtoperationsport2 $udt_comStr; VDTWrite2/O=1 "1WVL "+colorValStr+"\r"		//set color
			status = 1;noteStr=ReplaceStringByKey("status", noteStr, num2str(status),":", "|")		//update status to clear command next time
		else
			//run range command now instead of at status == 1, code should be as for status == 1:
			cmdRangeStr = "1RNG " + num2str(udt_rangeStart+currRangeNum) +"\r"	//command range val string
			vdt2/P=$udt_comStr killio;vdtoperationsport2 $udt_comStr;VDTWrite2/O=1 cmdRangeStr	//run command str
			status = 2;noteStr=ReplaceStringByKey("status", noteStr, num2str(status),":", "|")	//move onto reading	
		endif
		//call this a range change whether color changes or ranged changed, so store its time
		tsw_ticksAtLastRngChg=ticks;noteStr=ReplaceStringByKey("tsw_ticksAtLastRngChg", noteStr, num2str(tsw_ticksAtLastRngChg),":", "|")

	elseif (status == 1)
		vdt2/P=$udt_comStr killio		//clear result of commanding different color
		cmdRangeStr = "1RNG " + num2str(udt_rangeStart+currRangeNum) +"\r"		//command range val string
		vdt2/P=$udt_comStr killio;vdtoperationsport2 $udt_comStr;VDTWrite2/O=1 cmdRangeStr	//run command str
		status = 2;noteStr=ReplaceStringByKey("status", noteStr, num2str(status),":", "|")		//move onto reading
	
	elseif (status == 2) //clear result of changing range
			vdt2/P=$udt_comStr killio;vdtoperationsport2 $udt_comStr;vdt2/P=$udt_comStr killio
		status = 3;noteStr=ReplaceStringByKey("status", noteStr, num2str(status),":", "|")
		
	elseif (status == 3)		//wait set time, then prompt for a read
		moveJustOccured = NumberByKey("moveJustOccured",noteStr,":","|")		//determine appopriate wait time: waiting for move or range change
		Variable tsw_waitTime,tsw_ticksAtLast
		if (moveJustOccured)		//move timing takes precedence over range change timing.. if ever used a fast filter wheel it might be better to take a maximum between the two
			tsw_waitTime = NumberByKey("tsw_waitTime_move",noteStr,":","|")
			tsw_ticksAtLast = NumberByKey("tsw_ticksAtLastMove",noteStr,":","|")		
		else
			tsw_waitTime = NumberByKey("tsw_waitTime_range",noteStr,":","|")
			tsw_ticksAtLast = NumberByKey("tsw_ticksAtLastRngChg",noteStr,":","|")		
		endif
		Variable dt=ticks-tsw_ticksAtLast
		if ((dt) >= (60*tsw_waitTime) )
			//send command to read
			vdt2/P=$udt_comStr killio;vdtoperationsport2 $udt_comStr;VDTWrite2/O=1 "1REA "+num2str(numReads)+"\r"
			status = 4;noteStr=ReplaceStringByKey("status", noteStr, num2str(status),":", "|")
		endif	//else, continue and wait (status stays at 3)
		
	elseif (status == 4)
		
		//attempt a read of values
		vdtoperationsport2 $udt_comStr;
		VDTgetstatus2 0,0,0
		
		if (V_VDT > 2)		//data to read
			Variable col,i; string out
			udt_reads = nan		//stores reads
			
			col = numBenchCols+(numNonReadCols+numReads)*currRangeNum +1	//1 is for offset where actual reported range is stored (not yet implemented)
			VDTRead2/O=1/T="\r" out;	//first is a junk return
			for (i=0;i<numReads;i+=1)
				VDTRead2/O=1/T="\r" out;
				udt_reads[i] = str2num(out)			
			endfor
			udt_lastCalWv[row][col,col+numReads-1] = udt_reads[q-col]
			udt_lastCalWv[row][col+numReads] = mean(udt_reads)
			udt_lastCalWv[row][col+numReads+1] = sqrt(variance(udt_reads))
			udt_lastCalWv[row][col+numReads+2] = udt_lastCalWv[row][col+numReads+1]/numReads
			status = 0;noteStr=ReplaceStringByKey("status", noteStr, num2str(status),":", "|")
			readAttempts = 0;noteStr=ReplaceStringByKey("readAttempts", noteStr, num2str(readAttempts),":", "|")
			
			//move on to next if read was successful
			currRangeNum += 1
			if (currRangeNum >= numRanges)
				currRangeNum = 0 	//go back to first range
				row+= 1
			endif
			if (row >= dimsize(udt_lastCalWv,0))
				String summaryWaveRef = commandWvRef + "_S"
				Print "COMPLETED UDT CAL. CAlled udt_analyze() to make summary wave:", summaryWaveRef
				udt_analyze(commandWv,udt_lastCalWv,summaryWaveRef,udt_apertureArea_umSq)
				
				return 1		//stop
			endif
			noteStr=ReplaceStringByKey("row", noteStr, num2str(row),":", "|")
			noteStr=ReplaceStringByKey("currRangeNum", noteStr, num2str(currRangeNum),":", "|")
			vdt2/P=$udt_comStr killio
			doupdate;		//sped up by only updating after data is collected?
			
		else	
			waiting = 1		//only for tracking/debugging purposes
			readAttempts += 1
			
			//move on to next if read attempts has maxed out
			if (readAttempts > maxReadAttempts)
				Print "row=",row,"currRangeNum",currRangeNum,"reached max read attempts, skipping"
				vdt2/P=$udt_comStr killio
				currRangeNum += 1
				if (currRangeNum >= numRanges)
					currRangeNum = 0 	//go back to first range
					row+= 1
				endif
				
				noteStr=ReplaceStringByKey("row", noteStr, num2str(row),":", "|")
				noteStr=ReplaceStringByKey("currRangeNum", noteStr, num2str(currRangeNum),":", "|")
				readAttempts = 0
				status = 0;noteStr=ReplaceStringByKey("status", noteStr, num2str(status),":", "|")
			endif
			
			noteStr=ReplaceStringByKey("readAttempts", noteStr, num2str(readAttempts),":", "|")
			
		endif
	
	
	endif //endif for status 4
	
	//update note with any changes, then continue
	note/K udt_lastCalWv,noteStr
	return 0		//continue (returning 1 stops)	
		
end

//must make sure calPositionsWv is updated form with each row note as #_#_# where #1 is measured wavelength on radiometer, #2 is bench to measure, and #3 is dark row
function udt_analyze(calPositionsWv,calResultsWv,outRef,udt_apertureArea_umSq,[runsHighRangeToLow])
	WAVE calPositionsWv,calResultsWv	//as passed to udt_start() function, wv is the calibration results wave
	STring outRef		//ref to store results
	Double udt_apertureArea_umSq		//area of aperture for light hitting radiometer during measurement (in square microns!) .. my 60x radius is 69.44444444444 um, so pass pi*(69.44444444444)^2
	Variable runsHighRangeToLow		//old format of calResultsWv, ranges run from high to low
	
	Variable numReadRows = dimsize(calResultsWv,0)
	Variable numOutputParams = 14
	
	Variable runBackwards=!paramIsdefault(runsHighRangeToLow) && runsHighRangeToLow
	
	Duplicate/o calPositionsWv, $outRef/wave=out
	Variable origNumCols = dimsize(out,1)
	String resultsNote = note(calResultsWv)
	Variable numRanges = Numberbykey("numRanges", resultsNote , ":", "|")
	Variable udt_rangeStart = Numberbykey("udt_rangeStart", resultsNote , ":", "|")
	Variable udt_rangeEnd = udt_rangeStart + numRanges-1
	Variable numReads = Numberbykey("numReads", resultsNote , ":", "|")
	Variable i,j
	
	String dataStartLabel = "rng"+num2str(udt_rangeStart) + "_actual"
	Variable dataStartCol = finddimlabel(calResultsWv,1,dataStartLabel)
	Variable numColsPerRange = numReads + 4		//one columns before raw reads as space holder, 3 columns after (mean, sd,sem)
	
	Variable out_numStatsCols = 4	//one column for range level, one each for mean, sd,sem
	Variable out_totalNumStatsCols = out_numStatsCols * numRanges	
	Variable totalOutCols = origNumCols + out_totalNumStatsCols+ numOutputParams
	Redimension/D/N=(-1,totalOutCols) out
	
	//transfer summary range info -- goes column by column through results wave and output wave
	//all steps occur on all rows
	Variable outCol,currRangeNum,avgCol
	for (i=0;i<numRanges;i+=1)
		if (runBackwards)
			avgCol = dataStartCol-(i*numColsPerRange)+1+numReads	//skip one column in addition to all the reads due to the placeholder column (labeled rng#_actual
		else
			avgCol = dataStartCol+(i*numColsPerRange)+1+numReads	//skip one column in addition to all the reads due to the placeholder column (labeled rng#_actual
		endif
		outCol = origNumCols + i*out_numStatsCols
		currRangeNum = udt_rangeStart + i
		out[][outCol] = currRangeNum	//take down what range this is
		outCol += 1		//add one to output column
		out[][outCol,outCol+2] = calResultsWv[p][avgCol+q-outCol]		//transfer all the means,sd,sem for this columns
		SetDimLabel 1,outCol-1,$("rng" + num2str(currRangeNum)),out
		SetDimLabel 1,outCol,$("rng" + num2str(currRangeNum) + "_avg"),out
		SetDimLabel 1,outCol+1,$("rng" + num2str(currRangeNum) + "_sd"),out
		SetDimLabel 1,outCol+2,$("rng" + num2str(currRangeNum) + "_sem"),out
	endfor
	
	//for each read, find the last and second to last non-saturating range value
	Variable lastAvgCol = dataStartCol+((numRanges-1)*numColsPerRange)+1+numReads
	Variable paramsStartCol = origNumCols + out_totalNumStatsCols
	
	SetDimlabel 1,paramsStartCol,$"1stNonSaturatingRng",out
	SetDimlabel 1,paramsStartCol+1,$"1st_avg",out
	SetDimlabel 1,paramsStartCol+2,$"1st_sd",out
	SetDimlabel 1,paramsStartCol+3,$"1st_sem",out
	Variable finalValueCol = paramsStartCol+1		//column of "final" value before dark subtraction
	
	//transfer this to the appropriate column in the summary wave
	for (i=0;i<numReadRows;i+=1)
		for (j=0;j<numRanges;j+=1)
			avgCol = lastAvgCol - numColsPerRange*j
			if (!numtype(calResultsWv[i][avgCol]))		//real number, so this is the first real range reading
					currRangeNum = udt_rangeEnd - j
					out[i][paramsStartCol] = currRangeNum
					out[i][paramsStartCol+1] = calResultsWv[i][avgCol]
					out[i][paramsStartCol+2] = calResultsWv[i][avgCol+1]
					out[i][paramsStartCol+3] = calResultsWv[i][avgCol+2]
				break
			endif
		endfor
	endfor
	
	//for each read, find out wavelength, what bench is being measured, and what row contains a dark measurement for this
	setdimlabel 1,paramsStartCol+4,wavelength,out
	out[][paramsStartCol+4] = str2num(stringfromlist(0,GetDimLabel(out, 0, p ),"_"))
	setdimlabel 1,paramsStartCol+5,benchNum,out
	out[][paramsStartCol+5] = str2num(stringfromlist(1,GetDimLabel(out, 0, p ),"_"))
	setdimlabel 1,paramsStartCol+6,darkRow,out
	out[][paramsStartCol+6] = str2num(stringfromlist(2,GetDimLabel(out, 0, p ),"_"))
	Variable darkCol = paramsStartCol+6
	setdimlabel 1,paramsStartCol+7,unattenuatedRow,out
	out[][paramsStartCol+7] = str2num(stringfromlist(3,GetDimLabel(out, 0, p ),"_"))	
	Variable unattCol = paramsStartCol+7		//unattenuated column
	
	//someday might automate finding these dark and unattenuated rows
	//what row contains a dark measurement for each wavelength? (uses first found)
		//first, what wavelengths are there that were measured
//	String lambdas = "",darkRows="",od0Rows=""
//	for (i=0;i<numReadRows;i+=1)
//		lambda = stringfromlist(0,GetDimLabel(out, 0, i ),"_")
//		if (whichlistitem(lambda,lambdas) < 0)	//first time seeing this lambda..find info on it
//			lambdas+= lambda +";"
//			//dark row
//			darkRow=-1,od0Row=-1
//			for (j=i;j<numReadRows;j+=1)
//				
//			endfor
//		endif
//	endfor
	
	//for each read, calculate the dark-subtracted avg
	setdimlabel 1,paramsStartCol+8,avgMinusDark_W,out //for this row: if no dark value (nan/inf), use the final value as is
	//otherwise: get the final value, subtract from it the final value in this row's dark row
	out[][paramsStartCol+8] = numtype(out[p][darkCol]) ? out[p][finalValueCol] : (out[p][finalValueCol] - out[out[p][darkCol]][finalValueCol])
	
	//convert to uW for easy reading
	setdimlabel 1,paramsStartCol+9,avgMinusDark_uW,out
	out[][paramsStartCol+9] = out[p][q-1] * 10^6
	
	//convert from W to ph/s
	Double h = 6.626070040*10^-34		//J*s/photon (plank's constant)
	Double c = 	299792458*10^9		//nm/s from constant in m/s * 10^9 nm per m
	
	//calculate photons/s 
	setdimlabel 1,paramsStartCol+10,photonsPerS,out
	out[][paramsStartCol+10] = out[p][q-2] / (h*c/out[p][paramsStartCol+4])		//start with W = J/s. divide by J*S/ph and by nm/S and by 1/nm for ph/s
	
	//calculate photons/um2/s
	setdimlabel 1,paramsStartCol+11,photonsPerSqUmPerS,out
	out[][paramsStartCol+11] = out[p][q-1] / udt_apertureArea_umSq
	
	//calculate relative attenuation from (raw - dark)/(raw_unattenuated - dark) 
	setdimlabel 1,paramsStartCol+12,attenuation,out
	out[][paramsStartCol+12] = numtype(out[p][unattCol]) ? nan : ( out[p][paramsStartCol+8] / out[out[p][unattCol]][paramsStartCol+8] )
	
	//for display, calculate log relative attenuation
	setdimlabel 1,paramsStartCol+13,log_attenuation,out
	out[][paramsStartCol+13] = log(out[p][q-1])
end

function tsw_setCalWv2(panelName,calPositionsWv,resultsWv,summaryWv,calibrationSetList,pigmentSetList)
	String panelName
	WAVE calPositionsWv,resultsWv,summaryWv
	String calibrationSetList	//list of numbers color wheels, with each ND associated with them, e.g. "2:0,1,;5:3,4,;"
	String pigmentSetList			//set of names and lambda maxes for pigments of interest. e.g., "S_opsin:430;M_opsin:530;L_opsin:560;"
	
	String pathToTSWFolder = ks_TSW_FolderPath
	String pathToDF = TSW_DataFolderNameForDevice(panelName,1)	
	
	String dfSav = getdatafolder(1)
	setdatafolder(pathToDF)
	Duplicate/o calPositionsWv, calPositions; note/nocr calPositions,"tsw_setCalWv_name:"+nameofwave(calPositionsWv)+";"
	Duplicate/o resultsWv, calResults; note/nocr calPositions,"tsw_setCalWv_name:"+nameofwave(calResults)+";"
	Duplicate/o summaryWv, calSummary; note/nocr calPositions,"tsw_setCalWv_name:"+nameofwave(calSummary)+";"
	String noteStr=note(resultsWv)
	String wheelsList = stringbykey("wheelsList",noteStr,":","|")
	
	Variable num=dimsize(summaryWv,0),i,j,k
	variable numPigments=itemsinlist(pigmentSetList)
	Variable numColorBenches=itemsinlist(calibrationSetList)
	Variable numCols=numPigments
	//how many colors for each color bench?
	
	Variable currColor,colorsCount,currColorBandwidth; string currLbl,colorsForBench,currColorInfo,currColorStr,currColorBandwidthStr
	String pigmentInfo
	Variable pigmentLambda
	
	String pigmentCalcRefList = ""		//stores list of pigment calcs, one for each bench in order
	
	Variable unattenuatedCol=FindDimLabel(summaryWv, 1, "unattenuatedRow" ); //what columns contains the row with the unattenuated value for a reading (at a given color)
	Variable unattenuatedRow
	Variable readingCol=FindDimLabel(summaryWv, 1, "photonsPerSqUmPerS" )
	Double photonsPerSqUmPerS//for each color
	for (i=0;i<numColorBenches;i+=1)
		make/o/d/n=(1,numPigments+1) $("B_" + num2str(i) + "_pigmentCalcs")/wave=pigmentCalcs
		pigmentCalcRefList += getwavesdatafolder(pigmentCalcs,2) + ";"
		colorsForBench = "";colorsCount=0
		for (j=0;j<num;j+=1)
			currLbl = GetDimLabel(calPositionsWv, 0, j)
			currColorInfo=stringfromlist(0,currLbl,"_")
			currColorStr=stringfromlist(0,currColorInfo,"-")
			currColorBandwidthStr=stringfromlist(1,currColorInfo,"-")
			if ( WhichListItem(currColorStr,colorsForBench) < 0 )
				currColor = str2num(currColorStr)
				currColorBandwidth=str2num(currColorBandwidthStr)
				if ( !numtype(currColor) && (currColor > 0) )		//ignore nans infs and 0
					Redimension/n=(colorsCount+1,-1) pigmentCalcs		//make room for another color
				
					colorsForBench += currColorStr + ";"
					SetDimLabel 0,colorsCount,$( currColorInfo),pigmentCalcs
					unattenuatedRow = summaryWv[j][unattenuatedCol]
					photonsPerSqUmPerS = summaryWv[unattenuatedRow][readingCol]
					pigmentCalcs[colorsCount][0] = photonsPerSqUmPerS
					if (colorsCount == 0)
						setdimlabel 1,0,photonsPerSqUmPerS,pigmentCalcs
					endif
					
					for (k=0;k<numPigments;k+=1)
						pigmentInfo = stringfromlist(k,pigmentSetList)
						pigmentLambda=str2num(stringfromlist(1,pigmentInfo,":"))
						//pigmentCalcs[colorsCount][k+1] = nomo_integrateUniform(photonsPerSqUmPerS,nan,nan,currColor,currColorBandwidth,0.01,pigmentLambda)	
						
						if (colorsCount == 0)
							setdimlabel 1,k+1,$pigmentInfo,pigmentCalcs
						endif
					endfor
					
					colorsCount+= 1
				endif
			endif
		endfor
	endfor
	
	Setwindow $panelName, userdata(calibrationSetList) = calibrationSetList
	setwindow $panelName, userdata(pigmentSetList)=pigmentSetList
	setwindow $panelName, userdata(calPositionsWvRef)=getwavesdatafolder(calPositionsWv,2)
	setwindow $panelName, userdata(resultsWvRef)=getwavesdatafolder(resultsWv,2)
	setwindow $panelName, userdata(summaryWvRef)=getwavesdatafolder(summaryWv,2)
	setwindow $panelName, userdata(pigmentCalcRefList) = pigmentCalcRefList
	setdatafolder(dfSav)
	
	//edit/k=1 pigmentCalcs.ld
end

function/S tsw_getLightInfo(panelName)
	String panelName
	
	if (!strlen(panelName))
		panelName = winname(0,64)
	endif
	
	String calibrationSetList = GetUserData(panelName, "", "calibrationSetList")
	
	if (!strlen(calibrationSetList) || !strlen(panelName))
		//Print "fail 0"
		return ""
	endif
	
	String pigmentSetList = GetUserData(panelName, "", "pigmentSetList")
	String wheelsList = GetUserData(panelName, "", "wheelsList")
	//String pigmentCalcsRef = GetUserData(panelName, "", "pigmentCalcsRef")
	String summaryWvRef = GetUserData(panelName, "", "summaryWvRef")
	String pigmentCalcRefList = GetUserData(panelName, "", "pigmentCalcRefList")
	//wave pigmentCalcs=$pigmentCalcsRef
	wave summaryWv = $summaryWvRef
	Variable numWheels = itemsinlist(wheelsList)
	
	//about how calibration was set up
	Variable numColorsPerBench = 5
	Variable numRowsPerLambda = 12		//depends on how calPositionsWv was organized
	Variable numRowsPerBench = numRowsPerLambda*numColorsPerBench
	Variable numPerNDBench=6
	
	variable numPigments=itemsinlist(pigmentSetList),i,j
	Variable numColorBenches=itemsinlist(calibrationSetList)
	Variable colorBenchNum
	String benchesforColor,colorWheelColorInfo,colorWheelColorStr
	String calibrationSet
	String fluxStr
	String colorWheelInfo,colorWheelColors,pigmentStr
	Variable colorWheelColor,colorWheelRow
	Variable colorWheelPos,colorCalStartRow,ndOffsetRow,row
	Double flux,totalAtten		//total attenuation
	String calibrationSetInfo
	Variable numNDs,k,ndWheelPos,ndWheelNum,relNDWheelNum
	Variable attenuationCol = FindDimLabel(summaryWv, 1, "attenuation" )
	String outbenchStr,outStr="",outPigmentStr
	String pigmentCalcRef
	for (j=0;j<numColorBenches;j+=1)
		pigmentCalcRef = stringfromlist(j,pigmentCalcRefList)
		WAVE pigmentCalcs = $pigmentCalcRef
		outbenchStr = ""
		calibrationSet = stringfromlist(j,calibrationSetList)
		colorBenchNum = str2num(stringfromlist(0,calibrationSet))
		colorWheelPos=tsw_getLBSel(panelName,"",colorBenchNum)
		benchesforColor = stringfromlist(1,	calibrationSet,":")
		numNDs = itemsinlist(benchesforColor,",")
		colorWheelInfo=stringfromlist(colorBenchNum,wheelsList)		//get colors in color wheel from here (could get them from the wheel list wave too)
		colorWheelColors=stringfromlist(2,colorWheelInfo,":")
		colorWheelColorInfo=stringfromlist(colorWheelPos,colorWheelColors,",")
		colorWheelColorStr = stringfromlist(0,colorWheelColorInfo,"-")
		colorWheelColor = str2num(colorWheelColorInfo)
		colorWheelRow = FindDimLabel(pigmentCalcs, 0, colorWheelColorInfo )
		if (colorWheelRow < 0)
			//couldnt find row holding data
			continue
		endif
		if (numtype(colorWheelColor) || (colorWheelColor <= 0) )	//ignore 0 wavelength (which I use to indicate white light)
			continue
		endif	
		//for each pigment, sum the expected light intensity of each filter
		for (i=0;i<numPigments;i+=1)
			pigmentStr = getdimlabel(pigmentCalcs,1,i+1)
			flux = pigmentCalcs[colorWheelRow][i+1]
			for (k=0;k<numNDs;k+=1)
				ndWheelNum=str2num(stringfromlist(k,benchesforColor,","))
				ndWheelPos=tsw_getLBSel(panelName,"",ndWheelNum)
				colorCalStartRow = ((colorWheelPos-1)*numRowsPerLambda) + j*numRowsPerBench
				ndOffsetRow = k*numPerNDBench + ndWheelPos
				row = colorCalStartRow + ndOffsetRow
				totalAtten=summaryWv[row][attenuationCol]
				flux *= totalAtten
			endfor	//nd for loop
			//format the output string
			sprintf fluxStr, "%.2e",flux
			outBenchStr += pigmentStr +":" + "\f05"+fluxStr+"\f00" + "|"		
		endfor	//pigment for loop
		
		outStr += "B"+num2str(j)+"--"+outBenchStr + "\r"
	endfor //bench for loop
		
	return outStr
end

function tsw_updateLightInfo(panelName)
	String panelName
	
	//handles automatic updating of calibration results depending on user selections
	ControlInfo/w=$panelName showCalsCB
	if (V_Value)
		tsw_setEffectiveNdDispState(panelName,1)
	endif
	
	//get stringvar holding lightInfo
	String pathToDF = TSW_DataFolderNameForDevice(panelName,1)	
	String lightInfoStrPath = pathToDF + "lightInfoStr"
	SVAR/Z lightInfoStr = $lightInfoStrPath
	if (!Svar_exists(lightInfoStr))
		String/G $lightInfoStrPath
		SVAR lightInfoStr = $lightInfoStrPath
	endif
	
	//update variable, and if empty, abort
	lightInfoStr = tsw_getLightInfo(panelName)

	if (!strlen(lightInfoStr))
		return 0
	endif
	
	//check that control titleBox dispplaying string exists, if not, show it on the panel
	controlinfo/W=$panelName lightInfoBox
//	if (V_flag == 0)		//control not implemented
		variable btnWidth = str2num(GetUserData(panelName, "", "btnWidth" ))
		variable top=130,left=btnWidth;
		TitleBox lightInfoBox,win=$panelName,variable=lightInfoStr,frame=0,pos={left,top},size={220,200},fsize=10
//	endif
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