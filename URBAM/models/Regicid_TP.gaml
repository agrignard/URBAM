/***
* Name: Regicid REGIonal CIty District
* Author: Patrick from the code of Arno
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Regicid

/* Insert your model definition here */

global{
	cell_macro currentMacro;
	cell_meso currentMeso;
	
	int macro_grid_width <- 6;
	int macro_grid_height <- 6;
	int meso_grid_width <- 8;
	int meso_grid_height <- 8;
	int micro_grid_width <- 10;
	int micro_grid_height <- 10;
	
	
	float environment_height <- 5000.0;
	float environment_width <- 5000.0;
	
	int global_people_size <-50;
	geometry shape<-rectangle(environment_width, environment_height); // one edge is 5000(m)
	float step <- sqrt(shape.area) /2000.0 ;
	
	float coeff_speed <- environment_height / meso_grid_height / micro_grid_height; 
	list<string> macroCellsTypes <- ["City", "Village", "Park","Lake"];
	map<string, rgb> macroCellsColors <- ["City"::#gamaorange, "Village"::#gamared, "Park"::#green,"Lake"::#blue];
	list<string> mesoCellsTypes <- ["Residential", "Commercial", "Industrial", "Educational", "Park","Lake"];
	map<string, rgb> mesoCellsColors <- ["Residential"::#gamared, "Commercial"::#gamablue, "Industrial"::#gamaorange, "Educational"::#white, "Park"::#green,"Lake"::#blue];
	list<string> microCellsTypes <- ["Residential", "Commercial", "Industrial", "Educational", "Park","Lake"];
	map<string, rgb> microCellsColors <- ["Residential"::#gamared, "Commercial"::#gamablue, "Industrial"::#gamaorange, "Educational"::#white, "Park"::#green,"Lake"::#blue];
	map<string, list<int>> macroCellsProportions <- ["City"::[30,30,30,10,10,5], "Village"::[10,7,5,5,50,10], "Park"::[5,5,1,0,85,15],"Lake"::[5,0,0,0,5,100]];
	map<string, list<int>> microCellsProportions <- ["Residential"::[80,20,10,10,10,5], "Commercial"::[10,80,5,5,5,5], "Industrial"::[5,5,90,0,5,5],"Educational"::[5,5,5,90,5,5], "Park"::[30,30,30,10,80,5], "Lake"::[10,10,10,10,10,90]];
	map<string, int> mesoCellsPeople <- ["Residential"::100, "Commercial"::50, "Industrial"::20,"Educational"::50, "Park"::20, "Lake"::0];
	
	graph current_graph;
	init{
		ask cell_macro {
			type <- one_of(macroCellsTypes);
			loop meso over: cell_meso {
				int index <- rnd_choice(macroCellsProportions[type]);
				string type_meso <- mesoCellsTypes[index];
				meso_cells << type_meso;
				list<string> micro_cells;
				loop micro over: cell_micro {
					int index <- rnd_choice(microCellsProportions[type_meso]);
					micro_cells<< microCellsTypes[index];
				}
				meso.micro_cells<< micro_cells;
			}
		}
		
		list<geometry> lines;
		float cell_w <- first(cell_micro).shape.width;
		float cell_h <- first(cell_micro).shape.height;
		loop i from: 0 to: micro_grid_width {
			lines << line([{i*cell_w,0}, {i*cell_w,environment_height}]);
		}
		loop i from: 0 to: micro_grid_height {
			lines << line([{0, i*cell_h}, {environment_width,i*cell_h}]);
		}
		create road from: split_lines(lines) {
			create road with: [shape:: line(reverse(shape.points))];
		}
		current_graph <- directed(as_edge_graph(road));
		currentMacro<- one_of(cell_macro);
		currentMeso<- one_of(cell_meso);
		
		ask cell_macro {
			color <- macroCellsColors[type];
		}
		do update_color_sub_agent;
		do generate_people;	
	}
	
	action generate_people {
		ask people {do die;}
		int nb <- mesoCellsPeople[currentMacro.meso_cells[int(currentMeso)]];
		create people number: nb ;
	}
	
	action activateMacro {
		cell_macro cell <- cell_macro closest_to (circle(1) at_location #user_location);
		if (cell != nil and cell != currentMacro ) {
			currentMacro <- cell;
			do update_color_sub_agent;
			do generate_people;
		}
	}	
	
	action activateMeso {
		cell_meso cell <- cell_meso closest_to (circle(1) at_location #user_location);
		if (cell != nil and cell != currentMeso) {
			currentMeso <- cell;
			do update_color_sub_agent;
			do generate_people;
		}
	}	
	
	action update_color_sub_agent {
		ask currentMacro {
			loop meso over: cell_meso {
				meso.color <- mesoCellsColors[currentMacro.meso_cells[int(meso)]];
				loop micro over: cell_micro {
					micro.color <- microCellsColors[currentMeso.micro_cells[int(self)][int(micro)]];
				}
			}
		}
		
	}
	
	
}

species road {
	aspect default {
		draw shape + environment_height/500.0  color: #black;
	}
}

grid cell_micro  width: 10 height: 10 ;

grid cell_meso  width: 8 height: 8 {
	list<list<int, string>> micro_cells;
	aspect is_selected {
		if (currentMeso = self) {
			draw shape.contour + environment_height/100.0 color: #red;
		}
	}
}

grid cell_macro width: 6 height: 6 {
	string type;
	list<string> meso_cells;
	aspect is_selected {
		if (currentMacro = self) {
			draw shape.contour + environment_height/100.0 color: #red;
		}
	}
	
}

species people skills: [moving]{
	point target;
	rgb color <- rnd_color(255);
	float speed <- rnd(3, 10) #km / #h * coeff_speed;
	reflex move {
		if (target = nil) {
			target <- one_of(cell_micro).location;
		}
		do goto target: target on: current_graph;
		if (location = target) {
			target <- nil;
		}
	}
	aspect default {
		if (target != nil) {
			draw circle(global_people_size) color: color border: #black;
		}
		
	}
}




experiment main autorun: true{
	float minimum_cycle_duration <- 0.1;
	output{
		layout #split;
		display macro type:opengl{
			grid cell_macro lines: #white;
			species cell_macro aspect: is_selected;
			event mouse_down action: activateMacro; 
		}
		display meso type:opengl  {
			grid cell_meso lines: #white;
			species cell_meso aspect: is_selected;
			event mouse_down action: activateMeso; 
		}

		display micro type:opengl {
			grid cell_micro ;
			species road refresh: false;
			species people;
		}
	}
	
}