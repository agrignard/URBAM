/***
* Name: Urbam
* Author: Arno, Pat et Tri
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Urbam


global {
	map<string,rgb> color_per_mode <- ["car"::#red, "bike"::#blue, "walk"::#green];
	map<string,rgb> color_per_type <- ["residential"::#gray, "office"::#orange];
	map<string,float> nb_people_per_size <- ["S"::10.0, "M"::50.0, "L"::100.0];
	map<string,float> proba_choose_per_size <- ["S"::0.1, "M"::0.5, "L"::1.0];
	map<int, list<string>> id_to_building_type <- [1::["residential","S"],2::["residential","M"],3::["residential","L"],4::["office","S"],
		5::["office","M"],6::["office","L"]];
	float weight_car <- 0.4;
	float weight_walk <- 0.4;
	float weight_bike <- 0.2;
	list<building> residentials;
	map<building, float> offices;
	string imageFolder <- "../images/";
	int action_type;

	int file_cpt <- 1;
	bool load_grid_file <- false;
	map<string,graph> graph_per_mode;
	
	//image des boutons
	list<file> images <- [
		file(imageFolder +"residential_S.png"),
		file(imageFolder +"office_S.png"),
		file(imageFolder +"eraser.png"),
		file(imageFolder +"residential_M.png"),
		file(imageFolder +"office_M.png"),
		file(imageFolder +"road.png"),
		file(imageFolder +"residential_L.png"),
		file(imageFolder +"office_L.png"),
		file(imageFolder +"empty.png")
	]; 
	init {
		list<geometry> lines;
		ask cell {
			lines << shape.contour;
		}
		geometry global_line <- union(lines);
		create road from: split_lines(global_line);
		loop mode over: ["walk", "car", "bike"] {
			graph_per_mode[mode] <- as_edge_graph(road where (mode in each.allowed_mobility));
		}
		
		do init_buttons;
		
	}
	
	action init_buttons	{
		int inc<-0;
		ask button {
			action_nb<-inc;
			inc<-inc+1;
		}
	}
	
	
	action activate_act {
		button selected_but <- first(button overlapping (circle(1) at_location #user_location));
		ask selected_but {
			ask button {bord_col<-#black;}
			action_type<-action_nb;
			bord_col<-#red;
		}
	}
	
	
	reflex test_load_file when: load_grid_file and every(100#cycle) and file_cpt < 4{
		do load_matrix("../includes/nyc_grid_" +file_cpt+".csv");
		file_cpt <- file_cpt+ 1;
	}
	

	reflex compute_traffic_density{
		ask road {traffic_density <- 0;}
		ask people{
			if current_path != nil{
				ask list<road>(current_path.edges){
					traffic_density  <- (self as road).traffic_density + 1;
				}
			}
//			if current_edge != nil{
//				(current_edge as road).traffic_density  <- (current_edge as road).traffic_density + 1;
//			}
		}
	}
	
	action build_buildings {
		cell selected_cell <- first(cell overlapping (circle(1) at_location #user_location));
		if (action_type = 3) {ask selected_cell {do new_residential("S");}} 
		if (action_type = 4) {ask selected_cell {do new_office("S");}} 
		if (action_type = 5) {ask selected_cell {do erase_building;}} 
		if (action_type = 6) {ask selected_cell {do new_residential("M");}} 
		if (action_type = 7) {ask selected_cell {do new_office("M");}} 
		if (action_type = 9) {ask selected_cell {do new_residential("L");}} 
		if (action_type = 10) {ask selected_cell {do new_office("L");}} 
		
	}
	
	action load_matrix(string path_to_file) {
		file my_csv_file <- csv_file(path_to_file,",");
		matrix data <- matrix(my_csv_file);
		loop i from: 0 to: data.rows - 1 {
			loop j from: 0 to: data.columns - 1 {
				if (data[j, i] != -1) {
					int id <- int(data[j, i]);
					if (id > 0) {
						list<string> types <- id_to_building_type[id];
						string type <- types[0];
						string size <- types[1];
						cell current_cell <- cell[j,i];
						bool new_building <- true;
						if (current_cell.my_building != nil) {
							building build <- current_cell.my_building;
							new_building <- (build.type != type) or (build.size != size);
						}
						if (new_building) {
							if (type = "residential") {
								ask current_cell {do new_residential(size);}
							} else if (type = "office") {
								ask current_cell {do new_office(size);}
							}
						}
					}
				}
			}
		}
	}
}


species building {
	string size <- "S" among: ["S", "M", "L"];
	string type <- "residential" among: ["residential", "office"];
	list<people> inhabitants;
	rgb color;
	geometry bounds;

	action initialize(cell the_cell, string the_type, string the_size) {
		the_cell.my_building <- self;
		type <- the_type;
		size <- the_size;
		do define_color;
		shape <- the_cell.shape scaled_by 0.7;
		if (type = "residential") {residentials << self;}
		else if (type = "office") {
			offices[self] <- proba_choose_per_size[size];
		}
		bounds <- the_cell.shape + 0.5 - shape;
			
	}
	action remove {
		if (type = "office") {
			offices[] >- self;
			ask people {
				do reinit_destination;
			}
		} else {
			ask inhabitants {
				do die;
			}
		}
		cell(location).my_building <- nil;
		do die;
	}
	action define_color {
		color <- rgb(color_per_type[type], size = "S" ? 50 : (size = "M" ? 100: 255)  );
	}
	aspect default {
		draw shape color: color;
	}
}

species road {
	int traffic_density <- 0;
	rgb color <- rnd_color(255);
	list<string> allowed_mobility <- ["walk","bike","car"];
	aspect default {
		if traffic_density = 0 {
			draw shape color: #white;
		}else{
			draw shape + traffic_density/150 color: rgb(52,152,219);
		}	
	}
	
	aspect edges_no_width {
		if traffic_density = 0 {
			draw shape color: #white;
		}else{
			draw shape + 0.3 color: rgb(52,152,219);
		}	
	}
	
}
species people skills: [moving]{
	string mobility_mode <- "walk"; 
	building origin;
	building dest;
	bool to_destination <- true;
	point target;
	
	action reinit_destination {
		dest <- empty(offices) ? nil : offices.keys[rnd_choice(offices.values)];
		target <- nil;
	}
	reflex move when: dest != nil{
		if (target = nil) {
			if (to_destination) {target <- any_location_in(dest);}
			else {target <- any_location_in(origin);}
		}
		do goto target: target on: graph_per_mode[mobility_mode];
		if (target = location) {
			target <- nil;
			to_destination <- not to_destination;
		}
	}
	reflex wander when: dest = nil {
		do wander bounds: origin.bounds;
	}
	aspect default {
		draw triangle(1.0) color: color_per_mode[mobility_mode] rotate:heading +90;
	}
}
grid cell width: 8 height: 8 {
	building my_building;
	rgb color <- #lightgray;
	action new_residential(string the_size) {
		if (my_building != nil and (my_building.type = "residential") and (my_building.size = the_size)) {
			return;
		} else {
			if (my_building != nil ) {ask my_building {do remove;}}
			create building returns: bds{
				do initialize(myself, "residential", the_size);
			}
			create people number: nb_people_per_size[first(bds).size]{
				origin <- first(bds);
				origin.inhabitants << self;
				location <- any_location_in(origin.bounds);
				do reinit_destination;
			}
		}
		
	}
	action new_office (string the_size) {
		if (my_building != nil and (my_building.type = "residential") and (my_building.size = the_size)) {
			return;
		} else {
			if (my_building != nil) {ask my_building {do remove;}}
			create building returns: bds{
				do initialize(myself, "office",the_size);
			}
			ask people {
				do reinit_destination;
			}
		}
	}
	action erase_building {
		if (my_building != nil) {ask my_building {do remove;}}
	}

}

grid button width:3 height:4 
{
	int action_nb;
	rgb bord_col<-#black;
	aspect normal {
		if (action_nb > 2 and not (action_nb in [11])) {draw rectangle(shape.width * 0.8,shape.height * 0.8).contour + 0.5 color: bord_col;}
		if (action_nb = 0) {draw "Build residential building"  color:#black font:font("SansSerif", 16, #bold) at: location - {15,-10.0,0};}
		else if (action_nb = 1) {draw "Build office building"  color:#black font:font("SansSerif", 16, #bold) at: location - {12,-10.0,0};}
		else if (action_nb = 2) {draw "Tools"  color:#black font:font("SansSerif", 16, #bold) at: location - {12,-10.0,0};}
		else {
			draw image_file(images[action_nb - 3]) size:{shape.width * 0.7,shape.height * 0.7} ;
		}
	}
}

experiment city type: gui autorun: true{
	float minimum_cycle_duration <- 0.05;
	output {
		display map synchronized:true{
			grid cell lines: #white;
			species building;
			species road;// aspect: edges_no_width;
			species people;
			event mouse_down action:build_buildings;   
		}
		
			//Bouton d'action
		display action_buton name:"Actions possibles" ambient_light:100 	{
			species button aspect:normal ;
			event mouse_down action:activate_act;    
		}	
	}
}
