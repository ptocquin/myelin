var	title_details = "axon_analysis_details.csv";
var	title_summary = "axon_analysis_summary.csv";
var	title_anormal = "anormal_axon_analysis.csv";
var	handle_anormal = "[" + title_anormal + "]";
var	handle_details = "[" + title_details + "]";
var	handle_summary = "[" + title_summary + "]";

var dir;
var mouseID;

macro 'Recompute ROI Action Tool (f1) - C000T4b12r' {
	dir = getDirectory("Choose a Directory ");
    mouseID = getString("Enter the mouse ID for" +dir, mouseID);
    count = 1;
    processFiles(dir);
}

macro 'Recompute ROI [f1]' {
	dir = getDirectory("Choose a Directory ");
    mouseID = getString("Enter the mouse ID for" +dir, mouseID);
    count = 1;
    processFiles(dir);
}

function processFiles(dir) {
    list = getFileList(dir);
    for (i=0; i<list.length; i++) {
        //if (endsWith(list[i], "/"))
        if (list[i].matches(".*\.(JPG|jpg)")) {
            //listFiles(""+dir+list[i]);
            roiFile = File.getNameWithoutExtension(list[i]) + ".zip";
            if (File.exists(dir + roiFile)) {
                open(dir + list[i]);
                print((count++) + ": " + dir + list[i]);
                open(dir + roiFile);
                summary();
                roiManager("reset");
                close("*");
            }
        } else {
        continue;
        }
    }
    selectWindow(title_anormal);
    saveAs("results", getDir("home") + title_anormal);
}

function summary() {
    if (!isOpen(title_anormal)) {
    	run("New... ", "name="+title_anormal+" width=400 height=600");
    	print(handle_anormal, "\\Headings:MouseID\tn\timage\taxon\tarea_axon\tmean_thickness\tsd_thickness\tmean_R\tsd_R\tmean_r\tsd_r\tmean_g_ratio\tsd_g_ratio\tstatus");
    }
    
    total = roiManager("count");
    roiManager("Deselect");
    run("Select None");
    run("Clear Results");
    areas = newArray();
    total_axons = 0;
    for(i=0;i<total;i++) {
        roiManager("Select", i);
        name = Roi.getName;
		//print("Selection: "+name);
		axon_R = newArray();
		axon_r = newArray();
		g_ratio = newArray();
		thickness = newArray();
		//status = newArray();
        if(matches(name,"axon_[0-9]{4}")){ // matching only axons
            total_axons = total_axons + 1;
			run("Measure");
			area = getResult("Area", nResults-1);
            areas = Array.concat(areas, area);
            if(Roi.getGroup == 0) status = "undefined";
            if(Roi.getGroup == 2) status = "anormal";
            if(Roi.getGroup == 1) status = "normal";
            
            //status = Array.concat(status, s);
			for(j=0; j<total; j++){
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
            print(handle_anormal, mouseID + "\t" + i + "\t" + roiFile + "\t" + name + "\t" + area + "\t" + thickness_mean + "\t" + thickness_stdDev + "\t" + R_mean + "\t" + R_stdDev + "\t" + r_mean + "\t" + r_stdDev+ "\t" + g_ratio_mean + "\t" + g_ratio_stdDev + "\t" + status );
        }       
    }
}
