/***
* Name: Regicid REGIonal CIty District
* Author: Arno
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Regicid

/* Insert your model definition here */

import "common model.gaml"
global{
	int nbCellsWidth<-10;
	int nbCellsHeight<-10;
	float macroCellWidth<-100#km;
	float macroCellHeight<-100#km;
	
	int global_people_size <-100;
	cells currentMacro;
	cells currentMeso;
	
	macroCell currentMacro_tmp;
	mesoCell currentMeso_tmp;
	
	list<string> macroCellsTypes <- ["City", "Village", "Park","Lake"];
	map<string, rgb> macroCellsColors <- ["City"::#gamaorange, "Village"::#gamared, "Park"::#green,"Lake"::#blue];
	
	list<string> mesoCellsTypes <- ["Residential", "Commercial", "Industrial", "Educational", "Park","Lake"];
	map<string, rgb> mesoCellsColors <- ["Residential"::#gamared, "Commercial"::#gamablue, "Industrial"::#gamaorange, "Educational"::#white, "Park"::#green,"Lake"::#blue];
	
	list<string> microCellsTypes <- ["Residential", "Commercial", "Industrial", "Educational", "Park","Lake"];
	map<string, rgb> microCellsColors <- ["Residential"::#gamared, "Commercial"::#gamablue, "Industrial"::#gamaorange, "Educational"::#white, "Park"::#green,"Lake"::#blue];
	
	map<string, list<int>> macroCellsProportions <- ["City"::[30,30,30,10,10,5], "Village"::[10,7,5,5,50,10], "Park"::[3,3,0,0,85,10],"Lake"::[5,0,0,0,5,100]];
	map<string, list<int>> mesoCellsProportions <- ["Residential"::[70,5,0,5,20,5], "Commercial"::[10,80,0,5,20,0], "Industrial"::[5,5,90,0,0,0], "Educational"::[10,10,0,70,25,0], "Park"::[10,5,0,0,70,20],"Lake"::[5,5,0,0,5,80]];
	
	// for the RNG
	float a <- 25214903917.0;
	float c <- 11.0;
	float m <- 2^48;
	geometry shape <-rectangle(nbCellsWidth*macroCellWidth, nbCellsHeight*macroCellHeight);
	file imageRaster <- file('./../images/Kent_Sketches.png');
	
	init{
		//do createRandomGrid;
		do load_macro_grid("./../includes/Macro_Grid_10_10.csv");
		currentMacro<- one_of(macroCell);
		currentMeso<- one_of(macroCell);
		do load_profiles;
	}
	
	action load_macro_grid(string path_to_file) {
		file my_csv_file <- csv_file(path_to_file,",");
		matrix data <- matrix(my_csv_file);
		loop i from: 0 to: data.rows - 1 {
			loop j from: 0 to: data.columns - 1 {
				create macroCell{
					width<-macroCellWidth;
					height<-macroCellHeight;
					location<-{width*i+width/2,height*j+height/2};
					seed <- float(rnd(1000000));
					type <- string(data[i, j]);
					density<-rnd(10);
				}
			}
		}	
	}
	
	
	action createRandomGrid {
		loop i from: 0 to: nbCellsWidth-1{
			loop j from:0 to:nbCellsHeight-1{
				create macroCell{
					width<-macroCellWidth;
					height<-macroCellHeight;
					location<-{width*i+width/2,height*j+height/2};
					seed <- float(rnd(1000000));
					type <- one_of(macroCellsTypes);
					density<-rnd(10);
				}
			}
		}
	}
	
	reflex updateMacroMeso {
		if (currentMacro != currentMacro_tmp) {
			ask currentMacro_tmp{
				do generateMeso;
			}
		}
		if (currentMeso != currentMeso_tmp) {
			ask currentMeso_tmp{
				do generateMicro;
			}
		}
	}
	action activateMacro {
		currentMacro_tmp <- (macroCell closest_to  #user_location);
		
	}	
	
	action activateMeso {
		currentMeso_tmp <- (mesoCell closest_to #user_location);
		
	}	
	
}

species cells parent: poi{
	int level;
	int index;
	string type; 
	float seed;
	float width;
	float height;
	int density;
	cells currentSelectedCell;
	changeLog log;
	cells parentCell;
	map<list<int>,string> changeLog2 <- [];
	
	//for RNG
	float value;

	int rand(int n){
		value <- a*value+c;
		value <- value - floor(value/m)*m;
		return floor(value/m * n);
	}
	
	action reset_RNG{
		value <- seed;
	}

	action populateParentChangeLog{
		if parentCell != nil{
			if parentCell.log = nil{
				create changeLog{
					myself.parentCell.log <- self;
				}
			}
			add log at: index to: parentCell.log.childrenLogs; 
			ask parentCell {
				do populateParentChangeLog;
			}
		}
	}
	
	action addToLog(string s){
		if log = nil{
			create changeLog{
				myself.log <- self;
			}
		}
		add s at: index to: log.mainLog;
		do populateParentChangeLog;
		

	}
	
	
	action clean{
		if log != nil and length(log.mainLog) = 0 and length(log.childrenLogs) = 0 {
			ask log {
				do die;
			}
		}
		do die;
	}
	
	aspect macro{
		draw rectangle(width,height) color: macroCellsColors[type] ;
	}
	
	aspect meso{
		draw rectangle(width,height) color:mesoCellsColors[type];
	}
	
	aspect micro{
		draw rectangle(width,height) color: microCellsColors[type];
	}
	
	aspect macroTable{
		draw rectangle(width,height) depth:density color:macroCellsColors[type] border:macroCellsColors[type]+25;
	}
	
	aspect mesoTable{
		draw rectangle(width*nbCellsWidth,height*nbCellsHeight) depth:density color:mesoCellsColors[type] border:mesoCellsColors[type]+25 at:{world.shape.width*2+(location.x-currentMacro.location.x)*nbCellsWidth,world.shape.height/2+(location.y-currentMacro.location.y)*nbCellsHeight};
	}

	aspect microTable{
		draw rectangle(width*nbCellsWidth*nbCellsWidth,height*nbCellsHeight*nbCellsHeight) depth:density color:microCellsColors[type] border:microCellsColors[type]-25 at:{world.shape.width*3.5+(location.x-currentMeso.location.x)*nbCellsWidth*nbCellsWidth,world.shape.height/2+(location.y-currentMeso.location.y)*nbCellsHeight*nbCellsHeight};
	}
	
}

species connection{
	cells source;
	cells destination;
}

species macroCell parent: cells{
	int level <- 0;
	user_command "generate Meso"action: generateMeso;
	user_command "save State"action: saveState;
	user_command "City"action: modifyToCity;
	user_command "Village"action: modifyToVillage;
	user_command "Park"action: modifyToPark;
	user_command "Lake"action: modifyToLake;
	int index -> int(self) - int(first(macroCell));
	
	action generateMeso{
		currentMacro<-self;
		ask mesoCell{
			do clean;
		}
		ask microCell{
			do clean;
		}
		do reset_RNG;
		loop i from: 0 to: nbCellsWidth-1{
			loop j from:0 to:nbCellsHeight-1{
				create mesoCell{
					width<-myself.width/nbCellsWidth;
					height<-myself.height/nbCellsWidth;
					location<-{myself.location.x-myself.width/2+width*i+width/2,myself.location.y-myself.height/2+height*j+height/2};
					type <- myself.affectMesoCellType();
					parentCell <- myself;
					seed <- float(myself.rand(1000000));
					density<-rnd(10);
				}
			}
		}

		do applyChanges;
	}
	
	action applyChanges{
		if log != nil{
			loop k over: log.mainLog.keys{
				mesoCell cell <- first(mesoCell where (int(each)-int(first(mesoCell))= k));
				cell.type <- log.mainLog[k];
			}
			loop k over: log.childrenLogs.keys{
				mesoCell cell <- first(mesoCell where (int(each)-int(first(mesoCell))= k));
				cell.log <- log.childrenLogs[k];
			}
		}
	}
	
	string affectMesoCellType {
		int total <- sum(macroCellsProportions[type]);
		int ind <- rand(total);
		int cumul <- macroCellsProportions[type][0];
		int currentType <- 0;
		loop  while: (ind >= cumul) {
			currentType <- currentType + 1;
			cumul <- cumul + macroCellsProportions[type][currentType]; 
		}
		return mesoCellsTypes[currentType];
	}
	
	
	action saveState{
		list<int> newProportions <- [];
		loop mesoType over: mesoCellsTypes{
			newProportions << (mesoCell count (each.type = mesoType));
		}
		put newProportions at: currentMacro.type in: macroCellsProportions;
	}
	
	action modifyToCity{
		type<-macroCellsTypes[0];
		do generateMeso;
	}
	action modifyToVillage{
		type<-macroCellsTypes[1];
		do generateMeso;
	}
	action modifyToPark{
		type<-macroCellsTypes[2];
		do generateMeso;
	}
	action modifyToLake{
		type<-macroCellsTypes[3];
		do generateMeso;
	}
}

species mesoCell parent:cells{
	int level <- 1;
	int index -> int(self) - int(first(mesoCell));
	
	user_command "generate Micro"action: generateMicro;
	user_command "save Macro State"action: saveMacroState;
	user_command "Residential"action: modifyToResidential;
	user_command "Commercial"action: modifyToCommercial;
	user_command "Industrial"action: modifyToIndustrial;
	user_command "Educational"action: modifyToEducational;
	user_command "Park"action: modifyToPark;
	user_command "Lake"action: modifyToLake;
	
	user_command "Local Residential"action: localModifyToResidential;
	user_command "Local Commercial"action: localModifyToCommercial;
	user_command "Local Industrial"action: localModifyToIndustrial;
	user_command "Local Educational"action: localModifyToEducational;
	user_command "Local Park"action: localModifyToPark;
	user_command "Local Lake"action: localModifyToLake;
	
	macroCell parentCell;
	
	action generateMicro{
		block_size <- min([width/nbCellsWidth,height/nbCellsHeight]);
		
		currentMeso<-self;
		ask microCell{
			do clean;
		}
		ask people {do die;}
		ask road {do die;}
		do reset_RNG;
		loop i from: 0 to: nbCellsWidth-1{
			loop j from:0 to:nbCellsHeight-1{
				create microCell{
					width<-myself.width/nbCellsWidth;
					height<-myself.height/nbCellsHeight;
					location<-{myself.location.x-myself.width/2+width*i+width/2,myself.location.y-myself.height/2+height*j+height/2};
					type <- myself.affectMicroCellType();
					parentCell <- myself;	
					seed <- float(myself.rand(1000000));
					density<-rnd(10);
					create people number: density with: [location::location]{
						origin <- myself;
						list_of_people << self;
						do reinit_destination;
						map<profile, float> prof_pro <- proportions_per_bd_type[one_of(proportions_per_bd_type.keys)];
						my_profile <- prof_pro.keys[rnd_choice(prof_pro.values)];
			
					}
				}
			}
		}
		do generate_road;
		do applyChanges;
		
		
	}

	
	action generate_road {
		geometry s <- rectangle(width,height);
		list<geometry> lines;
		float w <- width/nbCellsWidth;
		float h <- height/nbCellsHeight;
		float min_x <- s.points min_of each.x;
		float min_y <- s.points min_of each.y;
		loop i from: 0 to: nbCellsWidth {
				lines << line([{i*w+ min_x,min_y}, {i*w+min_x,height+min_y}]);
			}
			loop i from: 0 to: nbCellsHeight {
				lines << line([{min_x, i*h+min_y}, {width+ min_x,i*h+min_y}]);
			}
			create road from: split_lines(lines) {
				create road with: [shape:: line(reverse(shape.points))];
			}
		ask world {do update_graphs;}
		
		
	}
	action applyChanges{
		if log != nil{
			loop k over: log.mainLog.keys{
				microCell cell <- first(microCell where (int(each)-int(first(microCell))= k));
				cell.type <- log.mainLog[k];
			}
		}
	}
	
	action saveMacroState{
		ask parentCell{
			do saveState;
		}
	}
	action saveState{
		list<int> newProportions <- [];
		loop microType over: microCellsTypes{
			newProportions << (microCell count (each.type = microType));
		}
		put newProportions at: currentMeso.type in: mesoCellsProportions;
	}
	action modifyToResidential{
		type<-mesoCellsTypes[0];
		do generateMicro;
	}
	action modifyToCommercial{
		type<-mesoCellsTypes[1];
		do generateMicro;
	}
	action modifyToIndustrial{
		type<-mesoCellsTypes[2];
		do generateMicro;
	}
	action modifyToEducational{
		type<-mesoCellsTypes[3];
		do generateMicro;
	}
	action modifyToPark{
		type<-mesoCellsTypes[4];
		do generateMicro;
	}
	action modifyToLake{
		type<-mesoCellsTypes[5];
		do generateMicro;
	}
	
	action localModifyToResidential{
		type<-mesoCellsTypes[0];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToCommercial{
		type<-mesoCellsTypes[1];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToIndustrial{
		type<-mesoCellsTypes[2];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToEducational{
		type<-mesoCellsTypes[3];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToPark{
		type<-mesoCellsTypes[4];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToLake{
		type<-mesoCellsTypes[5];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	
	string affectMicroCellType {
		int total <- sum(mesoCellsProportions[type]);
		int ind <- rand(total);
		int cumul <- mesoCellsProportions[type][0];
		int currentType <- 0;
		loop  while: (ind >= cumul) {
			currentType <- currentType + 1;
			cumul <- cumul + mesoCellsProportions[type][currentType]; 
		}
		return microCellsTypes[currentType];
	}
}

species microCell parent:cells{
	int level <- 3;
	int index -> int(self) - int(first(microCell));
	
	user_command "save Meso State"action: saveMesoState;
	user_command "Residential"action: modifyToResidential;
	user_command "Commercial"action: modifyToCommercial;
	user_command "Industrial"action: modifyToIndustrial;
	user_command "Educational"action: modifyToEducational;
	user_command "Park"action: modifyToPark;
	user_command "Lake"action: modifyToLake;
	
	user_command "Local Residential"action: localModifyToResidential;
	user_command "Local Commercial"action: localModifyToCommercial;
	user_command "Local Industrial"action: localModifyToIndustrial;
	user_command "Local Educational"action: localModifyToEducational;
	user_command "Local Park"action: localModifyToPark;
	user_command "Local Lake"action: localModifyToLake;
	
	mesoCell parentCell;
	
	action initialize {
		bounds <- rectangle(width,height) ;
	}
	action saveMesoState{
		ask parentCell{
			do saveState;
		}
	}
	action modifyToResidential{
		type<-microCellsTypes[0];
	}
	action modifyToCommercial{
		type<-microCellsTypes[1];
	}
	action modifyToIndustrial{
		type<-microCellsTypes[2];
	}
	action modifyToEducational{
		type<-microCellsTypes[3];
	}
	action modifyToPark{
		type<-microCellsTypes[4];
	}
	action modifyToLake{
		type<-microCellsTypes[5];
	}
	
	action localModifyToResidential{
		type<-microCellsTypes[0];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToCommercial{
		type<-microCellsTypes[1];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToIndustrial{
		type<-microCellsTypes[2];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToEducational{
		type<-microCellsTypes[3];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToPark{
		type<-microCellsTypes[4];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToLake{
		type<-microCellsTypes[5];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	
}

species changeLog{
	map<int, string> mainLog <- [];
	map<int, changeLog> childrenLogs <- [];
//	cells c;
}

species macroConnection parent: connection{
	
}

species mesoConnection parent: connection{
	
}

species microConnection parent: connection{
	
}

species people parent: basic_people skills: [moving]{
	action reinit_destination {
		dest <-one_of(microCell);
		target <- nil;
	}
}
experiment REGICID autorun: true{
	float minimum_cycle_duration <- 0.05;
	output{

		layout vertical([horizontal([0::3863,horizontal([1::5000,2::5000])::6137])::3362,3::6638])  ;
		//editors: false toolbars: false tabs: false parameters: false consoles: false navigator: false controls: false tray: false;
		

		display macro type:opengl draw_env:true{
			species macroCell aspect:macro;
			event mouse_down action: activateMacro; 
		}
		display meso type:opengl draw_env:false camera_pos: {currentMacro.location.x, currentMacro.location.y, world.shape.width/(nbCellsWidth*0.8)} camera_look_pos:  {currentMacro.location.x, currentMacro.location.y, 0} camera_up_vector: {0.0, 1.0, 0.0}{
			species mesoCell aspect:meso;
			event mouse_down action: activateMeso; 			
		}

		display micro type:opengl  draw_env:false z_near: world.shape.width / 1000  camera_pos: {currentMeso.location.x, currentMeso.location.y, world.shape.width/((nbCellsWidth*0.8)*(nbCellsWidth*0.8))} camera_look_pos:  {currentMeso.location.x, currentMeso.location.y, 0} camera_up_vector: {0.0, 1.0, 0.0}{
			species microCell aspect:micro;
			species road ;
			species people;
			 
		}
		
		display table type:opengl background:#white draw_env:true camera_pos: {1848.6801 * 1000,2083.7744 * 1000,2369.1066 * 1000} camera_look_pos: {1848.6801 * 1000,547.195 * 1000,3.0723 * 1000} camera_up_vector: {0.0,0.8387,0.5447}
		{
			species macroCell aspect:macroTable;
			species mesoCell aspect:mesoTable;
			species microCell aspect:microTable;
			graphics 'table'{
				draw box(nbCellsWidth*macroCellWidth,nbCellsHeight*macroCellHeight,world.shape.width*0.25) color:#black at:{world.shape.width/2,world.shape.height/2,-world.shape.width*0.26} empty:true;
				draw box(nbCellsWidth*macroCellWidth,nbCellsHeight*macroCellHeight,world.shape.width*0.25) color:#black at:{world.shape.width*2,world.shape.height/2,-world.shape.width*0.26} empty:true;
				draw box(nbCellsWidth*macroCellWidth,nbCellsHeight*macroCellHeight,world.shape.width*0.25) color:#black at:{world.shape.width*3.5,world.shape.height/2,-world.shape.width*0.26} empty:true;
			}
			graphics "text" {
				draw imageRaster size: 500 #px at: {world.shape.width, -world.shape.width};
			}
		}
		
		
		
	}
	
}