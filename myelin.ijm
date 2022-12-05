
/**
  * Myelin Sheath analysis tool
  * inspired from MRI g-ratio Tools (Volker Baecker at Montpellier RIO Imaging (www.mri.cnrs.fr))
  * (c) 2020, ULiège
  * written by Pierre Tocquin at University of Liège
  *
*/

var RADIUS_MEDIAN_FILTER = 5;
var SATURATED_PIXELS = 25;
var MIN_SIZE = 1000;
var MIN_CIRCULARITY = 0.1;
var MIN_SOLIDITY = 0.7;
var THRESHOLD_METHOD = "IsoData";
var _AXON_ROI_COLOR = "red";
var _AXON_ROI_WIDTH = 2;
var DO_CONVEXHULL = 0; //1=TRUE 0=FALSE
var METHOD = "tangent"; // center | tangent
var _ON_BORDER_CHECK = false;

var xcenters;
var ycenters;
var areas;
var mouseID;

var	title_details = "axon_analysis_details.csv";
var	title_summary = "axon_analysis_summary.csv";
var	title_anormal = "anormal_axon_analysis.csv";
var	handle_anormal = "[" + title_anormal + "]";
var	handle_details = "[" + title_details + "]";
var	handle_summary = "[" + title_summary + "]";
var dir;
var file;
var filename;
var datapath = ""; //getDirectory("Select the directory to store de results");

var scale_pixels;
var scale_mu = 5; // TODO to be set by user
var roi_area;
var roi_width;
var roi_height;
var n_axons;
var total_axons;


var axon_R;
var axon_r;
var g_ratio;
var thickness;
var to_analyse;

macro 'Help Action Tool Options' {
	Dialog.create("Options");
	items = newArray("yes","no");
	Dialog.addRadioButtonGroup("Apply Convex hull ?", items, 1, 2, "no");
	items = newArray("yes","no");
	Dialog.addRadioButtonGroup("Check for axons on border ?", items, 1, 2, "no");
	items = newArray("center", "tangent");
	Dialog.addRadioButtonGroup("Thickness computation method ?", items, 1, 2, "tangent");
	Dialog.addNumber("Scale (µm): ", scale_mu);
	Dialog.addString("Path to data files", datapath)
	Dialog.addNumber("Saturated pixels (25-50): ", SATURATED_PIXELS);
	Dialog.addNumber("Median filter (3-9): ", RADIUS_MEDIAN_FILTER);
	Dialog.addNumber("Min size (1000-5000): ", MIN_SIZE);
	Dialog.addNumber("Min circularity (0.1): ", MIN_CIRCULARITY);
	Dialog.addNumber("Min solidity (0.7): ", MIN_SOLIDITY);
	Dialog.show();
	radio = Dialog.getRadioButton();
	if(radio == "no") {
	DO_CONVEXHULL = false;
	}
	radio = Dialog.getRadioButton();
	if(radio == "yes") {
	_ON_BORDER_CHECK = true;
	}
	METHOD = Dialog.getRadioButton();
	scale_mu = Dialog.getNumber();
	datapath = Dialog.getString();
   SATURATED_PIXELS = Dialog.getNumber();
   RADIUS_MEDIAN_FILTER = Dialog.getNumber();
   MIN_SIZE = Dialog.getNumber();
   MIN_CIRCULARITY = Dialog.getNumber();
   MIN_SOLIDITY = Dialog.getNumber();
}

macro 'Prepare Image Action Tool (f1) - C000T4b12p' {
	setDataDirectory();
	SetZoneAndScale();
	prepareImage();
}

macro 'Prepare Image [f1]' {
	SetZoneAndScale();
	prepareImage();
}

macro 'Detect Axons Action Tool (f2) - C000T4b12d' {
	openOutputFiles();
	findAxons();
}

macro 'Detect Axons [f2]' {
	openOutputFiles();
	findAxons();
}

macro 'Measure Myelin Sheath Action Tool (f3) - C000T4b12c' {
	total_axons = roiManager("count");
	openOutputFiles();
	//checkAxons();
	measureMyelin();
}

macro 'Measure Myelin Sheath Axons [f3]' {
	total_axons = roiManager("count");
	openOutputFiles();
	//checkAxons();
	measureMyelin();
}

macro 'Add axon Action Tool (a) - C000T4b12+' {
	addAxon();
}

macro 'Add axon Axons [a]' {
	addAxon();
}

macro 'Remove axon Action Tool (d) - C000T4b12-' {
	removeAxon();
}

macro 'Remove axon Axons [d]' {
	removeAxon();
}

macro 'Set data directory Action Tool (f6) - C000T4b12D' {
	setDataDirectory();
}

macro 'Set data directory Axons [f6]' {
	setDataDirectory();
}

macro 'Recompute Action Tool (v) - C000T4b12v' {
	openOutputFiles();
  	//SetZoneAndScale();
	reCompute();
}

macro 'Recompute Axons [v]' {
	openOutputFiles();
  	//SetZoneAndScale();
	reCompute();
}

macro 'Set Axon as anormal [b]' {
	setAxonAsNormal();
}


macro 'Set Axon as normal [n]' {
	setAxonAsNormal();
}

macro 'Set Mitochondrion as normal [m]' {
	setMitoAsNormal();
}

macro 'Count normals/anormals [c]' {
	summarized();
}

macro 'Set All axon as Normal [N]' {
	setAllAxonAsNormal();
}

macro 'Set All Mitochondrion as Normal [M]' {
	setAllMitoAsNormal();
}

//macro 'Move ROI Action Tool (f7) - C000T4b12M' {
//	roiTranslate();
//}

//macro 'Move ROI Axons [f7]' {
//	roiTranslate();
//}

macro 'Single myelin Action Tool (f7) - C000T4b12S' {
	singleMyelin();
}

macro 'Single myelin Axons [f7]' {
	singleMyelin();
}

function setAllAxonAsNormal(){
	if(getBoolean("All information about normal/anormal axon state will be cleared ?") == true){
		n = roiManager("count");
		for(j=0;j<n;j++){
			roiManager("Select", j);
			name = Roi.getName;
			if(matches(name,"axon_[0-9]{4}_.*") == true) { // les objets relatifs aux mesures des gaines ne sont pas comptés
				Roi.setGroup(0);
				roiManager("Set Color", "blue");
				roiManager("Set Line Width", 2);
			} else {
				axonStatusNormal();
			}
		}
		roiManager("deselect");
	}
}

function setAllMitoAsNormal(){
	if(getBoolean("All information about normal/anormal mitochondria state will be cleared ?") == true){
		n = roiManager("count");
		for(j=0;j<n;j++){
			roiManager("Select", j);
			name = Roi.getName;
			if(matches(name,"axon_[0-9]{4}_.*") == true) { // les objets relatifs aux mesures des gaines ne sont pas comptés
				Roi.setGroup(0);
				roiManager("Set Color", "blue");
				roiManager("Set Line Width", 2);
			} else {
				mitoStatusNormal();
			}
		}
		roiManager("deselect");
	}
}

function setAsAnormal() {
	if (roiManager("index")!=-1) {  // Check that a ROI is selected
		Roi.setFillColor('#ff0000');
		Roi.setProperty('axon_status','anormal');
		Roi.setGroup(2);
		Roi.setStrokeColor("red");
		Roi.setStrokeWidth(2);
	} else {
		run("Select None");
		getCursorLoc(x, y, z, flag);
		n = roiManager("count");
		for(j=0;j<n;j++){
			roiManager("Select", j);
			if(Roi.contains(x, y)){
				// print("OK !"+j+" ... "+roiManager("index"));
				roiManager("Show All");
				roiManager("Select", j);
				Roi.setFillColor('#ff0000');
				Roi.setProperty('axon_status','anormal');
				Roi.setGroup(2);
	 			Roi.setStrokeColor("red");
	 			Roi.setStrokeWidth(2);
	 			// setFont("SanSerif", 40, "antialiased");
  			// 	setColor("red");
  			// 	makeText("A", x-20, y+20);
  			// 	Overlay.addSelection;
  				// run("Add Selection...", "stroke=red font=40 new");
	 			// roiManager("Show None");
			}
		}
	}
	roiManager("deselect");
}

function axonStatusNormal() {
	Roi.setProperty('axon_status','normal');
	Roi.setGroup(1);
	//Roi.setFillColor('#00000000');
	Roi.setStrokeColor("blue");
	Roi.setStrokeWidth(2);
}

function axonStatusAnormal() {
	Roi.setProperty('axon_status','anormal');
	Roi.setGroup(2);
	//Roi.setFillColor('#33FF0000');
	Roi.setStrokeColor("red");
	Roi.setStrokeWidth(2);
}

function mitoStatusAnormal() {
	Roi.setProperty('mito_status','anormal');
	Roi.setFillColor("#33FF0000");
}

function mitoStatusNormal() {
	Roi.setProperty('mito_status','normal');
	Roi.setFillColor("#3300FF00");
}


function setAxonAsNormal() {
	if (roiManager("index")!=-1) {  // Check that a ROI is selected
		if (Roi.getProperty('axon_status') == 'anormal') {
			axonStatusNormal();
		} else {
			axonStatusAnormal();
		}
		roiManager("deselect");
	} else {
		run("Select None");
		getCursorLoc(x, y, z, flag);
		n = roiManager("count");
		for(j=0;j<n;j++){
			roiManager("Select", j);
			if(Roi.contains(x, y)){
				roiManager("Show All");
				roiManager("Select", j);
				if (Roi.getProperty('axon_status') == 'anormal') {
					axonStatusNormal();
				} else {
					axonStatusAnormal();
				}
			}
		}
		roiManager("deselect");
	}
}

function setMitoAsNormal() {
	if (roiManager("index")!=-1) {  // Check that a ROI is selected
		if (Roi.getProperty('mito_status') == 'anormal') {
			mitoStatusNormal();
		} else {
			mitoStatusAnormal();
		}
		roiManager("deselect");
	} else {
		run("Select None");
		getCursorLoc(x, y, z, flag);
		n = roiManager("count");
		for(j=0;j<n;j++){
			roiManager("Select", j);
			if(Roi.contains(x, y)){
				roiManager("Show All");
				roiManager("Select", j);
				if (Roi.getProperty('mito_status') == 'anormal') {
					mitoStatusNormal();
				} else {
					mitoStatusAnormal();
				}
			}
		}
		roiManager("deselect");
	}
}

function summarized() {
  mouseID = getString("Enter the mouse ID", mouseID);
  file = getInfo("image.filename");
	if (!isOpen(title_anormal)) {
		run("New... ", "name="+title_anormal+" width=400 height=600");
		print(handle_anormal, "\\Headings:MouseID\timage\taxon\tstatus\tarea");
	}

  total = roiManager("count");
  roiManager("Deselect");
  run("Select None");
  run("Clear Results");
  for(i=0;i<total;i++){
    roiManager("Select", i);
    name = Roi.getName;
    if(matches(name,"axon_[0-9]{4}")){ // matching only axons
      if(Roi.getGroup == 2){
        print(handle_anormal, mouseID + "\t" + file + "\t" + name + "\t" + "anormal" + "\t" + getValue("Area") );
      }
      if(Roi.getGroup == 1){
        print(handle_anormal, mouseID + "\t" + file + "\t" + name + "\t" + "normal" + "\t" + getValue("Area") );
      }
      if(Roi.getGroup == 0){
        print(handle_anormal, mouseID + "\t" + file + "\t" + name + "\t" + "undefined" + "\t" + getValue("Area") );
      }
    }
  }

//	total = roiManager("count");
//	run("Clear Results");
//	RoiManager.selectGroup(2);
//  if (RoiManager.selected > 0) {
//    roiManager("measure");
//    anormal = getValue("results.count");
//    for(j=0;j<anormal;j++){
//      print(handle_anormal, mouseID + "\t" + file + "\t" + "anormal" + "\t" + getResult("Area", j) );
//    }
//    run("Clear Results");
//    RoiManager.selectGroup(1);
//    roiManager("measure");
//    normal = getValue("results.count");
//    for(j=0;j<normal;j++){
//      print(handle_anormal, mouseID + "\t" + file + "\t" + "normal" + "\t" + getResult("Area", j) );
//    }
//    run("Clear Results");
//  }


  close();
  roiManager("reset");

	//run("Original Scale");
	//roiManager("save", dir + filename + ".zip");
	//selectWindow(title);
	//saveAs("results", dir + title);
}


function checkAxons(){
	n_axons = roiManager("count");
	to_analyse = newArray();
	for(i=0;i<n_axons;i++){
		roiManager("Select", i);
		run("To Selection");
		run("Out [-]");
		ii=i+1;
		if(getBoolean("Keep this axon ? Clicking NO will remove the object.") == true){
			to_analyse = Array.concat(to_analyse, i);
			//Array.print(to_delete);
			// roiManager("delete");
			// n_axons = roiManager("count");
			// xcenters = newArray();
			// ycenters = newArray();
			// areas = newArray();
			// run("Clear Results");

			// for(j=0; j<n_axons; j++){
			// 	roiManager("Select", j);
			// 	run("Measure");
			// 	xcenters = Array.concat(xcenters, getResult("XM", nResults-1));
			// 	ycenters = Array.concat(ycenters, getResult("YM", nResults-1));
			// 	areas = Array.concat(areas, getResult("Area", nResults-1));
			// 	roiManager("Rename", "axon_" + IJ.pad((j+1),4));
			// 	roiManager("Set Color", _AXON_ROI_COLOR);
			// 	roiManager("Set Line Width", _AXON_ROI_WIDTH);
			// 	roiManager("Update");
			// }
		}
	}

	//Array.print(to_delete);

	//roiManager("Select", to_delete);
	//roiManager("delete");

	// n_axons = roiManager("count");
	// xcenters = newArray();
	// ycenters = newArray();
	// areas = newArray();
	// run("Clear Results");

	// for(j=0; j<n_axons; j++){
	// 	roiManager("Select", j);
	// 	run("Measure");
	// 	xcenters = Array.concat(xcenters, getResult("XM", nResults-1));
	// 	ycenters = Array.concat(ycenters, getResult("YM", nResults-1));
	// 	areas = Array.concat(areas, getResult("Area", nResults-1));
	// 	roiManager("Rename", "axon_" + IJ.pad((j+1),4));
	// 	roiManager("Set Color", _AXON_ROI_COLOR);
	// 	roiManager("Set Line Width", _AXON_ROI_WIDTH);
	// 	roiManager("Update");
	// }

	//Array.print(areas);
}

function addAxon(){
	run("Select None");
	setTool("polygone");
	waitForUser("Trace an axon... Click OK when done");
	if(DO_CONVEXHULL) {
		run("Convex Hull");
	}
	roiManager("add");
	n_axons = roiManager("count");
	roiManager("Select", n_axons-1);
	run("Interpolate", "interval=1");
	roiManager("Update");

	xcenters = newArray();
	ycenters = newArray();
	areas = newArray();
	run("Clear Results");
	i=0;
	j=1;
	while(i<n_axons){
		roiManager("Select", i);
		name = Roi.getName;
		//print("Selection: "+name);
		axon_R = newArray();
		axon_r = newArray();
		g_ratio = newArray();
		thickness = newArray();
		if(matches(name,"axon_[0-9]{4}_.*") == false){ //
			run("Measure");
			xcenters = Array.concat(xcenters, getResult("XM", nResults-1));
			ycenters = Array.concat(ycenters, getResult("YM", nResults-1));
			areas = Array.concat(areas, getResult("Area", nResults-1));
			roiManager("Rename", "axon_" + IJ.pad((j),4));
			roiManager("Set Color", _AXON_ROI_COLOR);
			roiManager("Set Line Width", _AXON_ROI_WIDTH);
			roiManager("Update");
			j++;
		}
		i++;
	}

	//Array.print(areas);

}

function removeAxon(){
	//run("Select None");
	//setTool("polygone");
	//waitForUser("Select an object in ROIManager... Click OK when done");
	if(roiManager("index")<0){
		return
	}
	roiManager("delete");
	n_axons = roiManager("count");
	xcenters = newArray();
	ycenters = newArray();
	areas = newArray();
	run("Clear Results");

	i=0;
	j=1;
	while(i<n_axons){
		roiManager("Select", i);
		name = Roi.getName;
		//print("Selection: "+name);
		axon_R = newArray();
		axon_r = newArray();
		g_ratio = newArray();
		thickness = newArray();
		if(matches(name,"axon_[0-9]{4}_.*") == false){ //
			run("Measure");
			xcenters = Array.concat(xcenters, getResult("XM", nResults-1));
			ycenters = Array.concat(ycenters, getResult("YM", nResults-1));
			areas = Array.concat(areas, getResult("Area", nResults-1));
			roiManager("Rename", "axon_" + IJ.pad((j),4));
			roiManager("Set Color", _AXON_ROI_COLOR);
			roiManager("Set Line Width", _AXON_ROI_WIDTH);
			roiManager("Update");
			j++;
		}
		i++;
	}

	// for(i=0; i<n_axons; i++){
	// 	roiManager("Select", i);
	// 	run("Measure");
	// 	xcenters = Array.concat(xcenters, getResult("XM", nResults-1));
	// 	ycenters = Array.concat(ycenters, getResult("YM", nResults-1));
	// 	areas = Array.concat(areas, getResult("Area", nResults-1));
	// 	roiManager("Rename", "axon_" + IJ.pad((i+1),4));
	// 	roiManager("Set Color", _AXON_ROI_COLOR);
	// 	roiManager("Set Line Width", _AXON_ROI_WIDTH);
	// 	roiManager("Update");
	// }

	//Array.print(areas);
}

function SetZoneAndScale() {
	// Clear old roi or selection and make a working copy of the image
	dir = getInfo("image.directory");
	file = getInfo("image.filename");
	filename = substring(file, 0, indexOf(file, "."));
	// roiManager("reset");
	run("Clear Results");
	run("Select None");
	mouseID = getString("Enter the mouse ID", mouseID);
	setTool("line");
	waitForUser("Trace the scale... Click OK when done");
	run("Measure");
	scale_pixels = getResult("Length");
	run("Clear Results");
	setTool("polygone");
	waitForUser("Trace the zone... Click OK when done");
	// run("Make Inverse");
	// setColor("white");
	// fill();
	// run("Make Inverse");
	run("Measure");
	roi_area = getResult("Area");
	if(selectionType == 2){
		run("Crop");
	}
	roi_width = getWidth();
	roi_height = getHeight();

}

function prepareImage() {
	//showMessageWithCancel(dir + filename + ".zip");

	// Clear old roi or selection and make a working copy of the image
	roiManager("reset");
	run("Clear Results");
	run("Select None");
	run("Duplicate...", " ");

	//run("8-bit");
	run("Duplicate...", " ");

	run("Set Measurements...", "area standard center shape bounding integrated display redirect=None decimal=3");

	//run("Unsharp Mask...", "radius=20 mask=0.50");
  run("Enhance Contrast...", "saturated="+SATURATED_PIXELS);
	run("Median...", "radius="+RADIUS_MEDIAN_FILTER);
  run("8-bit");
	setAutoThreshold(THRESHOLD_METHOD + " dark");
	run("Convert to Mask");
}

function findAxons() {
	run("Analyze Particles...", "size=0-Infinity add");

	roiManager("Show None");
	roiManager("Show All");

	// Measuring all particles
	roiManager("Measure");

	// Fill black small particles and delete corresponding roi
	indices = newArray();
	for(i=0; i<nResults; i++) {
		area = getResult("Area", i);
		circularity = getResult("Circ.", i);
		solidity = getResult("Solidity", i);
		if (area<MIN_SIZE || circularity<MIN_CIRCULARITY || solidity<MIN_SOLIDITY) {
			indices = Array.concat(indices, i);
			if(area<MIN_SIZE){
				roiManager("select", i);
				fillBlack();
			}
		}
	}
	roiManager("Select", indices);
	roiManager("Delete");
	run("Clear Results");

	// Measure only axons
	roiManager("Measure");

	// Identify center of axons
	n_axons = roiManager("count");
	xcenters = newArray(n_axons);
	ycenters = newArray(n_axons);
	areas = newArray(n_axons);

	for(i=0;i<n_axons;i++) {
		roiManager("Select", i);
		if(DO_CONVEXHULL == 1) {
			run("Convex Hull");
		}
		run("Interpolate", "interval=1");
		xcenters[i] = getResult("XM", i);
		ycenters[i] = getResult("YM", i);
		areas[i] = getResult("Area", i);
		roiManager("Rename", "axon_" + IJ.pad((i+1),4));
		roiManager("Set Color", _AXON_ROI_COLOR);
		roiManager("Set Line Width", _AXON_ROI_WIDTH);
		fillBlack();
		//smoothSelection();
		roiManager("Update");
	}
	close();
	roiManager("Show None");
	roiManager("Show All with labels");
	selectWindow(title_summary);
	saveAs("results", dir + title_summary);
}

function openOutputFiles() {

	if (File.exists(datapath + title_details) && !isOpen(title_details)) {
		print("ouverture fichier existant"+datapath+title_details);
		run("Table... ", "open=["+datapath+title_details+"]");
	} else {
		if (!isOpen(title_details)) {
			print("création nouveau fichier"+handle_details);
			run("New... ", "name="+title_details+" width=400 height=600");
			print(handle_details, "\\Headings:MouseID\tn\timage\taxon\tarea_axon\tmean_thickness\tsd_thickness\tmean_R\tsd_R\tmean_r\tsd_r\tmean_g_ratio\tsd_g_ratio\taxon_status\tmito_status");
		}
	}

	if (File.exists(datapath + title_summary) && !isOpen(title_summary)) {
		run("Table... ", "open=["+datapath+title_summary+"]");
	} else {
		if (!isOpen(title_summary)) {
			run("New... ", "name="+title_summary+" width=400 height=600");
			print(handle_summary, "\\Headings:mouseID\timage\timage_area\taxon_number\taxon_area_mean\taxon_area_sd\tscale_mu\tscale_pixels");
		}
	}
	//selectWindow(title);
}

function measureMyelin() {
	n_axons = roiManager("count"); //to_analyse.length;
	roiManager("Deselect");
	run("Select None");
	run("Clear Results");
	for(a=0;a<n_axons;a++){
		i = a; //to_analyse[a];
		setTool("multipoint");
		roiManager("Select", i);
		name = Roi.getName;
		axon_status = Roi.getProperty('axon_status');
		mito_status = Roi.getProperty('mito_status');
		//run("Interpolate", "interval=1");
		getSelectionCoordinates(xspline, yspline);
		if(_ON_BORDER_CHECK && isOnBorder(xspline, yspline)){
			showMessageWithCancel(i+1, "on border");
		} else {
      		//run("Set... ", "x=" + currentx + " y=" + currenty + " width=" + currentwidth + " height="+ currentheight);
			run("To Selection");
			run("Out [-]");
      		run("Out [-]");
      		run("Out [-]");
			ii=i+1;
			waitForUser("Please select outer points for axon " + ii + ". Click OK when done");
			run("Measure");
			n = getValue("results.count");
			//TODO for each row in results table, convert x,y columns to rectangle ROIs like you did above
			//run("Clear Results");
			axon_R = newArray();
			axon_r = newArray();
			g_ratio = newArray();
			thickness = newArray();
			for(j=0;j<n;j++){
				xj = getResult("X", j);
				yj = getResult("Y", j);

				if(isNaN(xj)){
				continue;
				}

				if(METHOD == "center"){
					makeLine(xcenters[i],ycenters[i],xj,yj);
					run("Interpolate", "interval=1");
					getSelectionCoordinates(x, y);
					run("Measure");
					axon_R = Array.concat(axon_R, getResult("Length", nResults-1));
					coord=getInnerPoint();
					run("Select None");
					makeLine(xcenters[i],ycenters[i],coord[0], coord[1]);
					run("Measure");
					axon_r = Array.concat(axon_r, getResult("Length", nResults-1));
					g_ratio = Array.concat(g_ratio, axon_r[j] / axon_R[j]);
					makeLine(coord[0], coord[1], xj, yj);
					run("Measure");
					thickness = Array.concat(thickness, getResult("Length", nResults-1));
				}

				if(METHOD == "tangent") {
					x1 = newArray();
					y1 = newArray();
					l = newArray();

					for(k=0; k<xspline.length; k++){
						x1i = xspline[k];
						y1i = yspline[k];
						makeLine(xj, yj, x1i, y1i);
						run("Measure");
						l = Array.concat(l, getResult("Length", nResults-1));
						x1 = Array.concat(x1, x1i);
						y1 = Array.concat(y1, y1i);
					}

					current_l = l[0];
					counter = 0;
					for(k=1; k<l.length; k++){
						if(l[k]<current_l){
							index = k;
							current_l=l[k];
						}
					}
					makeLine(xj, yj, x1[index], y1[index]);
					run("Measure");
					ti = getResult("Length", nResults-1);
					thickness = Array.concat(thickness, ti);
					//print("areas[i]" + areas[i]);
					ri = sqrt(areas[i]/PI);
					//print("ri" + ri);
					axon_r = Array.concat(axon_r, ri);
					axon_R = Array.concat(axon_R, ri+ti);
					g_ratio = Array.concat(g_ratio, ri / (ri+ti));
				}

				roiManager("add");
				newindex = roiManager("count")-1;
				roiManager("Select", newindex);
				roiManager("Rename", "axon_" + IJ.pad((i+1),4) + "_" + IJ.pad((j+1),4));
				run("Select None");
			}
			run("Clear Results");
			//roiManager("Show None");
			//roiManager("Select", currentthickness);
			//run("Measure");
			//roiManager("measure");
			//newdata = newArray(n);
			//for(j=0;j<nResults;j++){
			//	newdata[j] = getResult("Length",j);
			//}
      if(isNaN(xj)){
        continue;
      }
			Array.getStatistics(thickness, thickness_min, thickness_max, thickness_mean, thickness_stdDev);
			Array.getStatistics(axon_R, R_min, R_max, R_mean, R_stdDev);
			Array.getStatistics(axon_r, r_min, r_max, r_mean, r_stdDev);
			Array.getStatistics(g_ratio, g_ratio_min, g_ratio_max, g_ratio_mean, g_ratio_stdDev);
			print(handle_details, mouseID + "\t" + i + "\t" + file + "\t" + name + "\t" + areas[i] + "\t" + thickness_mean + "\t" + thickness_stdDev + "\t" + R_mean + "\t" + R_stdDev + "\t" + r_mean + "\t" + r_stdDev+ "\t" + g_ratio_mean + "\t" + g_ratio_stdDev + "\t" + axon_status + "\t" + mito_status);
			// print(mouseID + "\t" + i + "\t" + file + "\t" + name + "\t" + areas[i] + "\t" + thickness_mean + "\t" + thickness_stdDev + "\t" + R_mean + "\t" + R_stdDev + "\t" + r_mean + "\t" + r_stdDev+ "\t" + g_ratio_mean + "\t" + g_ratio_stdDev);
		}
	}

	Array.getStatistics(areas, min, max, mean, stdDev);
	print(handle_summary, mouseID + "\t" + 	file + "\t" + roi_area + "\t" + total_axons + "\t" + mean + "\t" + stdDev + "\t" + scale_mu +"\t" + scale_pixels);

	run("Original Scale");
	//print("chemin: " + dir + filename + ".zip");
	roiManager("save", dir + filename + ".zip");
	selectWindow(title_details);
	saveAs("results", dir + title_details);
}

function reCompute() {
	dir = getInfo("image.directory");
	file = getInfo("image.filename");
	filename = substring(file, 0, indexOf(file, "."));
	mouseID = getString("Enter the mouse ID", mouseID);
	n_axons = roiManager("count");
	roiManager("Deselect");
	run("Select None");
	run("Clear Results");
	area = 0;
  areas = newArray();
  total_axons = 0;
	for(i=0;i<n_axons;i++){
		roiManager("Select", i);
		name = Roi.getName;
		axon_status = Roi.getProperty('axon_status');
		mito_status = Roi.getProperty('mito_status');
		//print("Selection: "+name);
		axon_R = newArray();
		axon_r = newArray();
		g_ratio = newArray();
		thickness = newArray();
		if(matches(name,"axon_[0-9]{4}")){ // matching only axons
      total_axons = total_axons + 1;
			run("Measure");
			area = getResult("Area", nResults-1);
      areas = Array.concat(areas, area);
			for(j=0; j<n_axons; j++){
				roiManager("Select", j);
				sub_name = Roi.getName;
				if(matches(sub_name,name+"_.*")){
					to_measure = Array.concat(to_measure, j);
					run("Measure");
					ti = getResult("Length", nResults-1);
					thickness = Array.concat(thickness, ti);
					//print("areas[i]" + areas[i]);
					ri = sqrt(area/PI);
					//print("ri" + ri);
					axon_r = Array.concat(axon_r, ri);
					axon_R = Array.concat(axon_R, ri+ti);
					g_ratio = Array.concat(g_ratio, ri / (ri+ti));
				}
			}
			Array.getStatistics(thickness, thickness_min, thickness_max, thickness_mean, thickness_stdDev);
			Array.getStatistics(axon_R, R_min, R_max, R_mean, R_stdDev);
			Array.getStatistics(axon_r, r_min, r_max, r_mean, r_stdDev);
			Array.getStatistics(g_ratio, g_ratio_min, g_ratio_max, g_ratio_mean, g_ratio_stdDev);
			print(handle_details, mouseID + "\t" + i + "\t" + file + "\t" + name + "\t" + area + "\t" + thickness_mean + "\t" + thickness_stdDev + "\t" + R_mean + "\t" + R_stdDev + "\t" + r_mean + "\t" + r_stdDev+ "\t" + g_ratio_mean + "\t" + g_ratio_stdDev + "\t" + axon_status + "\t" + mito_status);

		}
	}
  Array.getStatistics(areas, min, max, mean, stdDev);
  print(handle_summary, mouseID + "\t" + 	file + "\t" + roi_area + "\t" + total_axons + "\t" + mean + "\t" + stdDev + "\t" + scale_mu +"\t" + scale_pixels);

}

function roiTranslate() {
	setTool("line");
	waitForUser("Trace the translation vector... Click OK when done");
	run("Measure");
	l = getResult("Length", nResults-1);
	a = getResult("Angle", nResults-1);
	dx = l*cos(a*PI/180);
	dy = l*sin(a*PI/180);
	roiManager("translate", dx, -dy);
}

function singleMyelin(){
	if(matches(selectionName, "axon_[0-9]{4}") == false) exit("No axon selected");
	// run("Measure");
	area = getValue("Area");
	setTool("multipoint");
	name = Roi.getName;
	axon_status = Roi.getProperty('axon_status');
	mito_status = Roi.getProperty('mito_status');
	ii = split(name,"_");
	axon_number = parseInt(ii[1]);
	i = roiManager("index");
	getSelectionCoordinates(xspline, yspline);
	run("Clear Results");
	run("To Selection");
	run("Out [-]");
	waitForUser("Please select outer points for axon " + axon_number + ". Click OK when done");
	run("Measure");
	n = getValue("results.count");
	//TODO for each row in results table, convert x,y columns to rectangle ROIs like you did above
	//run("Clear Results");
	axon_R = newArray();
	axon_r = newArray();
	g_ratio = newArray();
	thickness = newArray();
	for(j=0;j<n;j++){
		xj = getResult("X", j);
		yj = getResult("Y", j);

		if(METHOD == "tangent") {
			x1 = newArray();
			y1 = newArray();
			l = newArray();

			for(k=0; k<xspline.length; k++){
				x1i = xspline[k];
				y1i = yspline[k];
				makeLine(xj, yj, x1i, y1i);
				run("Measure");
				l = Array.concat(l, getResult("Length", nResults-1));
				x1 = Array.concat(x1, x1i);
				y1 = Array.concat(y1, y1i);
			}

			current_l = l[0];
			counter = 0;
			for(k=1; k<l.length; k++){
				if(l[k]<current_l){
					index = k;
					current_l=l[k];
				}
			}
			makeLine(xj, yj, x1[index], y1[index]);
			run("Measure");
			ti = getResult("Length", nResults-1);
			thickness = Array.concat(thickness, ti);
			//print("areas[i]" + areas[i]);
			ri = sqrt(area/PI);
			//print("ri" + ri);
			axon_r = Array.concat(axon_r, ri);
			axon_R = Array.concat(axon_R, ri+ti);
			g_ratio = Array.concat(g_ratio, ri / (ri+ti));
		}

		roiManager("add");
		newindex = roiManager("count")-1;
		roiManager("Select", newindex);
		roiManager("Rename", "axon_" + IJ.pad((axon_number),4) + "_" + IJ.pad((j+1),4));
		run("Select None");
	}
	run("Clear Results");
	//roiManager("Show None");
	//roiManager("Select", currentthickness);
	//run("Measure");
	//roiManager("measure");
	//newdata = newArray(n);
	//for(j=0;j<nResults;j++){
	//	newdata[j] = getResult("Length",j);
	//}
	Array.getStatistics(thickness, thickness_min, thickness_max, thickness_mean, thickness_stdDev);
	Array.getStatistics(axon_R, R_min, R_max, R_mean, R_stdDev);
	Array.getStatistics(axon_r, r_min, r_max, r_mean, r_stdDev);
	Array.getStatistics(g_ratio, g_ratio_min, g_ratio_max, g_ratio_mean, g_ratio_stdDev);
	print(handle_details, mouseID + "\t" + i + "\t" + file + "\t" + name + "\t" + area + "\t" + thickness_mean + "\t" + thickness_stdDev + "\t" + R_mean + "\t" + R_stdDev + "\t" + r_mean + "\t" + r_stdDev+ "\t" + g_ratio_mean + "\t" + g_ratio_stdDev + "\t" + axon_status + "\t" + mito_status);

}

/*

angles = newArray(24);
for(i=0;i<angles.length;i++){
	angles[i]=i*PI/12;
}

run("Select None");
for(i=0;i<n_axons;i++) {
	roiManager("select", i);
	run("Interpolate", "interval=1");
	getSelectionCoordinates(xspline, yspline);
	run("Select None");
	//getSelectionBounds(x, y, width, height);
	//run("Select None");
	//x = x + (width/2);
	//y = y + (height/2);
	x1 = getResult("XM", i);
	y1 = getResult("YM", i);
	l = getResult("Width", i) * 1.5;
	xpoints=newArray(angles.length);
	ypoints=newArray(angles.length);
	x1points=newArray(angles.length);
	y1points=newArray(angles.length);
	for(j=0;j<angles.length;j++){
		x2 = x1 + (l * cos(angles[j]));
		y2 = y1 + (l * sin(angles[j]));
		makeLine(x1,y1,x2,y2);
		run("Interpolate", "interval=1");
		getSelectionCoordinates(x, y);
		coord1=getInnerPoint();
		coord=getOuterPoint();
		xpoints[j]=coord[0];
		ypoints[j]=coord[1];
		run("Select None");
		makeLine(coord1[0], coord1[1], coord[0], coord[1]);
		roiManager("add");
	}
	makeSelection("freeline red", xpoints, ypoints);
	roiManager("add");
	//print(x,y,x1,y1);
}

*/

function isOnBorder(x, y){
	for(i=0; i<x.length; i++){
		if(x[i] < 1 || x[i] >= roi_width-1 || y[i] < 1 || y[i] >= roi_height-1){
			return true
		}
	}
	return false
}

function smoothSelection() {
	if (selectionType==-1) return;
	run("Convex Hull");
	run("Interpolate", "interval=1 smooth adjust");
}

function fillBlack() {
	setColor("black");
	fill();
}

function getInnerPoint() {
	for(i=0;i<xspline.length;i++){
			for(j=0;j<x.length;j++){
				if(round(xspline[i]) == round(x[j])){
					if(round(yspline[i]) == round(y[j])){
						return newArray(xspline[i],yspline[i]);
					}
				}
			}

	}
}

function getOuterPoint() {
	ival=0;
	i=1;
	j=0;
	while(ival==0) {
		if(x[i]<=0 || y[i]<=0 || i >= x.length-1){
			makePoint(x[i-1], y[i-1], "large red add");
			return newArray(x[i-1], y[i-1]);
			ival=255;
		} else {
			ix=round(x[i]);
			iy=round(y[i]);
			ival=getPixel(ix,iy);
			if(ival>0){
				makePoint(ix, iy, "large red add");
				//print(i, ix, iy, getPixel(ix,iy));
				return newArray(ix,iy);
			}
			i++;
		}
	}
}

function Union(array1, array2) {
	unionA = newArray();
	for (i=0; i<array1.length; i++) {
		for (j=0; j<array2.length; j++) {
			if (array1[i] == array2[j]){
				unionA = Array.concat(unionA, array1[i]);
			}
		}
	}
	return unionA;
}

function setDataDirectory() {
	datapath = getDirectory("Select data directory");
}
