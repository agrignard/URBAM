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
	init{
		loop i from: 0 to: nbCells-1{
			loop j from:0 to:nbCells-1{
				create macroCell{
					size<-world.shape.width/nbCells;
					location<-{size*i+size/2,size*j+size/2};
				}
			}
		}
		currentMacro<- one_of(macroCell);
		currentMeso<- one_of(macroCell);
	}
}

species cells{
	string type; 
	int seed;
	float size;
	cells currentSelectedCell;
	
	aspect macro{
		draw square(size) color:#gamablue border:#gamablue-25;
	}
	
	aspect meso{
		draw square(size) color:#gamaorange border:#gamaorange-25;
	}
	
	aspect micro{
		draw square(size) color:#gamared border:#gamared-25;
	}
	
}

species connection{
	cells source;
	cells destination;
}

species macroCell parent: cells{
	
	user_command "generate Meso"action: generateMeso;
	action generateMeso{
		currentMacro<-self;
		ask mesoCell{
			do die;
		}
		ask microCell{
			do die;
		}
		loop i from: 0 to: nbCells-1{
			loop j from:0 to:nbCells-1{
				create mesoCell{
					size<-myself.size/nbCells;
					location<-{myself.location.x-myself.size/2+size*i+size/2,myself.location.y-myself.size/2+size*j+size/2,0};
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
		loop i from: 0 to: nbCells-1{
			loop j from:0 to:nbCells-1{
				create microCell{
					size<-myself.size/nbCells;
					location<-{myself.location.x-myself.size/2+size*i+size/2,myself.location.y-myself.size/2+size*j+size/2,0};
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
		}
		display meso type:opengl  camera_pos: {currentMacro.location.x, currentMacro.location.y, world.shape.width/3} camera_look_pos:  {currentMacro.location.x, currentMacro.location.y, 0} camera_up_vector: {0.0, 1.0, 0.0}{
			species mesoCell aspect:meso;
			species microCell aspect:micro; 
		}

		display micro type:opengl camera_pos: {currentMeso.location.x, currentMeso.location.y, world.shape.width/12} camera_look_pos:  {currentMeso.location.x, currentMeso.location.y, 0} camera_up_vector: {0.0, 1.0, 0.0}{
			species microCell aspect:micro;
		}
	}
	
}