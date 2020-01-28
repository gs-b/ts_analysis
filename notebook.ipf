#pragma TextEncoding = "Windows-1252"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//This procedure file adds timestamping,backups, and other automated functions to Igor notebooks
//To start a new notebook, run this at the command line (Ctrl+J brings up the command line): "notes_newNB("whatever")
//"whatever" should be the preferred name of your notebook

//You will prompted to choose a location on your hard drive to which to save the notebook logs

//lines are timestamped when you hit enter, shift+enter will allow you to add a line without a timestamp

//When you have the notebook window as the top window, there are additional options under the "Notebook" top menu

//I recommend that you then save the pxp file and dedicate it to your notekeeping.
//When you want to add notes, reopen the pxp file and start editing. When you finish editing,
//save the notebook (CTRL+SHIFT+S) and save the pxp (CTRL+S)

//I also recommend using top menu-->notebook-->hide ruler for a more compact notebook display

function notes_newNB(notebookName)
	string notebookName
	
	if (strlen(notebookName) < 1)
		notebookName = "nb_write"		//default notebook name
	endif
	
	NewNotebook/F=1/N=$notebookName
	
	notes_winHook_apply(notebookName)
end

//constants related to time-stamped notebook with automatic backup (functions start with notes_)
static strconstant ks_nbBackupPath_AS = "_nbPath"		//append string for notebook backup
static constant k_nbBackupRateSecs = 600		//save every 10 min
static strconstant ks_igorFormatSave_AS = "_i_"
static strconstant ks_txtFormatSave_AS = "_t_"
static strconstant ks_nbBackupBgName_AS = "_buBg"

//constants related to ABF file acquisition synchronization (functions start with FT_ for file track)
static strconstant ks_ftTrackPathName_AS = "ftPath"		//no underscore needed

function notes_winHook_apply(notebookName)
	String notebookName
	
	Variable defaultFontSize = 11
	Variable timeStampFontSize = 5
	
	setwindow $notebookName, hook(notes_winHook_main) = notes_winHook_main, userdata(defaultFontSize) = num2str(defaultFontSize)
	setwindow $notebookName, userdata(timeStampFontSize) = num2str(timeStampFontSize)
	
	notes_toggleBackups(notebookName,1,1)
end

//MENU ITEMS DISPLAYED WITH NOTEBOOK
Menu "Notebook",dynamic //add to notebook the option to toggle file tracking
	notes_backupStatusStr(winname(0,16) ),/Q,notes_toggleBackups(winname(0,16) ,-1,0)
	"Change NB Backup Path",/Q,notes_setBackupPath(winname(0,16),0)
	nbTsw_menuDisplayStr(),/Q,nbTsw_toggle()
	ft_menuDisplayStr(),/Q,ft_toggle()			//allows user to toggle notebook tracking, sets tracking path if unset
	"Change ABF track path",/Q,ft_track_changePath(winname(0,16) ,0,0)	//allows user to change tracking path
end 

//RELATED TO BACKING UP THE NOTEBOOK --called when notebook is started
function notes_toggleBackups(notebookName,startOptions,redoPath)		//used in menu; cant be static
	String notebookName
	Variable startOptions		//1 to start, 0 to stop,-1 to toggle
	Variable redoPath	//1 to redo path (done anyway if symbolic path has not been set)
	
	Variable start		//will be 1 to start, 0 to stop, depending on input and current status
	if (startOptions < 0)		//toggle
		Variable backingUp = notes_backupStatus(notebookName)
		start = !backingUp
	else
		start = startOptions
	endif
	
	String backupBgName = notebookName + ks_nbBackupBgName_AS		//must be: [nb name] + "_" + [whatever]
	
	if (!start)		//stop: no need to check path, etc, just stop
		ctrlnamedbackground $backupBgName,stop=1
		print "notes_toggleBackups() backing up of notebook=",notebookname,"is stopped, use notes_toggleBackups(",notebookName,"1,1) or menu to start again"
		return 0
	endif
	
	//starting, check path and then start	
	Variable onlyChangeIfNotSet = !redoPath
	Variable backUpPathSet = notes_setBackupPath(notebookName,onlyChangeIfNotSet)
	if (!backUpPathSet)
		return 0
	endif	
	
	Variable backupRateTicks = k_nbBackupRateSecs * 60 	//a tick is 1/60th of a second
	String pathName = notebookName + ks_nbBackupPath_AS
		
	if (startOptions)
		ctrlnamedbackground $backupBgName start=backupRateTicks,period=backupRateTicks,proc=notes_backupBgFunc
	else
		ctrlnamedbackground $backupBgName,stop=1
	endif
end

function notes_setBackupPath(notebookName,onlyChangeIfNotSet)
	STring notebookNAme
	Variable onlyChangeIfNotSet
	
	if (strlen(notebookName) <1)
		notebookName =winname(0,16)//topnotebook
	endif
	
	String pathName = notebookName + ks_nbBackupPath_AS
	
	PathInfo $pathName
	Variable pathIsSet = V_flag
	
	if (pathIsset && onlyChangeIfNotSet)
		return 1
	endif
	
	newpath/M="Choose a folder to save notes backups into"/Z/C/O $pathName
	if (V_flag)
		Print "notes_setBackupPath() failed to make backup path for",notebookName,"not backing up. Run notes_toggleBackups(",notebookName,"1,1) to try again, or use menu"
		return 0
	endif	
	
	return 1
end

function/S notes_backupStatusStr(notebookName)		//cant be static, called in a menu declaration
	String notebookName
	
	if (strlen(notebookName) <1)
		notebookName =winname(0,16)//topnotebook
	endif
	
	Variable backingUp = notes_backupStatus(notebookName)
	if (backingUp)
		return "!! NB backups ON -- DISABLE?"
	endif
	
	return "NB Backups OFF -- ENABLE?"
	
end

static function notes_backupStatus(notebookName)		
	String notebookName
	
	if (strlen(notebookName) <1)
		notebookName =winname(0,16)//topnotebook
	endif
	
	String backupBgName = notebookName + ks_nbBackupBgName_AS	
	ctrlnamedbackground $backupBgName, status
	String runStr = stringbykey("RUN",s_info)
	return str2num(runStr)
end

function notes_backupBgFunc(s)
	STRUCT WMBackgroundStruct &s

	String notebookName = replacestring(ks_nbBackupBgName_AS,s.name,"")		//find notebook name in background task name 
	notes_backup(notebookName)
	
	return 0		//continue .. could also warn user
end

function notes_backup(notebookName)
	String notebookName
	
	Variable backUpPathSet = notes_setBackupPath(notebookName,1)
	if (!backUpPathSet)
		return 0
	endif	
	
	String pathName = notebookName + ks_nbBackupPath_AS
	String igorFormatSaveName = notebookName + ks_igorFormatSave_AS + notes_getDateTimeForFileNaming() +".ifn"
	String textFormatSaveName = notebookName + ks_txtFormatSave_AS + notes_getDateTimeForFileNaming() + ".txt"
	
	savenotebook/S=7/P=$pathName/O $notebookName	as igorFormatSaveName		//igor formatted notebook
	savenotebook/S=6/P=$pathName/O $notebookName	as textFormatSaveName		//plain text format (opens in Igor notebook) 
end

//HOOK FUNCTION AND SUBROUTINES FOR NOTEBOOK
function notes_winHook_main(s)
	STRUCT WMWinHookStruct &s

	notes_winHook_timeStampCtrl(s)
	
	return 0
end

static function notes_winHook_timeStampCtrl(s)
	STRUCT WMWinHookStruct &s	

	if (s.eventCode == 11)		//keyboard event
		
		if (s.keyCode == 13)					//return key (new paragraph)
			if ( !(s.eventMod & 2^1) )		//only do stamp if shift is NOT down, use shift to escape stamping
				if ( (s.eventMod & 2^2) > 0) 	//if return and ALT but NOT SHIFT down
					//does nothing at present
				else								//return and shift not down, ctrl not down: add time stamp
					notes_addNBTimeStampByStruct(s)
				endif
			else
			endif
			
		endif
		
		
	endif	
	
	
	return 0	
end

static function notes_addNBTimeStampByStruct(s)
	STRUCT WMWinHookStruct &s
	
	String notebookName = s.winName
	notes_addNBTimeStampToLine(notebookName)
	return 0
end


//ADDING AND REMOVING THE TIMESTAMP
static function notes_addNBTimeStampToLine(notebookName[textToAppend])
	String notebookName		//name of notebook window
	String textToAppend		//optionally append a string after stamp .. will have normal formatting
	
	GetSelection notebook, $notebookName, 2^0  //sets V_StartParagraph	 V_startPos, V_endParagraph, V_endPos
	Variable orig_V_StartParagraph =V_StartParagraph,orig_V_startPos=V_startPos,orig_V_endParagraph=V_endParagraph,orig_V_endPos=V_endPos
	
	Notebook $notebookName, selection = {startOfParagraph,endOfParagraph}		//set to selection to entire paragraph for searching
	
	GetSelection notebook, $notebookName, 2^1		//sets S_selection to selected region 
		
	Variable noExistingStamp
	String lineWithoutStamp = notes_removeTimeStamp(S_selection, noExistingStamp)		//checks for stamp in the string and removes if present
	
	if (!noExistingStamp)		//existing stamp: then remove stamp from line
		Variable defaultFontSize =str2num( win_getUserData(notebookName, "defaultFontSize") )
		Notebook $notebookName, fSize=defaultFontSize, text = lineWithoutStamp
	endif
	
	//select (original) start of paragraph and insert stamp
	Notebook $notebookName, selection = {(orig_V_StartParagraph,0), (orig_V_StartParagraph,0)}
	notes_insertNBTimeStamp(notebookName)
	
	Variable stampLen = notes_getNBTimeStampLen(notebookName)
	
	Notebook $notebookName, selection = {(orig_V_StartParagraph,orig_V_startPos+noExistingStamp*stampLen),(orig_V_endParagraph, orig_V_endPos+noExistingStamp*stampLen)}	//noExistingStamp multiplier causes space to be added after cursor position only if a new stamp was added
	Notebook $notebookName, text=" "
	if (!paramIsDefault(textToAppend) && (strlen(textToAppend) > 0))
		Notebook $notebookName, text=textToAppend
	endif
end

static function/S notes_removeTimeStamp(str, noExistingStamp)
	String str; Variable &noExistingStamp
	
	String delimPre = notes_getTimeStampDelimiterPre()		//these have to differ and one cannot be a subportion of the other!
	String delimPost = notes_getTimeStampDelimiterPost()
	
	Variable potentialStart = strsearch(str, delimPre, 0)
		
	if (potentialStart != 0)		//time stamp must start at 0
		noExistingStamp = 1
		return str
	endif
	
	Variable hasStamp = stringmatch(str,delimPre+"*"+delimPost+"*")
	
	if (!hasStamp)		//has no stamp, do nothing to line
		noExistingStamp = 1
		return str
	endif
	noExistingStamp=0
	return stringfromlist(1,str,delimPost)
end

static function notes_insertNBTimeStamp(notebookName)
	String notebookName
	
	Variable defaultFontSize =str2num( win_getUserData(notebookName, "defaultFontSize") )
	Variable timeStampFontSize =str2num( win_getUserData(notebookName, "timeStampFontSize") )

	String nb_timeStamp = notes_getNBTimeStamp(1,notebookName)
	
	Notebook $notebookName, fSize = timeStampFontSize, text = nb_timeStamp
	Notebook $notebookName, fSize=defaultFontSize		//-1 returns to default size. unfortunately no way to get font 

	return strlen(nb_timeStamp)
end


//FORMATTING OF THE TIMESTAMP
function/S notes_getNBTimeStamp(includeDelimiters,notebookName)	//exposed for call from ThorSlowWheels.ipf
	Variable includeDelimiters
	String notebookName
	
	if (includeDelimiters)	
		return notes_getTimeStampDelimiterPre()+notes_getTimeStamp(notebookName)+notes_getTimeStampDelimiterPost() //+ "   "		//added 3 spaces for readability
	endif
	
	return notes_getTimeStamp(notebookName)
end

static function notes_getNBTimeStampLen(notebookName)
	String notebookName
	
	return strlen(notes_getNBTimeStamp(1,notebookName))
end

//due to how notes_removeTimeStamp() works, neither of these can match a portion of the other, e.g. "||" for one and "__||_" for the other
//could change that function if one would like to do so
static function/S notes_getTimeStampDelimiterPre()
	return "||_"
end
static function/S notes_getTimeStampDelimiterPost()
	return "_||   "
end
static function/s notes_getTimeStamp(notebookName)
	String notebookName
	
	Variable nbOK=(strlen(notebookname) > 0) && (wintype(notebookname) > 0)
	Variable ft_tracking = nbOK && ft_getTrackingStatus(notebookName)

#if (exists("vdt2"))	
	Variable nbTsw_tracking = nbOK && nbTsw_getTrackingStatus(notebookName)
#else
	Variable nbTsw_tracking = 0
#endif	

	String out = GetDateTimeString()
	if (ft_tracking || nbTsw_tracking)
		out+=";"
	endif	
	if (nbTsw_tracking)
#if (exists("vdt2"))	
	out+=nbTsw_track(notebookName)
#endif
	endif
	if (ft_tracking)
		out+=ft_track(notebookName,1)
	endif
	
	return out
end

static function/s notes_getDateTimeForFileNaming()
	return replacestring(":",replacestring(" ",GetDateTimeString(),"_"),"_")		//replace spaces and colons with underscores
end


//RELATED TO ABF FILE TRACKING
function/S ft_menuDisplayStr()		//cannot be static for call from within menu declaration it seems
	String notebookName =  winname(0,16)		//would have to be top notebook that is being modified to get this menu options
	
	Variable tracking = ft_getTrackingStatus(notebookName)
	if (tracking)
		return "!!File tracking ON -- disable?"
	endif
	
	return "File tracking OFF -- enable?" 
end

function ft_toggle()		//used in menu, cant be static
	String notebookName =  winname(0,16)		//would have to be top notebook that is being modified to get this menu options
	
	Variable tracking = ft_getTrackingStatus(notebookName)
	if (numtype(tracking))
		tracking = 0
	endif
	ft_setTrackingStatus(notebookName,!tracking)
end
	
//returns 1 if set on, 0 if set to off
function ft_setTrackingStatus(notebookName,on)
	String notebookName
	Variable on	//one for on, zero for off
	
	if (strlen(notebookName) < 1) 
		notebookName =  winname(0,16)		//would have to be top notebook that is being modified to get this menu options
	endif
	
	if (numtype(on))		//nan inf ignored
		return 0
	endif
	
	if (on)			//do not allow set to on if path does exist and cannot be created by user
		Variable pathExists = ft_track_changePath(notebookName,1,0)
		if (!pathExists)
			on = 0
		endif
	endif
	
	setwindow $notebookName userdata(ft_trackingOn)=num2str(on)
	
	return on
end

function ft_getTrackingStatus(notebookName)
	String notebookName
	
	Variable nbExists=wintype(notebookName)
	
	if (nbExists!=5)
		return 0
	endif
	 
	String info = getuserdata(notebookName,"","ft_trackingOn")
	Variable on = str2num(info)
	if (numtype(on))
		return 0		//nan inf
	endif
	return on
end

static function nbTsw_setTrackingStatus(notebookName,on)
	String notebookName
	Variable on	//one for on, zero for off

	if (numtype(on))		//nan inf ignored
		return 0
	endif
	setwindow $notebookName userdata(nbTsw_trackingOn)=num2str(on)
end

function/S ft_track(notebookName,noNbEntryOnFolderChange)
	String notebookName
	Variable noNbEntryOnFolderChange	
		//optionally pass 1 to suppress notebook entry, good for getting started by user toggle in menu

	if (strlen(notebookName) < 1)
		notebookName=winname(0,16)
	endif
	
	String trackedFilePathName = ft_track_getSymbolicPathName(notebookName)
	Variable pathExists = ft_track_changePath(notebookName,1,noNbEntryOnFolderChange)		//attempts to set path if it does not exist
	if (!pathExists)
		return ""
	endif
	
	String files = IndexedFile($trackedFilePathName,-1,"????")//empirally ordered alphabetically 
	String rsvList=ListMatch(files,"*.rsv")
	String abfList=ListMatch(files,"*.abf")
	Variable num=itemsinlist(abfList)
	Variable recordingInProgress = itemsinlist(rsvList) > 0
	String lastFile,currFile,out
	if (recordingInProgress)
		lastFile = stringfromlist(0,rsvList)
		currFile = replacestring(".rsv",stringfromlist(0,rsvList),".abf")
	else
		lastFile = stringfromlist(num-1,abfList)
	endif
	out="NF:"+lastFile+";R:"+num2str(recordingInProgress)+";"
	
	return out		//NF stands for newest position,R stands for recording (0 for not recording, 1 for recording)
end

//change tracking path, set tracking status to zero if path set fails
function ft_track_changePath(notebookName,onlyIfPathDoesNotExist,noNbEntryOnFolderChange)		//used in menu,cant be static
	String notebookName
	Variable onlyIfPathDoesNotExist,noNbEntryOnFolderChange
	
	String trackedFilePathName = ft_track_getSymbolicPathName(notebookName)
	PathInfo $trackedFilePathName
	Variable pathAlreadyExists = V_flag
	if (pathAlreadyExists && onlyIfPathDoesNotExist)
		return 1
	endif
	
	newpath/M="Choose a folder to track new ABF files"/Z/O $trackedFilePathName
	if (V_flag)
		Print "ft_track_changePath() failed to make file track path for",notebookName,"not tracking. Run again to try again"
		ft_setTrackingStatus(notebookName,0)
		return 0
	endif
	
	if (noNbEntryOnFolderChange)
		pathinfo $trackedFilePathName
		notes_addNBTimeStampToLine(notebookName,textToAppend="---New file tracking path= "+S_path+" ---")
	endif
	
	return 1
end

static function/s ft_track_getSymbolicPathName(notebookName)
	String notebookName
	
	return notebookName + "_" + ks_ftTrackPathName_AS		//"_" is required after notebookName
end


#if (exists("vdt2"))
//RELATED TO THOR LAB SLOW WHEEL TRACKING
static function/s nbTsw_track(notebookName)
	String notebookName
	
	return tsw_getPositions_all(2)
end
#endif

function/S nbTsw_menuDisplayStr()		//used in menu; cant be static 
	String notebookName =  winname(0,16)		//would have to be top notebook that is being modified to get this menu options
#if (exists("vdt2"))	
	Variable tracking = nbTsw_getTrackingStatus(notebookName)
	if (tracking)
		return "!!Thor Wheel tracking ON -- disable?"			//! causes check
	endif
	
	return "Thor Wheel tracking OFF -- enable?" 
#else
	return ""
#endif
end

function nbTsw_toggle()		//used in menu, cant be static
	String notebookName =  winname(0,16)		//would have to be top notebook that is being modified to get this menu options
#if (exists("vdt2"))	
	Variable tracking = nbTsw_getTrackingStatus(notebookName)
	if (tracking)
		nbTsw_setTrackingStatus(notebookName,0)
	else
		nbTsw_setTrackingStatus(notebookName,1)
	endif
#else
	return 0
#endif
end

#if (exists("vdt2"))
static function nbTsw_getTrackingStatus(notebookName)
	String notebookName
	
	Variable nbExists=wintype(notebookName)
	
	if (nbExists!=5)
		return 0
	endif
	 
	String info = getuserdata(notebookName,"","nbTsw_trackingOn")
	Variable on = str2num(info)
	if (numtype(on))
		return 0		//nan inf
	endif
	return on
end	
#endif