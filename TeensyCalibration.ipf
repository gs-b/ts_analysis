#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//calibration procedures for Teensy dynamic clamp
//requires Igor NIDAX tools mx and #include procs associated with it (to apply voltage commands and read voltage output)
//requires VDT2 (to tell the teensy what to do)
//The sketch TeensyCalibration.ino must be loaded onto the Teensy so that the Teensy knows how to follow commands via VDT2

//the following connections must be made from the Teensy to the scaling circuitry and NIDAQ board:
//(TODO enter these)

//Overview of input-side calibration:
//input to Teensy commands from +/-10V, record command, scaled command, and teensy readings, correlate these
	
//Overview of output-side calibration:
//command Teensy to output 0-3.3V, record teensy output, scaled output, and correlate these

#if (exists("fdaqmx_writechan"))		//only compile of daq procs are available via the xop

//useful command examples

//setup to scan into wave0 from A0,wave1 from A1"; their length and scaling set period and #; type sets precision; all waves must have same npnts and type
//DAQmx_Scan/DEV="dev1" WAVES="Wave0, 0; Wave1, 1;"	
	//adding the /bkg flag will do it in background and transfer to waves as it goes, live, continuously -- or might require /rpt flag?
	//stopped with fDAQmx_ScanStop("dev1")
	//wave scaling may be adjusted to capabilities of DAC
	//can get raw device reads with /I -- range includes negative (e.g., -23768 to 32767 for 16-bit), so /U is not usually useful
	//scanning occurs in order of parameter list
	
	//instead of WAVES="" use FIFO="" with a pre-made FIFO to use that.
	//EOSH specifies an end of scan hook
	

//use may need to modify:
static strconstant ks_dacName = "dac0"
static strconstant ks_teensyCom = "COM19"

//input-side pins
static constant k_teensyCmdChanNum = 0 //on NIDAQ, # of analog in pin (as in AI#). I use analog out (AO) 0, which has chanNum = 0
static constant k_teensyCmdCopyChanNum	= 0		//copy of command is recorded by what analog in (AI) pin
static constant k_teensyInputCopyChanNum = 1		//copy of scaled input to teensy is recorded by what analog in (AI) pin

//output-side pins
static constant k_teensyOutputCopyChanNum = 2		//copy of teensy DAC output (unscaled, 0-3.3V range)
static constant k_teensyScaledOutputCopyChanNum = 3 //scaled teensy output (scaled, +/-10V range)

//user will not need to modify, but might want to
static constant k_comBaud = 115200
static constant k_teensyNumReadReturns = 30		//how many reads does the teensy return when prompted (set by its .ino sktch)
static constant k_teensyReadSetsToAvg = 900 //how many sets of teensy reads to average (each set has reads = k_teensyNumReadReturns) 
static constant k_teensyReturnTimeOutSecs = 5		//give up even teensy takes longer than this to return over serial i/o
static constant k_cmdResolutionRange = 2	//how many volts around command value to put, nidaqmx tools scale to use gain better for accuracy
static constant k_waitAfterNewLevelSecs = 0.3		//how long to wait between new command values

static constant k_dacSampleRate = 10000
static constant k_dacAvgNum = 10		//dac is capable of averaging 10 samples even at 10kHz, supposedly
static constant k_dacAvgLenSecs = 2	//number of seconds to average

function teensyCal_follow(dacNum,statsRef,sinFreq,sinMin,sinMax)
	Variable dacNum		//dac num (0 or 1 at present) to follow on teensy correspondance determined by ino sketch
	String statsRef
	Variable sinFreq		//sinusoid frequency in Hz
	Double sinMin,sinMax	//minimum value of sine wave in V (-10,10 is max range; teensy is good at following -8 to 8)
	
	vdtoperationsport2 $ks_teensyCom;VDT2/P=$ks_teensyCom baud=k_comBaud;		//connect to teensy
	Variable teensyInFollowMode = teensyCal_setFollowMode(dacNum,1)				//put it in follow mode, hopefully
	if (!teensyInFollowMode)
		print "teensyCal_follow() teensy failed to enter follow mode, aborting"
		return 0
	endif
	
	//nidaq command parameters -- will just make one second of stimulus, but repeat it over and over for as many repeats as we want (set by numRepeats)
	Variable sampleFreq = 100000	//e.g., 100,000 Hz (100 kHz) sample freq.. listed limit is 250 kHz, but in Igor the nidaq driver gives back an error at 200 kHz, allows 100 kHz. havent tested others
	Variable samplePeriod = 1/sampleFreq
	Variable numRepeats = 20
	
	Variable outputLengthSamples = numRepeats * sampleFreq
	
	//build sine wave
	Double sinMid = (sinMin + sinMax)/2
	Double sinAmp = (sinMax - sinMin)/2
		
	make/o/d/n=(sampleFreq) sinTest
	setscale/p x,0,samplePeriod,"s",sinTest
	sinTest = sinMid + sinAmp*sin(2*pi*sinFreq*x)
	
	//set up to run this on DAC command pin, but dont start yet
	Variable ok = fdaqmx_writechan(ks_dacName,k_teensyCmdChanNum,-8,-10,10)	//start off commanding a negative voltage as output, so that the sine wave (which starts half way between vMin and vMax is clear (hopefully)	
	daqmx_waveformgen/dev=ks_dacName/bkg/strt=0 "sinTest, "+num2str(k_teensyCmdChanNum)+";"
	
	//set up to record inputs to and outputs from teensy as captured by the nidaq board, also setup display
	String trigStr = "/" + ks_dacName + "/ao/starttrigger"		//passing this below tells nidaq board to record when waveform starts
	String recordingWvs = "cmdCopy;inputCopy;teensyOutputVoltage;scaledOutputVoltage;"
	String winN = statsRef+"_win"
	killwindow/Z $winN; display/k=1/n=$winN;winN = s_name
	
	variable i,numRecs = itemsinlist(recordingWvs);string recwv
	for (i=0;i<numRecs;i+=1)
		recwv = stringfromlist(i,recordingWvs)
		make/o/d/n=(outputLengthSamples) $recwv
		setscale/p x,0,samplePeriod,"s",$recwv
		
		appendtograph/l=$("L_"+recwv) $recwv
	endfor
	doupdate;disp_arrayAxes(winN,"L*",0.04,"")
	modifygraph live=1		//live mode might be faster
	setaxis L_cmdCopy,-10,10
	setaxis L_inputCopy,-0.2,3.5
	setaxis L_teensyOutputVoltage,-0.2,3.5
	setaxis L_scaledOutputVoltage,-10,10
	doupdate;
	
	String scanWvStr="cmdCopy,"+num2str(k_teensyCmdCopyChanNum)+";inputCopy,"+num2str(k_teensyInputCopyChanNum)+";"
	scanWvStr += "teensyOutputVoltage,"+num2str(k_teensyOutputCopyChanNum)+";scaledOutputVoltage,"+num2str(k_teensyScaledOutputCopyChanNum)+";"
	Variable ok1 = fDAQmx_ScanStop(ks_dacName)		//assure not already scanning
	daqmx_scan/DEV=ks_dacName/STRT=1/BKG/TRIG=(trigStr) WAVES=(scanWvStr)		//start scanning, but due to trigger actually waits for waveform gen to start
	//print fDAQmx_ErrorString()
	
	//start command, which also starts acquisition due to /TRIG=(trigStr)
	Variable ok2 = fdaqmx_waveformstart(ks_dacName,numRepeats)
	
	Variable ok3 = fDAQmx_ScanWait(ks_dacName)	//wait til cmdCopy and inputCopy have been filled
	
	//turn teensy off follow mode once complete
	Variable teensyOutOfFollowMode = teensyCal_setFollowMode(dacNum,0)
	
	vdtcloseport2 $ks_teensyCom	
end

function teensyCal_outputCal(statsRef)
	STring statsRef
	
	STring dispWinName = statsRef + "_outputCalWin"
	
	Variable vMin = 0,vMax=4095
	Variable vFitStart = 30,vFitEnd=4065
	Variable numAdditionalLevels=14
	
	Variable numLevels = 2+ numAdditionalLevels		//vMin and vMax plus any additional
	
	vdtoperationsport2 $ks_teensyCom;VDT2/P=$ks_teensyCom baud=k_comBaud;		//connect to teensy
	Variable inWriteMode = teensyCal_enterWriteMode()
	if (!inWriteMode)
		print "teensyCal_outputCal() teensy could not be put into write mode by teensyCal_enterWriteMode(); aborting"
		return 0
	endif
		
	//numRows == numLevels; numCols == numWaveStats; numLayers == 2(0 is intermediate voltage direct from teensy, 1 is scaled output)
	make/o/d/n=(4)/free/W wstest; wavestats/q/w wstest;WAVE M_wavestats;Variable numStats = dimsize(M_wavestats,0)	//just find out how many rows there are in wavestats output
	make/o/d/n=(numLevels,numStats,2) $statsRef/wave=stats; stats = nan
	setscale/I x,vMin,vMax,stats		//assign level scaling (and let Igor calculate intermediate levels)
	dl_lblsToLbls("M_wavestats",0,0,inf,statsRef,1,0,"",0)		//assign wave stats labels to columns	
	redimension/n=(-1,numStats+2,-1) stats;		//make a place to store exact cmdVal and what is reported as output just in case
	stats = nan
	dl_assignLblsFromList(stats,1,numStats,"cmdVal;returnedVal;","",0)
	numStats+=2;
	dl_assignLblsFromList(stats,2,0,"teensyOutputVoltage;scaledOutputVoltage;","",0)		//assign layer labels -- order must stay or else update fit code below
	
	//make waves to store raw reads from the command and input copies going into the dac,setup reading into them
	Variable avgPnts = k_dacAvgLenSecs * k_dacSampleRate
	make/o/d/n=(avgPnts) teensyOutputVoltage,scaledOutputVoltage
	setscale/p x,0,1/k_dacSampleRate,"s",teensyOutputVoltage,scaledOutputVoltage
	Variable ok = fDAQmx_ScanStop(ks_dacName)		//assure not already scanning	

	//run the test
	int i;Double level,rangeMinV,rangeMaxV
	make/o/free/n=(numLevels+1,10) daqErrors = nan	//error tracing
	String winN,teensyReturn
	for (i=0;i<numLevels;i+=1)
		level = round(pnt2x(stats,i))		//make it an integer
		level = max(level,0)		//keep within limits
		level = min(level,4095)
		stats[i][%cmdVal][] = level
		teensyReturn = teensyCal_writeVal(level)
		stats[i][%returnedVal][] = str2num(teensyReturn)
		waitSecs(k_waitAfterNewLevelSecs)
		
		daqmx_scan/DEV=ks_dacName/AVE=(k_dacAvgNum)/STRT=0/BKG WAVES=("teensyOutputVoltage,"+num2str(k_teensyOutputCopyChanNum)+";scaledOutputVoltage,"+num2str(k_teensyScaledOutputCopyChanNum)+";")
		daqErrors[i][1]  = fdaqmx_scanstart(ks_dacName,0)		//start dac reading in background, fills cmdCopy and inputCopy
			//get and store dac reads
		daqErrors[i][2]  = fDAQmx_ScanWait(ks_dacName)	//wait til cmdCopy and inputCopy have been filled
		wavestats/q/w teensyOutputVoltage; stats[i][0,numStats-3][%teensyOutputVoltage]=M_wavestats[q]
		wavestats/q/w scaledOutputVoltage;stats[i][0,numStats-3][%scaledOutputVoltage]=M_wavestats[q]
		daqErrors[i][3]  = fDAQmx_ScanStop(ks_dacName)
		
		//output
		if (i==0)
			killwindow/Z $dispWinName
			display/k=1/N=$dispWinName stats[][%avg][%scaledOutputVoltage]/tn=scaledOutputVoltage vs stats[][%cmdVal][0]
			winN=s_name  
			appendtograph/w=$winN/l=L_input stats[][%avg][%teensyOutputVoltage]/tn=teensyOutputVoltage vs stats[][%cmdVal][0]
			appendtograph/w=$winN/l=left_sdev/b=bottom_sdev stats[][%sdev][%scaledOutputVoltage]/tn=scaledOutputVoltage_sdev vs stats[][%cmdVal][0]
			appendtograph/w=$winN/l=L_input_sdev/b=bottom_sdev stats[][%sdev][%teensyOutputVoltage]/tn=teensyOutputVoltage_sdev vs stats[][%cmdVal][0]
			
			errorbars/w=$winN/rgb=(0,0,0) scaledOutputVoltage,y,wave=(stats[][%sdev][%scaledOutputVoltage],stats[][%sdev][%scaledOutputVoltage])
			errorbars/w=$winN/rgb=(0,0,0) teensyOutputVoltage,y,wave=(stats[][%sdev][%teensyOutputVoltage],stats[][%sdev][%teensyOutputVoltage])
			modifygraph/W=$winN axisenab(bottom)={0,0.4},axisenab(bottom_sdev)={0.61,1}
			modifygraph/w=$winN freepos=0,lblpos=52,axisenab(left)={0.55,1},axisenab(l_input)={0,0.45}
			modifygraph/w=$winN freepos=0,lblpos=52,axisenab(left_sdev)={0.62,1},axisenab(l_input_sdev)={0,0.38}
			Label/w=$winN left "Scaled output (V)";Label/w=$winN bottom "Teensy Cmd (0-4095)";Label/w=$winN L_input "Unscaled Teensy Output (V)"
			Label/w=$winN left_sdev "SDEV \\U";Label/w=$winN bottom_sdev "Teensy Cmd (0-4095)";Label/w=$winN L_input_sdev "SDEV \\U"
			ModifyGraph/w=$winN freePos(L_input_sdev)={0,bottom_sdev},freePos(left_sdev)={0,bottom_sdev}
			doupdate;		//need update before matching axis scaling
		endif
		doupdate;
		Print "teensyCal_inputCal() completed level #=",i,"level=",level
	endfor
	
	teensyReturn = teensyCal_writeVal(0);
	print teensyCal_writeVal(9797);		//kick the teensy out of write mode hopefully
	vdtcloseport2 $ks_teensyCom	
	
	
	//fit line to input-output relation
	Variable avgCol = finddimlabel(stats,1,"avg")
	Variable levelsCol = finddimlabel(stats,1,"cmdVal")
	STring coefsSafeRef = statsRef +"_coefs"
	make/o/d/n=(2) $coefsSafeRef/wave=coefs
	Variable pFitStart = ceil((vFitStart-dimoffset(stats,0))/dimdelta(stats,0))		//start with highest acceptable point
	Variable pFitEnd =  floor((vFitEnd-dimoffset(stats,0))/dimdelta(stats,0))		//end with lowest acceptable point
	curvefit/n line, kwcwave=coefs, stats[pFitStart,pFitEnd][avgCol][1]/x=stats[pFitStart,pFitEnd][levelsCol][0]/d //vs stats(vFitStart,vFitEnd)[%avg][%teensyReads]
	ModifyGraph/w=$winN rgb($("fit_"+statsRef))=(1,4,52428)
	
end	

function teensyCal_inputCal(dacNum,statsRef)
	Variable dacNum
	String statsRef		//save results. also displays to 
	
	STring dispWinName = statsRef + "_inputCalWin"
	
	//additional parameters for calibration. Could move these to the function declaration
	Variable vMin = -9,vMax=9		//min is -10,max is +10 
	Variable vEnd = 0		//where to put value at end
	Variable vFitStart=-8,vFitEnd=8		//not necessarily linear throughout range, range to fit for linearity of gain
	Variable numAdditionalLevels=14		//# linearly distributed levels to test between vMin and vMax
	
	Variable numLevels = 2+ numAdditionalLevels		//vMin and vMax plus any additional
	
	vdtoperationsport2 $ks_teensyCom;VDT2/P=$ks_teensyCom baud=k_comBaud;		//connect to teensy
	
	//numRows = numLevels; numCols = numWaveStats; numLayers = 3 (0 is command voltage, 1 is intermediate voltage, 2 is teensy)
	make/o/d/n=(4)/free/W wstest; wavestats/q/w wstest;WAVE M_wavestats;Variable numStats = dimsize(M_wavestats,0)	//just find out how many rows there are in wavestats output
	make/o/d/n=(numLevels,numStats,3) $statsRef/wave=stats; stats = nan
	setscale/I x,vMin,vMax,stats		//assign level scaling (and let Igor calculate intermediate levels)
	dl_lblsToLbls("M_wavestats",0,0,inf,statsRef,1,0,"",0)		//assign wave stats labels to columns	
	dl_assignLblsFromList(stats,2,0,"cmdVoltage;teensyInputVoltage;teensyReads","",0)		//assign layer labels -- order must stay or else update fit code below
	
	//make waves to store raw reads from the command and input copies going into the dac,setup reading into them
	Variable avgPnts = k_dacAvgLenSecs * k_dacSampleRate
	make/o/d/n=(avgPnts) cmdCopy,inputCopy
	setscale/p x,0,1/k_dacSampleRate,"s",cmdCopy,inputCopy
	Variable ok = fDAQmx_ScanStop(ks_dacName)		//assure not already scanning
	
	//run the test
	int i;Double level,rangeMinV,rangeMaxV
	make/o/free/n=(numLevels+1,10) daqErrors = nan	//error tracing
	String winN
	for (i=0;i<numLevels;i+=1)
		level = pnt2x(stats,i)
		rangeMinV = min(level-k_cmdResolutionRange/2,-10)	//mostly a nidaq quirk that has to be dealt with, see fdaqmx_writechan
		rangeMaxV = max(level+k_cmdResolutionRange/2,10)		//mostly a nidaq quirk that has to be dealt with, see fdaqmx_writechan
		daqErrors[i][0] = fdaqmx_writechan(ks_dacName,k_teensyCmdChanNum,level,rangeMinV,rangeMaxV)	//command the level as output
		waitSecs(k_waitAfterNewLevelSecs)
		daqmx_scan/DEV=ks_dacName/AVE=(k_dacAvgNum)/STRT=0/BKG WAVES=("cmdCopy,"+num2str(k_teensyCmdCopyChanNum)+";inputCopy,"+num2str(k_teensyInputCopyChanNum)+";")
		daqErrors[i][1]  = fdaqmx_scanstart(ks_dacName,0)		//start dac reading in background, fills cmdCopy and inputCopy
			//get and store teensy reads
		WAVE teensyReadSet = teensyCal_getReadSet(dacNum)		//get teensy reads
		WAVESTATS/q/w teensyReadSet; stats[i][][%teensyReads]=M_wavestats[q]
			//get and store dac reads
		daqErrors[i][2]  = fDAQmx_ScanWait(ks_dacName)	//wait til cmdCopy and inputCopy have been filled
		wavestats/q/w cmdCopy; stats[i][][%cmdVoltage]=M_wavestats[q]
		wavestats/q/w inputCopy;stats[i][][%teensyInputVoltage]=M_wavestats[q]
		daqErrors[i][3]  = fDAQmx_ScanStop(ks_dacName)
		
		//output
		if (i==0)
			killwindow/Z $dispWinName
			display/k=1/N=$dispWinName stats[][%avg][%teensyReads]/tn=teensyReads vs stats[][%avg][%cmdVoltage]
			winN=s_name
			appendtograph/w=$winN/l=L_input stats[][%avg][%teensyInputVoltage]/tn=teensyInput vs stats[][%avg][%cmdVoltage]
			appendtograph/w=$winN/l=left_sdev/b=bottom_sdev2 stats[][%sdev][%teensyReads]/tn=teensyReads_sdev vs stats[][%sdev][%teensyInputVoltage]
			appendtograph/w=$winN/l=L_input_sdev/b=bottom_sdev stats[][%sdev][%teensyInputVoltage]/tn=teensyInput_sdev vs stats[][%sdev][%cmdVoltage]
			errorbars/w=$winN/rgb=(0,0,0) teensyReads,xy,wave=(stats[][%sdev][%cmdVoltage],stats[][%sdev][%cmdVoltage]),wave=(stats[][%sdev][%teensyInputVoltage],stats[][%sdev][%teensyInputVoltage])		//error bars of sdev for x and y
			errorbars/w=$winN/rgb=(0,0,0) teensyInput,xy,wave=(stats[][%sdev][%cmdVoltage],stats[][%sdev][%cmdVoltage]),wave=(stats[][%sdev][%teensyInputVoltage],stats[][%sdev][%teensyInputVoltage])		//error bars of sdev for x and y
			modifygraph/W=$winN axisenab(bottom)={0,0.4},axisenab(bottom_sdev)={0.61,1},axisenab(bottom_sdev2)={0.61,1}
			modifygraph/w=$winN freepos=0,lblpos=52,axisenab(left)={0.55,1},axisenab(l_input)={0,0.45}
			modifygraph/w=$winN freepos=0,lblpos=52,axisenab(left_sdev)={0.62,1},axisenab(l_input_sdev)={0,0.38}
			Label/w=$winN left "Teensy reads";Label/w=$winN bottom "Command voltage";Label/w=$winN L_input "Scaled voltage"
			Label/w=$winN left_sdev "SDEV \\U";Label/w=$winN bottom_sdev "Command voltage SDEV \\U";Label/w=$winN L_input_sdev "SDEV \\U"
			Label/w=$winN bottom_sdev2 "Scaled input SDEV \\U"
			ModifyGraph/w=$winN freePos(L_input_sdev)={0,bottom_sdev},freePos(left_sdev)={0,bottom_sdev2},freepos(bottom_sdev2)={0,left_sdev},lblPos(bottom_sdev2)=33
			doupdate;		//need update before matching axis scaling
		endif
		doupdate;
		Print "teensyCal_inputCal() completed level #=",i,"level=",level
	endfor
	
	vdtcloseport2 $ks_teensyCom
	
	daqErrors[i][0] =fdaqmx_writechan(ks_dacName,k_teensyCmdChanNum,vEnd,rangeMinV,rangeMaxV)	//command the level as output -- not sure why but this isnt working
	
	
	//fit line to input-output relation
	Variable avgCol = finddimlabel(stats,1,"avg")
	STring coefsSafeRef = statsRef +"_coefs"
	make/o/d/n=(2) $coefsSafeRef/wave=coefs
	Variable pFitStart = ceil((vFitStart-dimoffset(stats,0))/dimdelta(stats,0))		//start with highest acceptable point
	Variable pFitEnd =  floor((vFitEnd-dimoffset(stats,0))/dimdelta(stats,0))		//end with lowest acceptable point
	curvefit/n line, kwcwave=coefs, stats[pFitStart,pFitEnd][avgCol][2]/x=stats[pFitStart,pFitEnd][avgCol][0]/d //vs stats(vFitStart,vFitEnd)[%avg][%teensyReads]
	ModifyGraph/w=$winN rgb($("fit_"+statsRef))=(1,4,52428)
	

end


//functions to read from the teensy
function/WAVE teensyCal_getReadSet(dacNum)
	Variable dacNum		//presently allows 0 or 1 for the input to A0 or A1 pins
	
	Variable i
	for (i=0;i<k_teensyReadSetsToAvg;i++)
		WAVE/I currReads = teensyCal_getReads(dacNum)
		if (i==0)
			duplicate/o/free/i currReads,out
		else
			concatenate/np=0 {currReads},out
		endif
	endfor
		
	return out
end

function/WAVE teensyCal_getReads(dacNum)
	Variable dacNum		//presently allows 0 or 1 for the input to A0 or A1 pins
	
	String cmdChar = selectstring(dacNum,"a","b")		//meaning of these for serial i/o set in loop of .ino sktch
	VDT2/P=$ks_teensyCom killio	//delete and previous serial i/o
	
	VDTWrite2/O=1/Q cmdChar		//only one character commands are currntly parsed
	if (!V_VDT)		//failed
		print "teensyCal_getReads() failed to send command for reads"
		make/o/free/i out = {-1}		//teensy cant have negative values, so this will indicate an error
		return out
	endif
	
	//wait for a return from the teensy over serial i/o
	Variable startms = ticks,elapsedSecs
	String outStr=""
	do
		vdtgetstatus2 0,0,0		//check for input on the serial buffer
		if (V_VDT > 0)
			vdtread2/O=1/T="\r" outStr;
			if (V_VDT < 1)
				print "teensyCal_getReads() failed to get reads"
				make/o/free/i out = {-1}		//teensy cant have negative values, so this will indicate an error
				return out
			endif
			VDT2/P=$ks_teensyCom killio	//delete and previous serial i/o
			break		//succeeded, so break
		endif
		elapsedSecs = (ticks-startms)/60 
	while ( elapsedSecs < k_teensyReturnTimeOutSecs)
	
	if (strlen(outStr) < 1)
		make/o/free/i out={-1}		//teensy cant have negative values, so this will indicate an error
		return out	
	endif
	
	Variable outpnts = itemsinlist(outStr)
	if (k_teensyNumReadReturns != outpnts)
		print "teensyCal_getReads() warning, expected readNum=",k_teensyNumReadReturns,"but received",outpnts,"may need to change a constant here or in .ino sktch"
	endif
	make/o/i/n=(k_teensyNumReadReturns)/free out = str2num(stringfromlist(p,outStr))
	
	return out
end
	
//assumes teensy is already connected via serial
function teensyCal_enterWriteMode()
	//teensy may already be in write mode, if sending back numbers
	String teensyReturn = teensyCal_writeVal(1025)		//pick a random write val
	if (stringmatch(teensyReturn,"1025"))
		return 1
	endif
	
	String template = "*entering write mode.*"
	VDTWrite2/O=1/Q "w"	;waitSecs(1)
	String out = com_readsafe(ks_teensyCom,"\r")
	if (stringmatch(out,template))
		return 1
	endif
	VDTWrite2/O=1/Q "w"	;waitSecs(1)
	out = com_readsafe(ks_teensyCom,"\r")
	if (stringmatch(out,template))
		return 1
	endif
	
	print "teensyCal_enterWriteMode() appears to have failed to enter write mode!"
	return 0
end

function/S teensyCal_writeVal(val)
	Variable val //should be 0-4095
	
	val = max(val,0)
	val = min(val,4095)
	
	Variable teensySendType = 2^4 + 2^6		//send as unsigned 16-bit integers
	
	vdtwritebinary2/type=(teensySendType)/o=(3)/b val
	waitSecs(0.1)
	String teensyReturn = com_readSafe(ks_teensyCom,"\r")		//teensy will echo the commanded number if in write mode, and set DAC0 on pin A21 to command value
	return teensyReturn
end

function teensyCal_setFollowMode(dacNum,enterFollowMode)
	Variable dacNum
	Variable enterFollowMode		//1 to enter, 0 to exit
	
	
	vdt2 killio
	String template = "*entering follow mode.*"
	String out
	
	if (enterFollowMode)
		String cmdStr = selectstring(dacNum,"f","g")		//f puts into write mode for dac0, g for dac1
		VDTWrite2/O=1/Q cmdStr	;waitSecs(1)
		out = com_readsafe(ks_teensyCom,"\r")
		if (stringmatch(out,template))
			return 1
		endif
		VDTWrite2/O=1/Q cmdStr;waitSecs(1)
		out = com_readsafe(ks_teensyCom,"\r")
		if (stringmatch(out,template))
			return 1
		endif
		
		print "teensyCal_enterFollowMode() appears to have failed to enter follow mode for dac",dacNum,"!"
		return 0	
	endif
	
	VDTWrite2/O=1/Q "q"	;waitSecs(1)	//anything but 'f','g', and 'v' should break follow mode
	out = com_readsafe(ks_teensyCom,"\r")
	if (!stringmatch(out,template))
		return 0
	endif
	String out1 = com_readsafe(ks_teensyCom,"\r")		//just in case of a build-up of commands, check one more
	return stringmatch(out,template)	//return 0 if truly out of follow mode, 1 if still in
end
#endif

function/S com_readSafe(comStr,termStr)
	String comstr,termStr
	
	if (strlen(termStr) < 1)
		termStr = ",\r\t"
	endif
	
	vdtoperationsport2 $comStr
	VDTGetStatus2 0, 0, 0; 
	String out =""
	if (v_vdt > 0)
		vdtread2/O=1/T=termStr out;
		return out
	else
		return "<<nothing to read>>"
	endif
end
