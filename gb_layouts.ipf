#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.


Menu "Layout"
	"Bring Layout Page Objects to Top/O1",/Q,layout_objsToTop(0)
	"Show Layout Page Objects (only)/1",/Q,layout_objsToTop(1)
end

function layout_objsToTop(hideOthers)
	int hideOthers
	
	String objs = layout_getPageObjList(""),name
	int numToShow=itemsinlist(objs),i
	
	if (hideOthers)
		String wins = winlist("*",";","WIN:"+num2str(1+2+16+64+16384+65536))
		int numWins = itemsinlist(wins)
		for (i=0;i<numWins;i+=1)
			name = stringfromlist(i,wins)
			if (whichlistitem(name,objs) < 1)
				dowindow/hide=1 $name
			endif
		endfor
	endif
	
	for (i=0;i<numToShow;i+=1)
		name = stringfromlist(i,objs)
		dowindow/f/hide=0 $name
	endfor
end

function/s layout_getPageObjList(layoutName)
	String layoutName
	
	int i,numObjs = layout_getNumObjsOnPage(layoutName)
	STring out = "",info,name
	for (i=0;i<numObjs;i+=1)
		info = layoutinfo(layoutName,num2str(i))
		name = stringbykey("name",info)
		out += name + ";"
	endfor	
	return out
end

function layout_getNumObjsOnPage(layoutName)
	String layoutName
	
	return numberbykey("numobjects",layoutinfo(layoutName,"Layout"))
end

function layout_appendGraphs(layoutName,graphMatchStr,numGraphs)
	String layoutName; String graphMatchStr; Variable numGraphs
	
	if (strlen(graphMatchStr) < 1)
		graphMatchStr = "*"
	endif
	
	String layouts = winlist("*",";","WIN:4")
	if (strlen(layoutName) < 1)
		layoutName=stringfromlist(0,layouts)
	else
		if (whichlistitem(layoutName,layouts) < 0)		//no window of name, make new
			newlayout/N=$layoutName
			layoutname=s_name
			print "layout_appendGraphs() new layout",layoutName
		endif
	endif
	
	String graphs=winlist(graphMatchStr,";","WIN:1")
	Variable i,numGraphsFound=itemsinlist(graphs)
	Variable num=min(numGraphsFound,numGraphs)
	String graphN
	for (i=0;i<num;i+=1)
		graphN = stringfromlist(i,graphs)
		appendlayoutobject/w=$layoutName graph $graphN
	endfor
	
end
