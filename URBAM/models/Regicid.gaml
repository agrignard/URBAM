/***
* Name: Regicid REGIonal CIty District
* Author: Arno
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Regicid

/* Insert your model definition here */

global{
	int nbCells<-6;
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
		draw square(size) color: macroCellsColors[type] border:#gamablue-25;
	}
	
	aspect meso{
		draw square(size) color:mesoCellsColors[type] border:#gamaorange-25;
	}
	
	aspect micro{
		draw square(size) color: microCellsColors[type] border:#gamared-25;
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
				}
			}
		}
	}
	
	string affectMesoCellType {
		int total <- sum(macroCellsProportions[type]);
		int index <- rand(total);
		int cumul <- macroCellsProportions[type][0];
		int currentType <- 0;
		loop  while: (index >= cumul) {
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
	}
	action modifyToVillage{
		type<-macroCellsTypes[1];
	}
	action modifyToPark{
		type<-macroCellsTypes[2];
	}
	action modifyToLake{
		type<-macroCellsTypes[3];
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
		list<int> newProportions <- [];
		loop microType over: microCellsTypes{
			newProportions << (microCell count (each.type = microType));
		}
		put newProportions at: currentMeso.type in: mesoCellsProportions;
	}
	action modifyToResidential{
		type<-mesoCellsTypes[0];
	}
	action modifyToCommercial{
		type<-mesoCellsTypes[1];
	}
	action modifyToIndustrial{
		type<-mesoCellsTypes[2];
	}
	action modifyToEducational{
		type<-mesoCellsTypes[3];
	}
	action modifyToPark{
		type<-mesoCellsTypes[4];
	}
	action modifyToLake{
		type<-mesoCellsTypes[5];
	}
	
	string affectMicroCellType {
		int total <- sum(mesoCellsProportions[type]);
		int index <- rand(total);
		int cumul <- mesoCellsProportions[type][0];
		int currentType <- 0;
		loop  while: (index >= cumul) {
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
		type<-mesoCellsTypes[0];
	}
	action modifyToCommercial{
		type<-mesoCellsTypes[1];
	}
	action modifyToIndustrial{
		type<-macroCellsTypes[2];
	}
	action modifyToEducational{
		type<-macroCellsTypes[3];
	}
	action modifyToPark{
		type<-macroCellsTypes[4];
	}
	action modifyToLake{
		type<-macroCellsTypes[5];
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
		layout #split;
		display macro type:opengl{
			species macroCell aspect:macro;
			//species mesoCell aspect:meso;
			//species microCell aspect:micro;
			event mouse_down action: activateMacro; 
		}
		display meso type:opengl  camera_pos: {currentMacro.location.x, currentMacro.location.y, world.shape.width/3} camera_look_pos:  {currentMacro.location.x, currentMacro.location.y, 0} camera_up_vector: {0.0, 1.0, 0.0}{
			species mesoCell aspect:meso;
	//		species microCell aspect:micro; 
			event mouse_down action: activateMeso; 			
		}

		display micro type:opengl camera_pos: {currentMeso.location.x, currentMeso.location.y, world.shape.width/12} camera_look_pos:  {currentMeso.location.x, currentMeso.location.y, 0} camera_up_vector: {0.0, 1.0, 0.0}{
			species microCell aspect:micro;
		}
		
	}
	
}