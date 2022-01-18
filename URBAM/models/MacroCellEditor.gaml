/***
* Name: MacroCellEditor
* Author: Patrick Taillandier
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model MacroCellEditor

global {
	shape_file france_shp <- shape_file("../includes/GIS/France.shp");
	geometry shape <- envelope(france_shp);
	map<string, rgb> macroCellsColors <- ["Urban hi-density"::#gamaorange, "Urban low-density"::#gamared, "Countryside"::#green,"Water"::#blue, "Empty"::#white];

	int action_type <- -1;	
	
	init {
		create cells from: shape to_rectangles(10,10) where (each.area > 100);		
	}	
	
	user_command save_data {
		save cells to: "../includes/GIS/France_Macro.shp" type:shp attributes: [type::"Type"];
	}
	
	action activate_act {
		button selected_but <- first(button overlapping (circle(1) at_location #user_location));
		if(selected_but != nil) {
			ask selected_but {
				if (type = "") {
					save cells to: "../includes/GIS/France_squares.shp" type:shp attributes: [type::"Type"];
				} 
				else {					
				  ask button {bord_col<-#black;}
					if (action_type != id) {
						action_type<-id;
						bord_col<-#red;
					} else {
						action_type<- -1;
			      }
				}
			}
		}
	}
	
	action cell_management {
		button the_button <- (button first_with (each.id = action_type)); 
		if(the_button!=nil){
		  if (the_button.type != "") {
			cells selected_cell <- first(cells overlapping (circle(1.0) at_location #user_location));
			if(selected_cell != nil) {
				ask selected_cell {
					type <- the_button.type;
				}
			}
		  }
		}	
	}
}

species cells {
	string type <- "Countryside";
	aspect default {
		draw shape color: macroCellsColors[type] border: #black;
	}
	
}



grid button width:2 height:3 
{
	int id <- int(self);
	string type <- id < length(macroCellsColors) ? macroCellsColors.keys[id] : "";
	rgb color <- type = "" ?  #magenta: macroCellsColors[type]  ;
	rgb bord_col<-#black;
	aspect normal {
		draw rectangle(shape.width * 0.55,shape.width * 0.55).contour + (shape.width * 0.001) color: bord_col;
		if (type = "") {
			draw "Save Data" color: #red size: 50#px;
		} 
		else {draw rectangle(shape.width * 0.5,shape.width * 0.5) color: color ;}
	}
}


experiment toSquares type: gui {
	output {
		layout #split
		editors: false toolbars: false tabs: false parameters: false consoles: false navigator: false controls: false tray: false;
		display map background:#black{
			image "../includes/GIS/FranceAvecNom.png" refresh: false;
			species cells transparency: 0.5;
			event mouse_down action:cell_management;
		}
		
		display action_buton background:#black name:"Tools panel"  	{
			species button aspect:normal ;
			event mouse_down action:activate_act;    
		}
	}
}
