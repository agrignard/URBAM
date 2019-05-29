/***
* Name: Regicid REGIonal CIty District
* Author: Arno
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Regicid

/* Insert your model definition here */

global{
	int nbCells<-10;
	cells currentMacro;
	cells currentMeso;
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
	
	
	init{
		do createRandomGrid;
		//do load_macro_grid("./../includes/Macro_Grid.csv");
		currentMacro<- one_of(macroCell);
		currentMeso<- one_of(macroCell);
	}
	
	action load_macro_grid(string path_to_file) {
		file my_csv_file <- csv_file(path_to_file,",");
		matrix data <- matrix(my_csv_file);
		loop i from: 0 to: data.rows - 1 {
			loop j from: 0 to: data.columns - 1 {
					create macroCell{
					size<-world.shape.width/nbCells;
					location<-{size*i+size/2,size*j+size/2};
					seed <- float(rnd(1000000));
					type <- string(data[i, j]);
					density<-rnd(10);
				}
			}
		}
	}
	
	action createRandomGrid {
		loop i from: 0 to: nbCells-1{
			loop j from:0 to:nbCells-1{
				create macroCell{
					size<-world.shape.width/nbCells;
					location<-{size*i+size/2,size*j+size/2};
					seed <- float(rnd(1000000));
					type <- one_of(macroCellsTypes);
					density<-rnd(10);
				}
			}
		}
	}
	
	
	action activateMacro {
		macroCell cell <- first(macroCell closest_to (circle(1) at_location #user_location));
		ask cell {do generateMeso;}
	}	
	
	action activateMeso {
		mesoCell cell <- first(mesoCell closest_to (circle(1) at_location #user_location));
		ask cell {do generateMicro;}
	}	
	
}

species cells{
	string type; 
	float seed;
	float size;
	int density;
	cells currentSelectedCell;
	list<float> seedList;
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
	
	aspect macro{
		draw square(size) color: macroCellsColors[type] border:#black;
	}
	
	aspect meso{
		draw square(size) color:mesoCellsColors[type] border:#black;
	}
	
	aspect micro{
		draw square(size) color: microCellsColors[type] border:#black;
	}
	
	aspect mesoTable{
		draw square(size*nbCells) depth:density color:mesoCellsColors[type] border:mesoCellsColors[type]+25 at:{175+(location.x-currentMacro.location.x)*nbCells,world.shape.height/2+(location.y-currentMacro.location.y)*nbCells};
	}

	aspect microTable{
		draw square(size*nbCells*nbCells) depth:density color:microCellsColors[type] border:microCellsColors[type]-25 at:{300+(location.x-currentMeso.location.x)*nbCells*nbCells,world.shape.height/2+(location.y-currentMeso.location.y)*nbCells*nbCells};
	}
	
}

species connection{
	cells source;
	cells destination;
}

species macroCell parent: cells{
	user_command "generate Meso"action: generateMeso;
	user_command "save State"action: saveState;
	user_command "City"action: modifyToCity;
	user_command "Village"action: modifyToVillage;
	user_command "Park"action: modifyToPark;
	user_command "Lake"action: modifyToLake;
	
	action generateMeso{
		currentMacro<-self;
		ask mesoCell{
			do die;
		}
		ask microCell{
			do die;
		}
		do reset_RNG;
		loop i from: 0 to: nbCells-1{
			loop j from:0 to:nbCells-1{
				create mesoCell{
					size<-myself.size/nbCells;
					location<-{myself.location.x-myself.size/2+size*i+size/2,myself.location.y-myself.size/2+size*j+size/2};
					type <- myself.affectMesoCellType();
					seed <- float(myself.rand(1000000));
					density<-rnd(10);
				}
			}
		}
		ask first(mesoCell){
			do generateMicro;
		}
	}
	
	string affectMesoCellType {
		int total <- sum(macroCellsProportions[type]);
		int index <- rand(total);
		int cumul <- macroCellsProportions[type][0];
		int currentType <- 0;
		loop  while: (index>cumul) {
			currentType <- currentType + 1;
			cumul <- cumul + macroCellsProportions[type][currentType]; 
		}
		return mesoCellsTypes[currentType];
	}
	
	action saveState{
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
	
	user_command "generate Micro"action: generateMicro;
	user_command "save Macro State"action: saveMacroState;
	user_command "Residential"action: modifyToResidential;
	user_command "Commercial"action: modifyToCommercial;
	user_command "Industrial"action: modifyToIndustrial;
	user_command "Educational"action: modifyToEducational;
	user_command "Park"action: modifyToPark;
	user_command "Lake"action: modifyToLake;
	action generateMicro{
		currentMeso<-self;
		ask microCell{
			do die;
		}
		do reset_RNG;
		loop i from: 0 to: nbCells-1{
			loop j from:0 to:nbCells-1{
				create microCell{
					size<-myself.size/nbCells;
					location<-{myself.location.x-myself.size/2+size*i+size/2,myself.location.y-myself.size/2+size*j+size/2};
					//type <- microCellsTypes[myself.rand(length(microCellsTypes))];
					type <- myself.affectMicroCellType();
					seed <- float(myself.rand(1000000));
					density<-rnd(10);
				}
			}
		}	
	}
	
	action saveMacroState{
		ask macroCell(currentMacro){
			do saveState;
		}
	}
	action saveState{
		
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
	
	string affectMicroCellType {
		int total <- sum(mesoCellsProportions[type]);
		int index <- rand(total);
		int cumul <- mesoCellsProportions[type][0];
		int currentType <- 0;
		loop  while: (index>cumul) {
			currentType <- currentType + 1;
			cumul <- cumul + mesoCellsProportions[type][currentType]; 
		}
		return microCellsTypes[currentType];
	}
}

species microCell parent:cells{
	user_command "save Meso State"action: saveMesoState;
	user_command "Residential"action: modifyToResidential;
	user_command "Commercial"action: modifyToCommercial;
	user_command "Industrial"action: modifyToIndustrial;
	user_command "Educational"action: modifyToEducational;
	user_command "Park"action: modifyToPark;
	user_command "Lake"action: modifyToLake;
	action saveMesoState{
		ask mesoCell(currentMeso){
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
	
}

species macroConnection parent: connection{
	
}

species mesoConnection parent: connection{
	
}

species microConnection parent: connection{
	
}


experiment REGICID{
	output{
		//layout #split;
		layout vertical([horizontal([0::3863,horizontal([1::5000,2::5000])::6137])::3362,3::6638])  editors: false toolbars: false tabs: false parameters: false consoles: false navigator: false controls: false tray: false;
		display macro type:opengl draw_env:false{
			species macroCell aspect:macro;
			//species mesoCell aspect:meso;
			//species microCell aspect:micro;
			event mouse_down action: activateMacro; 
		}
		display meso type:opengl  draw_env:false camera_pos: {currentMacro.location.x, currentMacro.location.y, world.shape.width/(nbCells*0.8)} camera_look_pos:  {currentMacro.location.x, currentMacro.location.y, 0} camera_up_vector: {0.0, 1.0, 0.0}{
			species mesoCell aspect:meso;
			//species microCell aspect:micro; 
			event mouse_down action: activateMeso; 			
		}

		display micro type:opengl draw_env:false camera_pos: {currentMeso.location.x, currentMeso.location.y, world.shape.width/((nbCells*0.8)*(nbCells*0.8))} camera_look_pos:  {currentMeso.location.x, currentMeso.location.y, 0} camera_up_vector: {0.0, 1.0, 0.0}{
			species microCell aspect:micro;
		}
		
		display table type:opengl background:#white draw_env:false camera_pos: {216.5723,218.6043,128.4638} camera_look_pos: {185.83,24.5045,-36.4296} camera_up_vector: {-0.1006,0.6349,0.7661}
		{
			species macroCell aspect:macro;
			species mesoCell aspect:mesoTable;
			species microCell aspect:microTable;
			graphics 'table'{
				draw box(100,100,25) color:#black at:{50,50,-26} empty:true;
				draw box(100,100,25) color:#black at:{175,50,-26} empty:true;
				draw box(100,100,25) color:#black at:{300,50,-26} empty:true;
			}
		}
		
	}
	
}