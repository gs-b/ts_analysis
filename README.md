# ts_analysis
Time series (ts) and electrophysiology analysis in Igor Pro, including abf loading and analysis routines in Wavemetrics Igor Pro (7 and 8)

![file panel](/file_panel_image.png)

# Requirements for complete functionality
* Igor Pro 7 or 8 (tested most recently in 8.05). Download from Wavemetrics.com
* Bruxton DataAccess (currently available for download at https://www.bruxton.com/legacy.html)
  * *Data Access only runs on Windows!* See below for limited use options on other devices.
  * Follow Bruxton's installation directions. 
  * After installation, find ABFXOP.xop and place it in the 32-bit Igor Extensions folder (on my device this is at Program Files C:\Program Files (x86)\WaveMetrics\Igor Pro 8 Folder\Igor Extensions) 
* igorUtilities.ipf, available at https://github.com/gs-b/igorUtilities, is strictly required for the code to fully compile.
  * Quick installation: download anywhere on your computer and drag it into Igor
  * Permenant installation: download and save into the Igor Procedures folder (on my device, this is at Documents/WaveMetrics/Igor Pro 8 User Fies/Igor Procedures/)
  * Sustainable installation: clone the https://github.com/gs-b/igorUtilities git repository onto your device, then make a shortcut to the repository folder and place the shortcut in the Igor Procedures folder.
  
# Incomplete functionality options
* Bruxton DataAccess (which entails a Windows PC and 32-bit Igor) is not required unless loading files directly from ABF. Other analysis routines remain available. To use the data loader on a Mac, one option to use the 'ABF -> IBW' (ABF to IBW) option on a Windows machine with Bruxton DataAccess. Files will be converted to and stored as Igor Binary Waves (IBWs), which can then be loaded on Mac.
* On 64-bit Windows PCs that have Bruxton DataAccess, 64-bit Igor can be used in tandem with 32-bit Igor for direct loading from ABF (further discussed below).

# Installation
All procedures are currently contained in a single procedure (.ipf) file for ease of loading into an instance of Igor. The install options are the same as for igorUtilities.ipf:
  * Quick installation: download anywhere on your computer and drag it into Igor
  * Permenant installation: download and save into the Igor Procedures folder (on my device, this is at Documents/WaveMetrics/Igor Pro 8 User Fies/Igor Procedures/)
  * Sustainable installation: clone this repository onto your device, then make a shortcut to the repository folder and place the shortcut in the Igor Procedures folder. If you clone this repo and the igorUtilities repo, you can put them in the same parent directory and use a single shortcut for that directory in order to automatically use both in Igor.
  
 
# Contents
This readme currently has the following sections (the start of which is indicated with four hyphens):
'ABF-loading specific information and usage': a GUI for abf loading into Igor
'Super-simple spike timing': extracts spike timing; so far only used with whole-cell recording

# ABF-loading specific information and usage

Getting started: Once installation is finished, you can begin loading by hitting F12 (or selecting the menu item Misc->filePanel load/start). Alternatively, you can run fd_abfload("") from the command line. These options both initialize the GUI and immediately open a file chooser to select ABFs to "Index". Once ABFs have been indexed, they can be loaded through the file panel GUI.

ABf file organization: ABF files that are to be loaded into waves can be stored anywhere in your file architecture. However, for portability, it is strongly recommended that abfs be stored within subfolders of a main "parent" folder. No abfs should be stored in the parent folder. Following this method, as long as the parent folder and relevant subfolders are available, a pxp can be reopened on a different folder and mapped to the new location of the parent folder. 

This organization also allows bulk loading of all ABFs within all subfolders of a chosen "parent"/root folder. Shift click the "Index ABFs" button and choose a parent folder to use this loading method. This loads all ABFs within all the parent folders subdirectories (but not within any folders within the subdirectories).

Abf file names: To use all available functions, ABF's should follow this naming scheme exactly: <letter e.g. C for last name Clark><2-digit year e.g. 18 for 2018><2-digit month e.g. 12 for december><2-digit day e.g. 07 for the 7th of december><2-digit descriptive number e.g., 00 for cell 00 recorded on dec. 7th><underscore><4-digit file number e.g. 0000 for the first file associated with cell 00 recorded on dec. 7th>. In this example, the file name would be: 'B18120700_0000.abf'

32-bit vs 64-bit Igor: Because DataAcces only runs on 32-bit Igor, abf files can only be loaded into waves in 32-bit Igor. However, functions associated with ABF loader can be used to run 32-bit and 64-bit instances of Igor side by side in order to load the waves in 32-bit Igor and have the waves automatically retrieved by 64-bit Igor.
64-bit Igor can use ~all of the computer's RAM, whereas 32-bit is limited to ~3 gb even if the computer has more RAM.

Loading with the GUI: Abf files first have to be indexed in a filePanel, then their data can be loaded into Igor one or more waves. Indexing can occur at initialization (by selecting ABFs when prompted with the file chooser dialog) or anytime afterwards by hitting F12, clicking 'filePanel start\load' under Misc, or running fd_abfload(""). Each indexed file is given an index from 0 to N-1 where N is the number of files that have been loaded. There is currently no way to remove a file from the index.

Data from an indexed file can be loaded into waves be double-clicking the left-most column of the filePanel in the row containing the file name. Multiple files can be loaded at once by selecting them their rows in the filePanel and then double clicking the header row of the left-most column (titled 'Load'). A red underlined L will appear once the file(s) have been loaded. Repeating a double click on a loaded wave toggles loading; thus it "unloads" waves that have been loaded by deleting them. Any modifications to the waves since loading will be lost. 

The selection of channels that are loaded with each wave can be toggled in a similar manner (by double-clicking the associated cell in filePanel or double-clicking a column header to toggle the entire file selection). Numbers in the listbox labeled 'CH' can be selected and then its header double-clicked in order to apply a pattern of channel selections to selected files. Channels marked by red, underlined L's are toggled for loading (and by default all channels are set to be loaded when a file is newly indexed)

The selection of sweeps to load can be set in a similar manner by making a selection in the listbox below CH and then double-clicking its header. Note, however, that this is applied specifically to each sweep rather than across channels. This listbox displays every sweep for every selected file in order, listed in rows as <Index of sweep's file><underscore><sweep number from 0 to numSweeps-1> and sweeps selected to be loaded are indicated as for files and channels.

Visualizing data with the GUI: Data loaded from files can be displayed on the main graph, which receives an automatic name upon creation. The right-most listboxes are dedicated to display. Any files selected AND loaded are listed in the bottom-right listbox, with one row for each sweep. One or more of these rows can be selected, and the sweep(s) will be overlaid on the main graph. By default, each channel receives its own axis (though see below). 

If the 'Save Y Ax' chechbox is set, then the sweep display list selection can change and any y-axis range set for display in the main graph will be maintained. The same is true for x axes if the 'Save X Ax' checkbox is set. However, note that when the file selection changes, the settings in the top-right listbox may be reset. (More specifically, if new files are selected by a standard click rather than a shift-click, which normally adds more files to the current selection, then the settings are reset.)

The upper-right listbox can be used to overlay various channels and change the axis positions. Each axis has a row and each string under the 'O/L' column (which stands for overlay) indicates which channel (from 0 to numChans-1, reading left to right) is displayed on that axis, with 1 indicating displayed and 0 indicating not. If an axis has no channel displayed (a list of "000..." in the O/L column, that axis is no longer plotted). Ax start and ax end can be used to set the axis start and end; if blank, axes are distributed uniformly along the window). Note that this listbox is reset to its default when the file selection changes, in the same manner as for y range and x range settings with 'Save Y Ax' and 'Save X Ax'.

A graph can be "copied" and its copy will no longer be modified by the filePanel by hitting Ctrl+D while it is the top window. Importantly, the waves are also saved from deletion by unloading at this point because waves that are displayed on a graph cannot be killed (the filePanel usually automatically circumvents this issue and kills waves even if they are selected for display by clearing them from the main graph.)

A new graph can be created and set as the main graph by clicking the 'Change graph' button. Shift-clicking this button brings the main graph back to the top of all the windows, which can be helpful for finding it among many other graphs.

Other GUI functions: Automatic junction potential correction or downsampling can be applied as waves are loaded from files using their associated fields at the bottom of the filePanel. Mounse over them for directions on their usage.

The '/O' checkbox determines behavior when a wave loaded (or more often re-loaded) but a wave of the same name already exists in Igor. When checked, the pre-existing wave is overwritten, when unchecked, it is not. This can be particularly important when junction potential or auto downsampling settings have changed or if the user is performing analysis that modifies waves loaded by the filePanel -- directly modifying these waves can be confusing and it is probably better to make a copy with the built-in duplicate function.

The string directly below the main (file selection) listbox, beginning with "#SWs:..." has useful tallies for the current selection of files (taking into account channel and sweep selections). It reports, in order from left to right, the total number of sweeps selected, the total number of waves selected, the total free memory now, and the total free memory that would be available after load. The latter two are particularly useful for determining if you are about to try to load waves that can't fit into memory. Note that, at present, this only updates when the file selection changes (not just if channel or sweep selections change).

Programming function organization: Key functions have names beginning with "fd_" (for file directory; these usually relate to the organization of data in Igor) or "da_" (for data access; these are usually functions that directly call routines available through ABFXOP.xop). You can use these starting strings as filters in the procedure browser to quickly see all the functions that are available. 



# Super-simple spike timing

Initialization: Select a wave to analyze. (A simple way to do this is to display it via the abf loader then right click and select copy trace name.) Then run this command: spike_timesFromDvDt(...) and pass the wave to be analyzed as the first parameter. For more information, see the commments next to the input parameters of spike_timesFromDvDt(...), as well as this example:

In the simplest usage, use the cursors (brought up with ctrl+i while a graph plotting the wave is top window) to select a wave and specify a range where there are no spikes, from which the threshold is calculated. Place cursor A at the start of the region and cursor B at the end, then run:

spike_timesFromDvDt($csrwave(A),"","",0.01,xcsr(A),xcsr(B),nan,0,inf)	//initiates spike time identification using the range between csr A and csr B as a baseline without spiking enforcing a 0.01 second refractory period. The default threshold for a spike is simply dvdt > 6*<standard deviation of the dvdt trace from this baseline> to implement Milner and Do 2017's method.

Two windows are generated. The first is a graph that displays the wave along with its first and second derivatives. Accepted spike times are the top-most bars above the raw trace; any spikes rejected (usually due to refractory period limit), will be on the lower trace. The second is a table containing a 2D wave, where rows are potential spikes and columns are different parameters for each spike. The spike time is set as the time at which the dvdt trace crossed a threshold, and this is stored in the dvdtThresholdX column. yDispVal sets whether a spike time appears on the upper or lower spike Times trace in the window. Spikes with a yDispVal of 0 are considered real and <0 are rejected (e.g., -1 values were rejected because of their refractory period). Users could add meaning for other negative values in the future, which would aid in scanning through determining why events were rejected. 

Call the function spike_getFinalTimes(...) to get a simple array of the final spike times. These can also be directly copied from the table. 

Use left/right arrow keys or shift+click to select and navigate to specific spikes.

left/right arrow keys normally ignore rejected spikes, but with ctrl down they are included.

left/right arrow keys with shift down scan through bouts of time instead, without regard to whether there are spikes. The default is the end of the current window to 10s past that point. 

up and down arrow keys will change the value of a selected spike by +1 or -1, respectively. This provides one way for the user to manually add or remove events. 

Programming function organization: The names of all key functions start with "spike_" (so they can be easily viewed in the procedure browser). Preferences such as the 10s window for left/right arrow + ctrl can be set in spike_winHook() and the functions it calls.


