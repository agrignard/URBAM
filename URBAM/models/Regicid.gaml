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
	
	// for the RNG
	float a <- 25214903917.0;
	float c <- 11.0;
	float m <- 2^48;
	
	
	init{
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
//	string type <- 
	
	user_command "generate Meso"action: generateMeso;
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
					type <- mesoCellsTypes[myself.rand(length(mesoCellsTypes))];
					seed <- float(myself.rand(1000000));
				}
			}
		}
	}
}

species mesoCell parent:cells{
	
	user_command "generate Micro"action: generateMicro;
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
					type <- microCellsTypes[myself.rand(length(microCellsTypes))];
					seed <- float(myself.rand(1000000));
				}
			}
		}	
	}
}

species microCell parent:cells{
	
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
			species mesoCell aspect:meso;
			species microCell aspect:micro;
			event mouse_down action: activateMacro; 
		}
		display meso type:opengl{
			species mesoCell aspect:meso;
			species microCell aspect:micro; 
			event mouse_down action: activateMeso; 			
		}

		display micro type:opengl {//camera_pos: (currentMeso = nil) ? {0,0,0} : {currentMeso.location.x, currentMeso.location.y, world.shape.width/nbCells/nbCells} camera_look_pos: (currentMeso = nil) ? {0,0,0} : {currentMeso.location.x, currentMeso.location.y, 0} camera_up_vector: {0, 1, 0}{
			species microCell aspect:micro;
		}
	}
	
}