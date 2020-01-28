#pragma rtGlobals=1		// Use modern global access method.
#pragma IgorVersion=6.1	// Control panel features and named background tasks.
#pragma Version=1.0
#pragma IndependentModule=MCCPanel

// REVISION HISTORY
// Version		Description
// 1.0			Initial release
//
#if (exists("MCC_GetHoldingEnable"))
Constant kBackgroundTaskPeriod = 30

StrConstant kMCCPanelName = "pnlMCCPanel"
StrConstant kMCCPanelDF = "root:MCCPanel"

Menu "Misc", hideable
	"MultiClamp Commander", /Q, MultiClampCommanderPanel()
end

///////////////////////////////////////////////////////////////
// INITIALIZATION AND PANEL BUILDING
///////////////////////////////////////////////////////////////
//**
// Initializes globals and builds the panel.
//*
Function MultiClampCommanderPanel()
	DoWindow/F $(kMCCPanelName)
	if (V_Flag)
		return 0
	endif
	Initialize()
	DoMultiClampCommanderPanel()
	SetStartStopButtonTitle()

	SetStartStopButtonDisable(0)
		
	ControlUpdate/W=$(kMCCPanelName) button_startstop
End

//**
// Initializes all global variables for the panel.
//*
Function Initialize()
	String currentDF = GetDataFolder(1)
	NewDataFolder/O/S $(kMCCPanelDF)
	
	// Variables
	Variable/G panelInitialized = 1
	Variable/G timeoutMs = 3000		// default value is 3s according to Axon documentation.
				
	if (!exists(kMCCPanelDF + ":currentlyMonitoring"))
		Variable/G currentlyMonitoring =  0
	endif
	
	if (!exists("V_Flagsss"))
		Variable/G V_Flag = 0
	endif

	SetDataFolder currentDF
End

//**
// Code that creates the data panel.  This is in a function
// since this is part of an independent module.
//*
Function DoMultiClampCommanderPanel()
	PauseUpdate; Silent 1		// building window...
	NewPanel /K=1 /W=(10,57,701,782)/N=$(kMCCPanelName) as "MultiClamp Monitor"
	ModifyPanel fixedSize=1
	GroupBox group_serverInfo,pos={8,1},size={650,540},title="\\f01Device Information"
	GroupBox group_serverInfo,fSize=18,frame=0
	Button button_startstop,pos={494,31},size={150,25},proc=MCCPanel#Button_start_stop_monitoring,title="Start monitoring"
	Button button_startstop,fSize=14
	SetVariable setvar_setTimeout,pos={13,582},size={164,20},bodyWidth=70,proc=MCCPanel#SetVar_TimeoutMs,title="\\f01Timeout (ms)"
	SetVariable setvar_setTimeout,fSize=14
	SetVariable setvar_setTimeout,limits={0,15000,100},value= root:MCCPanel:timeoutMs,live= 1
	PopupMenu popup_selectserver,pos={13,63},size={402,21},bodyWidth=300,proc=MCCPanel#PopMenu_SelectServer,title="\\f01Select device:"
	PopupMenu popup_selectserver,fSize=14
	PopupMenu popup_selectserver,mode=1,popvalue="700B:  Serial number: Demo    Channel ID: 1",value= #"\"700B:  Serial number: Demo    Channel ID: 1;700B:  Serial number: Demo    Channel ID: 2;\""
	Button button_scan,pos={13,31},size={110,25},proc=MCCPanel#Button_scanServers,title="Find devices"
	Button button_scan,fSize=14
	GroupBox group_timeout,pos={6,544},size={446,70},title="\\f01Timeout",fSize=18
	GroupBox group_timeout,frame=0
	GroupBox group_errormessage,pos={6,620},size={446,100},title="\\f01Error message"
	GroupBox group_errormessage,fSize=18,frame=0
	SetVariable setvar_holding,pos={49,157},size={140,16},bodyWidth=100,proc=MCCPanel#SetVar_Holding_Proc,title="Holding"
	SetVariable setvar_holding,limits={-inf,inf,1e-09},value= _NUM:0.152005016803741,live= 1
	CheckBox checkHolding,pos={202,158},size={57,14},proc=MCCPanel#Check_Holding_Proc,title="Enabled"
	CheckBox checkHolding,value= 1
	CheckBox checkBridgeBal,pos={202,189},size={57,14},proc=MCCPanel#Check_BridgeBal_Proc,title="Enabled"
	CheckBox checkBridgeBal,value= 1
	SetVariable setvar_bridgeBal,pos={13,188},size={176,16},bodyWidth=100,proc=MCCPanel#SetVar_BridgeBal_Proc,title="Bridge Balance"
	SetVariable setvar_bridgeBal,limits={-inf,inf,1e+06},value= _NUM:8.4133959798062e-42,live= 1
	CheckBox checkNeutCap,pos={202,223},size={57,14},proc=MCCPanel#Check_NeutCap_Proc,title="Enabled"
	CheckBox checkNeutCap,value= 1
	SetVariable setvar_NeutCap,pos={21,215},size={168,30},bodyWidth=100,proc=MCCPanel#SetVar_NeutCap_Proc,title="Neutralization\rCapacitance"
	SetVariable setvar_NeutCap,limits={-inf,inf,1e-12},value= _NUM:8.4133959798062e-42,live= 1
	Button buttonBridgeBalAuto,pos={273,186},size={50,20},proc=MCCPanel#Button_BridgeBalAuto_Proc,title="Auto"
	GroupBox groupMode,pos={13,93},size={278,51},title="Mode"
	CheckBox checkVClampMode,pos={32,120},size={56,14},proc=MCCPanel#Check_Mode_Proc,title="V-clamp"
	CheckBox checkVClampMode,value= 1,mode=1
	CheckBox checkIClampMode,pos={186,120},size={52,14},proc=MCCPanel#Check_Mode_Proc,title="I-clamp"
	CheckBox checkIClampMode,value= 0,mode=1
	CheckBox checkIZeroMode,pos={123,120},size={33,14},proc=MCCPanel#Check_Mode_Proc,title="I=0"
	CheckBox checkIZeroMode,value= 0,mode=1
	Button buttonWCCopmAuto,pos={202,317},size={50,20},proc=MCCPanel#Button_WCAuto_Proc,title="Auto"
	CheckBox check_wccomp,pos={202,290},size={57,14},proc=MCCPanel#Check_WC_Proc,title="Enabled"
	CheckBox check_wccomp,value= 1
	SetVariable setvar_wccomp_cap,pos={25,289},size={164,16},bodyWidth=100,proc=MCCPanel#SetVar_WCCap_Proc,title="Capacitance"
	SetVariable setvar_wccomp_cap,limits={-inf,inf,1e-12},value= _NUM:3.0297521436129e-11,live= 1
	SetVariable setvar_wccomp_res,pos={32,319},size={157,16},bodyWidth=100,proc=MCCPanel#SetVar_WCResProc,title="Resistance"
	SetVariable setvar_wccomp_res,limits={-inf,inf,1e+13},value= _NUM:10989195,live= 1
	GroupBox groupWCComp,pos={13,265},size={278,76},title="Whole Cell Compensation"
	SetVariable setvar_srcomp_correction,pos={373,231},size={97,16},bodyWidth=45,proc=MCCPanel#SetVar_SRCompCorr_Proc,title="Correction"
	SetVariable setvar_srcomp_correction,limits={-inf,inf,5},value= _NUM:20,live= 1
	CheckBox check_srcomp,pos={579,209},size={57,14},proc=MCCPanel#Check_SRComp_Proc,title="Enabled"
	CheckBox check_srcomp,value= 0
	SetVariable setvar_srcomp_bandwidth,pos={373,208},size={154,16},bodyWidth=100,proc=MCCPanel#SetVar_SRCompBand_Proc,title="Bandwidth"
	SetVariable setvar_srcomp_bandwidth,limits={-inf,inf,100},value= _NUM:1147.83996582031,live= 1
	GroupBox groupSRComp,pos={362,186},size={282,88},title="Series Resistance Compensation"
	SetVariable setvar_srcomp_prediction,pos={540,231},size={96,16},bodyWidth=45,proc=MCCPanel#SetVar_SRCompPred_Proc,title="Prediction"
	SetVariable setvar_srcomp_prediction,limits={-inf,inf,5},value= _NUM:20,live= 1
	CheckBox check_oscKill,pos={373,251},size={91,14},proc=MCCPanel#Check_OscKill_Proc,title="Oscillation Killer"
	CheckBox check_oscKill,value= 0
	GroupBox groupPipetteOffset,pos={362,284},size={255,57},title="Pipette Offset"
	Button buttonPipOffsetAuto,pos={542,309},size={50,20},proc=MCCPanel#Button_PipOffsetAuto_Proc,title="Auto"
	SetVariable setvar_pipOffset,pos={373,311},size={132,16},bodyWidth=100,proc=MCCPanel#SetVar_PipetteOffset,title="Offset"
	SetVariable setvar_pipOffset,limits={-inf,inf,0.001},value= _NUM:0.021,live= 1
	GroupBox groupFSComp,pos={13,353},size={475,71},title="Fast and Slow Compensation"
	SetVariable setvar_cpFast,pos={46,375},size={143,16},bodyWidth=100,proc=MCCPanel#SetVar_CpFast_Proc,title="Cp Fast:"
	SetVariable setvar_cpFast,limits={-inf,inf,1e-12},value= _NUM:3.02975e-11,live= 1
	SetVariable setvar_CpFast_tau,pos={202,375},size={136,16},bodyWidth=100,proc=MCCPanel#SetVar_CpFastTau_Proc,title="tau (s):"
	SetVariable setvar_CpFast_tau,limits={-inf,inf,1e-06},value= _NUM:1.09892,live= 1
	Button buttonCpFastAuto,pos={422,373},size={50,20},proc=MCCPanel#Button_CpFastAuto_Proc,title="Auto"
	CheckBox check_CpSlowTaux20,pos={355,402},size={57,14},proc=MCCPanel#Check_CpSlowTaux20_Proc,title="Tau x20"
	CheckBox check_CpSlowTaux20,value= 1
	SetVariable setvar_CpSlow_tau,pos={202,401},size={136,16},bodyWidth=100,proc=MCCPanel#SetVar_CpSlowTau_Proc,title="tau (s):"
	SetVariable setvar_CpSlow_tau,limits={-inf,inf,1e-06},value= _NUM:1.09892,live= 1
	SetVariable setvar_cpSlow,pos={43,401},size={146,16},bodyWidth=100,proc=MCCPanel#SetVar_CpSlow_Proc,title="Cp Slow:"
	SetVariable setvar_cpSlow,limits={-inf,inf,1e-12},value= _NUM:3.02975e-11,live= 1
	Button buttonCpSlowAuto,pos={422,399},size={50,20},proc=MCCPanel#Button_CpSlowAuto_Proc,title="Auto"
	GroupBox groupSlowCurrent,pos={362,93},size={282,82},title="Slow Current Injection"
	CheckBox check_slowCurrInjEnable,pos={373,114},size={57,14},proc=MCCPanel#Check_SlowCurrInjEnable_Proc,title="Enabled"
	CheckBox check_slowCurrInjEnable,value= 0
	SetVariable setvar_slowCurrInjLevel,pos={373,138},size={126,16},bodyWidth=80,proc=MCCPanel#SetVar_SlowCurrInjLevel_Proc,title="Level (V)"
	SetVariable setvar_slowCurrInjLevel,limits={-inf,inf,0.001},value= _NUM:1,live= 1
	SetVariable setvar_SlowCurrInjSTime,pos={513,131},size={123,30},bodyWidth=80,proc=MCCPanel#SetVar_SlowCurrInjSTime_Proc,title="Settling\r time (s):"
	SetVariable setvar_SlowCurrInjSTime,limits={0.1,5,1},value= _NUM:0.1,live= 1
	GroupBox groupOutputs,pos={13,436},size={475,85},title="Outputs"
	TitleBox titleOutPrimary,pos={53,476},size={45,13},title="Primary:",frame=0
	TitleBox titleOutPrimary,fStyle=1
	TitleBox titleOutSecondary,pos={34,502},size={64,13},title="Secondary:",frame=0
	TitleBox titleOutSecondary,fStyle=1
	TitleBox titleOutGain,pos={149,454},size={30,13},title="Gain:",frame=0,fStyle=1
	TitleBox titleOutLPF,pos={253,454},size={53,13},title="LPF (Hz):",frame=0
	TitleBox titleOutLPF,fStyle=1
	TitleBox titleOutHPF,pos={363,454},size={55,13},title="HPF (Hz):",frame=0
	TitleBox titleOutHPF,fStyle=1
	SetVariable setvar_outPriGain,pos={139,474},size={50,16},bodyWidth=50,proc=MCCPanel#SetVar_OutPriGain_Proc
	SetVariable setvar_outPriGain,limits={1,2000,1},value= _NUM:1,live= 1
	SetVariable setvar_outSecGain,pos={139,500},size={50,16},bodyWidth=50,proc=MCCPanel#SetVar_OutSecGain_Proc
	SetVariable setvar_outSecGain,limits={1,100,1},value= _NUM:1,live= 1
	SetVariable setvar_outPriLPF,pos={244,474},size={70,16},bodyWidth=70,proc=MCCPanel#SetVar_OutPriLPF_Proc
	SetVariable setvar_outPriLPF,limits={2,30000,1000},value= _NUM:2000,live= 1
	SetVariable setvar_outSecLPF,pos={244,500},size={70,16},bodyWidth=70,proc=MCCPanel#SetVar_OutSecLPF_Proc
	SetVariable setvar_outSecLPF,limits={10000,inf,10000},value= _NUM:10000,live= 1
	SetVariable setvar_outPriHPF,pos={355,474},size={70,16},bodyWidth=70,proc=MCCPanel#SetVar_OutPriHPF_Proc
	SetVariable setvar_outPriHPF,limits={0,300,10},value= _NUM:10,live= 1
	SetWindow kwTopWin,hook(MCCPanel)=MCCPanel#AxonMCCMonitor_Hook
	NewNotebook /F=1 /N=NBERROR /W=(6,649,452,716) /HOST=# /OPTS=15 
	Notebook kwTopWin, defaultTab=36, statusWidth=0, autoSave=1, writeProtect=1, showRuler=0, rulerUnits=1
	Notebook kwTopWin newRuler=Normal, justification=0, margins={0,0,324}, spacing={0,0,0}, tabs={}, rulerDefaults={"Arial",10,0,(0,0,0)}
	Notebook kwTopWin, zdata= "GasbT9aUqV%#%W&-*B?r:>d.g,.JIK$F:>?:*UPN8#Nq;j))b>B[dV_7e\"eY.ENfckdi<q2.<3Zi!1:\"4M)L/.Ii5MQ5W#+\\1gEb,Mo$\\J\"O&aC7i&gZ?$1:NlrGOZ+&CWX'A%1S5W`m65?7QQ-(Fu1c>,k0gtRL&f+BJVoJ$+V#t^q8Cs42D?qb(/SX\"/<9Fk/!3Rl'4&=*gEm\"Bq`7*&a'YcfulG\"[9g:@=k`l[^b_0<Tol]=1]"
	Notebook kwTopWin, zdataEnd= 1
	RenameWindow #,NBERROR
	SetActiveSubwindow ##
EndMacro

///////////////////////////////////////////////////////////////
// BACKGROUND TASK RELATED
///////////////////////////////////////////////////////////////
//**
// Start or stop the background task that monitors the amplifiers.
//*
Function Control_monitoring()
	NVAR/Z monitoring = $(kMCCPanelDF+":currentlyMonitoring")
	CtrlNamedBackground axonMCCMonitor status
	Variable run = NumberByKey("RUN", S_info , ":", ";")
	if (!NVAR_Exists(monitoring))
		Initialize()
		NVAR/Z monitoring = $(kMCCPanelDF+":currentlyMonitoring")
	endif
		
	if (monitoring)
		if (numtype(run) != 0 || run == 0)
			String cmd
			sprintf cmd, "CtrlNamedBackground axonMCCMonitor, burst=0, dialogsOK=1, period=%d, proc=%s#Background_monitoring, start", kBackgroundTaskPeriod, GetIndependentModuleName()
			Execute cmd
		endif
	else
		if (run == 1)
			CtrlNamedBackground axonMCCMonitor, stop=1
		endif
	endif
End

//**
// Background task that Igor calls each time the background task should run.
//*
Function Background_monitoring(s)
	STRUCT WMBackgroundStruct &s
	Variable start = StopMsTimer(-2)
	NVAR/Z monitoring = $(kMCCPanelDF+":currentlyMonitoring")
	if (NVAR_Exists(monitoring) && monitoring)
		UpdateAllData()
	endif
//	printf "Background task took %f ms.\r", (StopMsTimer(-2) - start) / 1000
	return 0		// Continue background task.
End

//////////////////////////////////////////////////////////
// UTILITY FUNCTIONS
//////////////////////////////////////////////////////////
//**
// Clear the error message in the notebook subwindow and disable the
// group box containing the subwindow.
//*
Function ClearErrorMessage()
	// Make sure panel is displayed.
	DoWindow $(kMCCPanelName)
	if (!V_Flag)
		return 0
	endif
	
	ControlInfo/W=$(kMCCPanelName) group_errormessage
	if (V_disable != 2)
		GroupBox group_errormessage win=$(kMCCPanelName), disable=2
	endif
	Notebook $(kMCCPanelName)#NBERROR selection={startOfFile, endOfFile}, text="", backRGB = (61440, 61440, 61440)
End

//**
// Set an error message in the notebook subwindow and alert
// the user by beeping.
//
// @param messageStr
// 	A string containing the error message that should be displayed
// 	in the notebook subwindow.
//*
Function SetErrorMessage(messageStr)
	String messageStr
	// Make sure panel is displayed.
	DoWindow $(kMCCPanelName)
	if (!V_Flag)
		return 0
	endif
	
	ControlInfo/W=$(kMCCPanelName) group_errormessage
	if (V_disable != 0)
		GroupBox group_errormessage win=$(kMCCPanelName), disable=0
		beep
	endif
	Notebook $(kMCCPanelName)#NBERROR selection={startOfFile, endOfFile}, fSize=12, text=messageStr, backRGB = (65535, 65535, 65535)
End

//**
// Utility function that updates the titles of the primary and secondary
// output GroupBoxes based on the primary and secondary output
// parameters being measured.
//*
Function UpdatePanelGroupTitles()
	// Make sure panel is displayed
	DoWindow $(kMCCPanelName)
	if (!V_Flag)
		return 0
	endif
	String currentDF = GetDataFolder(1)
	SetDataFolder $(kMCCPanelDF)
		
	NVAR OperatingMode,ScaledOutSignal,Alpha,ScaleFactor,ScaleFactorUnits,LPFCutoff
	NVAR MembraneCap,ExtCmdSens,RawOutSignal,RawScaleFactor,RawScaleFactorUnits
	NVAR HardwareType,SecondaryAlpha,SecondaryLPFCutoff,SeriesResistance

	SVAR OperatingMode_str, ScaledOutSignal_str, ScaleFactorUnits_str, RawOutSignal_str, RawScaleFactorUnits_str, HardwareType_str
	
	String primaryOutput = ""
	String secondaryOutput = ""
	
	sprintf primaryOutput, "\f01Primary Output:\f00\t%s (%.3f %s)", ScaledOutSignal_str, ScaleFactor * Alpha, ScaleFactorUnits_str
	sprintf secondaryOutput, "\f01Secondary Output:\f00\t%s (%.3f %s)", RawOutSignal_str, RawScaleFactor * SecondaryAlpha, RawScaleFactorUnits_str
	
	// Set titles (but only if the title would change, to prevent annoying blinking of the controls).
	ControlInfo/W=$(kMCCPanelName) group_primary_output
	if (cmpstr(S_value, primaryOutput) != 0)
		GroupBox group_primary_output,win=$(kMCCPanelName),title=primaryOutput
	endif

	ControlInfo/W=$(kMCCPanelName) group_secondary_output
	if (cmpstr(S_value, secondaryOutput) != 0)
		GroupBox group_secondary_output,win=$(kMCCPanelName),title=secondaryOutput
	endif


	SetDataFolder currentDF
End

//**
// Simple utility function that in turn calls
// functions to get data and update
// all of the controls on the panel that need to be
// updated when new data comes in.
//*
Function UpdateAllData()
	Variable value
	Variable retVal
	
	try
		// Holding enable
		retVal = MCC_GetHoldingEnable();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			CheckBox checkHolding value = retVal ? 1 : 0
		else
			// TODO: Handle error
		endif
	
		
		// Holding value
		retVal = MCC_GetHolding();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_holding value = _NUM:retVal
		else
			// TODO: Handle error
		endif
		
		
		// Mode
		retVal = MCC_GetMode();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			CheckBox checkVClampMode, value = (retVal == 0) ? 1 : 0		// Voltage clamp
			CheckBox checkIZeroMode, value = (retVal == 2) ? 1 : 0		// I=0
			CheckBox checkIClampMode, value = (retVal == 1) ? 1 : 0		// Current clamp
		else
			// TODO: Handle error
		endif
		
		
		// Bridge balance enable
		retVal = MCC_GetBridgeBalEnable();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			CheckBox checkBridgeBal value = retVal ? 1 : 0
		else
			// TODO: Handle error
		endif
		
		
		// Bridge balance resistance
		retVal = MCC_GetBridgeBalResist();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_bridgeBal value = _NUM:retVal
		else
			// TODO: Handle error
		endif
		
		// Neutralization enable
		retVal = MCC_GetNeutralizationEnable();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			CheckBox checkNeutCap value = retVal ? 1 : 0
		else
			// TODO: Handle error
		endif
		
		
		// Neutralization capacitance		
		retVal = MCC_GetNeutralizationCap();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_NeutCap value = _NUM:retVal
		else
			// TODO: Handle error
		endif
		
		
		// Whole cell compensation enable
		retVal = MCC_GetWholeCellCompEnable();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			CheckBox check_wccomp value = retVal ? 1 : 0
		else
			// TODO: Handle error
		endif
		
		
		// Whole cell compensation resistance		
		retVal = MCC_GetWholeCellCompResist();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_wccomp_res value = _NUM:retVal
		else
			// TODO: Handle error
		endif
		
		// Whole cell compensation capacitance		
		retVal = MCC_GetWholeCellCompCap();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_wccomp_cap value = _NUM:retVal
		else
			// TODO: Handle error
		endif
		
		
		
		// Series resistance compensation enable
		retVal = MCC_GetRsCompEnable();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			CheckBox check_srcomp value = retVal ? 1 : 0
		else
			// TODO: Handle error
		endif
		
		// Series resistance compensation bandwidth		
		retVal = MCC_GetRsCompBandwidth();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_srcomp_bandwidth value = _NUM:retVal
		else
			// TODO: Handle error
		endif
		
		// Series resistance compensation correction		
		retVal = MCC_GetRsCompCorrection();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_srcomp_correction value = _NUM:retVal
		else
			// TODO: Handle error
		endif
		
		// Series resistance compensation prediction		
		retVal = MCC_GetRsCompPrediction();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_srcomp_prediction value = _NUM:retVal
		else
			// TODO: Handle error
		endif
		
		
		// Oscillation killer enable
		retVal = MCC_GetOscKillerEnable();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			CheckBox check_oscKill value = retVal ? 1 : 0
		else
			// TODO: Handle error
		endif
		
		
		// Pipette offset	
		retVal = MCC_GetPipetteOffset();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_pipOffset value = _NUM:retVal
		else
			// TODO: Handle error
		endif
		


		
		// Cp Fast Cap	
		retVal = MCC_GetFastCompCap();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_cpFast value = _NUM:retVal
		else
			// TODO: Handle error
		endif
		
		// Cp Fast Tau	
		retVal = MCC_GetFastCompTau();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_CpFast_tau value = _NUM:retVal
		else
			// TODO: Handle error
		endif
		
		// Cp Slow Cap	
		retVal = MCC_GetSlowCompCap();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_cpSlow value = _NUM:retVal
		else
			// TODO: Handle error
		endif
		
		// Cp Slow Tau	
		retVal = MCC_GetSlowCompTau();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_CpSlow_tau value = _NUM:retVal
		else
			// TODO: Handle error
		endif
		
		// Cp Slow Tau x20 Enable
		retVal = MCC_GetSlowCompTauX20Enable();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			CheckBox check_CpSlowTaux20 value = retVal ? 1 : 0
		else
			// TODO: Handle error
		endif
		
		
		// Slow Current Injection Enable
		retVal = MCC_GetSlowCurrentInjEnable();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			CheckBox check_SlowCurrInjEnable value = retVal ? 1 : 0
		else
			// TODO: Handle error
		endif
		
		// Slow Current Injection Level	
		retVal = MCC_GetSlowCurrentInjLevel();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_SlowCurrInjLevel value = _NUM:retVal
		else
			// TODO: Handle error
		endif
		
		// Slow Current Injection Settling time	
		retVal = MCC_GetSlowCurrentInjSetlTime();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_SlowCurrInjSTime value = _NUM:retVal
		else
			// TODO: Handle error
		endif
		
		// Primary Signal Gain	
		retVal = MCC_GetPrimarySignalGain();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_outPriGain value = _NUM:retVal
		else
			// TODO: Handle error
		endif
		
		// Primary Signal LPF	
		retVal = MCC_GetPrimarySignalLPF();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_outPriLPF value = _NUM:retVal
		else
			// TODO: Handle error
		endif
			
		// Primary Signal HPF	
		retVal = MCC_GetPrimarySignalHPF();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_outPriHPF value = _NUM:retVal
		else
			// TODO: Handle error
		endif
		
		// Secondary Signal Gain	
		retVal = MCC_GetSecondarySignalGain();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_outSecGain value = _NUM:retVal
		else
			// TODO: Handle error
		endif
		
		// Secondary Signal LPF	
		retVal = MCC_GetSecondarySignalLPF();AbortOnRTE
		if (numtype(retVal) != 2)	// No error
			SetVariable setvar_outSecLPF value = _NUM:retVal
		else
			// TODO: Handle error
		endif
		
	
		// Clear any error messages from previous runs.
		ClearErrorMessage()
	catch
		String errorMessage = GetRTErrMessage()
		Variable dummy
		dummy = GetRTError(1)		// Clear the error
		SetErrorMessage(StringFromList(1, errorMessage, ";"))
	endtry
	
End

//**
// Utility function to set the title of the start/stop button
// to the correct value depending on whether or not
// the amplifier is currently being monitored.
//*
Function SetStartStopButtonTitle()
	DoWindow $(kMCCPanelName)
	if (V_flag == 0)
		return 0
	endif
	
	NVAR/Z monitoring = $(kMCCPanelDF+":currentlyMonitoring")
	if (!NVAR_Exists(monitoring))
		Initialize()
		NVAR/Z monitoring = $(kMCCPanelDF+":currentlyMonitoring")
		if (!NVAR_Exists(monitoring))
			return 0
		endif
	endif
	String buttonTitle
	if (monitoring)
		buttonTitle = "Stop monitoring"
	else
		buttonTitle = "Start monitoring"
	endif
	Button button_startstop, win=$(kMCCPanelName), title=buttonTitle
	ControlUpdate/A/W=$(kMCCPanelName)
End

//**
// Set the disable status of the start/stop button.
// @param isDisabled
// 	1 if the button should be disabled or 0 if it should be enabled.
//*
Function SetStartStopButtonDisable(isDisabled)
	Variable isDisabled
	
	DoWindow $(kMCCPanelName)
	if (V_flag == 0)
		return 0
	endif
	Variable disable = isDisabled? 2 : 0
	Button button_startstop, win=$(kMCCPanelName), disable=disable
End

//**
// Utility function that finds all available MCC
// servers and stores the list in a global string.
//*
Function ScanForServers()
	String currentDF = GetDataFolder(1)
	SetDataFolder $(kMCCPanelDF)
	
	NVAR timeout = $(kMCCPanelDF + ":timeoutMs")
	MCC_FindServers
	WAVE serversWave = W_MultiClamps
	
	String serverList
	serverList = ""
	Variable n, numServers = DimSize(serversWave, 0)
	String currentServerDesc
	For (n=0; n<numServers; n+=1)
		// Note:  If the format string below is changed it must also be changed in PopMenu_SelectServer().
		if (serversWave[n][%Model] ==1)
			// Server is a 700B server.
			sprintf currentServerDesc, "%s:  Serial number: %s    Channel ID: %d", "700B", GetDimLabel(serversWave, 0, n), serversWave[n][%ChannelID]
		endif
		serverList = AddListItem(currentServerDesc, serverList, ";", inf)
	EndFor
	// Put enclosing quote marks on serverList
	serverList = "\"" + serverList + "\""
	PopupMenu popup_selectserver value=#serverList
	SetDataFolder currentDF
	
End




//////////////////////////////////////////////////////////
// CONTROL ACTION PROCEDURES
//////////////////////////////////////////////////////////
//**
// Action procedure for Select server popup menu control
// that sets global variables indicating which server
// should be monitored.
//*
Function PopMenu_SelectServer(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			Variable retVal
			Variable error = GetRTError(1)		// Clear any existing error.
			String popStr = pa.popStr
			Variable channel, comPort, axoBus
			String serial
			sscanf popStr, "700B:  Serial number: %s    Channel ID: %d", serial, channel
			if (V_flag == 2)
				// The selected item represents a 700B server.
				retVal = MCC_SelectMultiClamp700B(serial, channel)
				if (numtype(retVal == 2))
					// TODO: Add in error handling code.
				else
					UpdateAllData()
					SetStartStopButtonDisable(0)
				endif
			endif
			break
	endswitch

	return 0
End

//**
// Action procedure for start/stop button that starts or stops monitoring.
//*
Function Button_start_stop_monitoring(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			NVAR/Z monitoring = $(kMCCPanelDF+":currentlyMonitoring")
			if (NVAR_Exists(monitoring))
				monitoring = !monitoring
				SetStartStopButtonTitle()
				Control_monitoring()
			endif
			break
	endswitch

	return 0
End

//**
// Action procedure for timout setvar which calls the XOP
// to set the timeout value and then calls the XOP again
// to read the new timeout value.
//*
Function SetVar_TimeoutMs(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetTimeoutMs(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
						
			break
	endswitch

	return 0
End

//**
// Action procedure for "Find servers" button.
//*
Function Button_scanServers(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			ScanForServers()
			break
	endswitch

	return 0
End

//**
// Panel window hook function.
//*
Function AxonMCCMonitor_Hook(s)
	STRUCT WMWinHookStruct &s
	
	Switch (s.eventCode)
		Case 2:		// Window is being killed.
			NVAR/Z monitoring = $(kMCCPanelDF+":currentlyMonitoring")
			if (NVAR_Exists(monitoring))
				monitoring = !monitoring
				SetStartStopButtonTitle()
				Control_monitoring()
			endif
			break
	EndSwitch
	return 0
End

Function SetVar_Holding_Proc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetHolding(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function Check_Holding_Proc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			try
				Variable retVal
				retVal = MCC_SetHoldingEnable(cba.checked);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVar_BridgeBal_Proc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetBridgeBalResist(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function Check_BridgeBal_Proc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			try
				Variable retVal
				retVal = MCC_SetBridgeBalEnable(cba.checked);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function Button_BridgeBalAuto_Proc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			try
				Variable retVal
				retVal = MCC_AutoBridgeBal();AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVar_NeutCap_Proc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetNeutralizationCap(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function Check_NeutCap_Proc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			try
				Variable retVal
				retVal = MCC_SetNeutralizationEnable(cba.checked);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function Check_Mode_Proc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			// Determine which box is checked
			Variable newMode
			StrSwitch (cba.ctrlName)
				Case "checkVClampMode":
					newMode = 0;
					// Uncheck the other radios
					CheckBox checkIClampMode, value=0
					CheckBox checkIZeroMode, value=0
					break;
					
				Case "checkIClampMode":
					newMode = 1;
					// Uncheck the other radios
					CheckBox checkVClampMode, value=0
					CheckBox checkIZeroMode, value=0
					break;
					
				Case "checkIZeroMode":
					newMode = 2;
					// Uncheck the other radios
					CheckBox checkVClampMode, value=0
					CheckBox checkIClampMode, value=0
					break;
					
			EndSwitch
			try
				Variable retVal
				retVal = MCC_SetMode(newMode);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVar_WCCap_Proc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetWholeCellCompCap(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVar_WCResProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetWholeCellCompResist(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function Check_WC_Proc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			try
				Variable retVal
				retVal = MCC_SetWholeCellCompEnable(cba.checked);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function Button_WCAuto_Proc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			try
				Variable retVal
				retVal = MCC_AutoWholeCellComp();AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
			
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVar_SRCompBand_Proc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetRSCompBandwidth(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVar_SRCompCorr_Proc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetRSCompCorrection(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function Check_SRComp_Proc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			try
				Variable retVal
				retVal = MCC_SetRSCompEnable(cba.checked);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVar_SRCompPred_Proc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetRSCompPrediction(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function Check_OscKill_Proc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			try
				Variable retVal
				retVal = MCC_SetOscKillerEnable(cba.checked);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function Button_PipOffsetAuto_Proc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			try
				Variable retVal
				retVal = MCC_AutoPipetteOffset();AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVar_PipetteOffset(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetPipetteOffset(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVar_CpFast_Proc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetFastCompCap(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVar_CpFastTau_Proc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetFastCompTau(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function Check_CpSlowTaux20_Proc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			try
				Variable retVal
				retVal = MCC_SetSlowCompTauX20Enable(cba.checked);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVar_CpSlow_Proc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetSlowCompCap(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVar_CpSlowTau_Proc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetSlowCompTau(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function Button_CpFastAuto_Proc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			try
				Variable retVal
				retVal = MCC_AutoFastComp();AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function Button_CpSlowAuto_Proc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			try
				Variable retVal
				retVal = MCC_AutoSlowComp();AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End





Function Check_SlowCurrInjEnable_Proc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			try
				Variable retVal
				retVal = MCC_SetSlowCurrentInjEnable(cba.checked);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVar_SlowCurrInjLevel_Proc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetSlowCurrentInjLevel(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVar_SlowCurrInjSTime_Proc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetSlowCurrentInjSetlTime(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVar_OutSecGain_Proc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetSecondarySignalGain(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVar_OutPriGain_Proc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetPrimarySignalGain(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVar_OutPriLPF_Proc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetPrimarySignalLPF(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVar_OutSecLPF_Proc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetSecondarySignalLPF(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SetVar_OutPriHPF_Proc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			try
				Variable retVal
				retVal = MCC_SetPrimarySignalHPF(sva.dval);AbortOnRTE
				ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
#endif
