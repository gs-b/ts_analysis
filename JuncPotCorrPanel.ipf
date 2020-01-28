#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
//hard to make this an independent modulate because it relies on MultiClampMonitor.ipf, an independent modual

#if (exists("MCC_GetHoldingEnable"))		//only compile if MCC is available
//these constants hold an ordered list of junction potentials and their associated solutions (semi-colon delimited)
static strconstant ks_solutions = "Kmes;CsCl;D-Mann;NMDG-Asp;TEA-Phos;"
static strconstant k_juncPots="-8.43;-4.43;-7.43;-3.74;-5.71;"
static strconstant ks_panelName = "juncPotCorrPanel"		//attemps to use this panel name, would fail if another window of name

Menu "Misc", hideable
	"Junc Pot Online Correction Panel", /Q, juncPotCorr_panel()
end

function juncPotCorr_panel()
	Variable existingPanel = wintype(ks_panelName)
	
	String panelName
	if (existingPanel == 7)		//panel exists, just kill and start over
		killwindow $panelName
	endif
	
	Variable loff=2		//offset for all controls from left
	Variable controlHeight=12
	Variable controlSpacing_y=18
	newpanel/w=(50,0,250,50)/N=$ks_panelName/k=1
	panelName = S_name
	
	setvariable setvar_holding,win=$panelName,pos={loff,0},size={90,controlHeight},title="HOLD:",value=_NUM:NaN,proc=juncPotCorr_setVar_holding_proc
	popupmenu popup_selectSolution,win=$panelName,pos={loff,controlSpacing_y},size={200,controlHeight},mode=1,value=#("\""+ks_solutions+"\""),proc=juncPotCorr_popupmenu_selectSolution_proc		//need # because it has to be computed at run time to deal with the strconstant
	juncPotCorr_updateJuncPotDisp(panelName)
end

//returns the junction potential for the currently selected solution
function juncPotCorr_getPotentialForSel(panelName)
	String panelName
	
	if (Strlen(panelName) < 1)
		panelName = winname(0,64)
	endif
	
	ControlInfo/W=$panelName popup_selectSolution
	V_value--		//numbering starts at 1, make it start at zero
	if (V_value < 0)			
		return nan
	endif
	
	return str2num(stringfromlist(v_Value,k_juncPots))
end

//this is modeled on SetVar_Holding_Proc(sva) in MultiClampMonitor and tries to use its error system
function juncPotCorr_setVar_holding_proc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable juncPot = juncPotCorr_getPotentialForSel(sva.win)
			Variable newHold = (sva.dval - juncPot) * 10^-3		//convert from mV to V of MCCPanel
			if (numtype(newHold != 0))
				return 0
			endif
			print "trying newHold",newHold
			setvariable setvar_holding,win=pnlMCCPanel,value=_NUM:newHold		//works without this but MCC panel is not up to date
			try
				Variable retVal
				retVal = MCC_SetHolding(newHold);AbortOnRTE
				MCCPanel#ClearErrorMessage()
			catch
				String errorMessage = GetRTErrMessage()
				Variable value
				value = GetRTError(1)
				MCCPanel#SetErrorMessage(StringFromList(1, errorMessage, ";"))
			endtry
			break
		case -1: // control being killed
			break
	endswitch

	return 0
end

function juncPotCorr_popupmenu_selectSolution_proc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	if (pa.eventCode != 2)		//mouse up, end of selection only
		return 0
	endif 
	
	juncPotCorr_updateJuncPotDisp(pa.win)
end

static function juncPotCorr_updateJuncPotDisp(panelName)
	String panelName
	
	String titleStr = "JP="+num2str(juncPotCorr_getPotentialForSel(panelName))
	popupmenu popup_selectSolution,win=$panelName,title=titleStr
end
#endif