/***
* Name: Urbam
* Author: Arno, Pat et Tri
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Urbam
	

import "common model.gaml"
global{
	int population_level <- 40 parameter: 'Population level' min: 0 max: 300 category: "General";
	bool blackMirror parameter: 'Dark Room' category: 'Aspect' <- true;
	
	//SPATIAL PARAMETERS  
	int grid_height <- 6;
	int grid_width <- 6;
	float environment_height <- 5000.0;
	float environment_width <- 5000.0;
	
	
	bool load_grid_file_from_cityIO <-true; //parameter: 'Online Grid:' category: 'Simulation' <- false;
	bool load_grid_file <- false;// parameter: 'Offline Grid:' category: 'Simulation'; 
	bool udpScannerReader <- false; 
	bool udpSliderReader <- true; 
	bool editionMode <-false;
	
	bool show_cells parameter: 'Show cells:' category: 'Aspect' <- true;
	bool show_building parameter: 'Show Building:' category: 'Aspect' <- true;
	
	bool on_modification_cells <- false update: show_cells != show_cells_prev;
	
	bool show_cells_prev <- show_cells update: show_cells ;
	bool on_modification_bds <- false update: false;
	
	
	//string cityIOUrl <-"https://cityio.media.mit.edu/api/table/cityIO_gama";
	string cityIOUrl <-"https://cityio.media.mit.edu/api/table/urbam";
	shape_file nyc_bounds0_shape_file <- shape_file("../includes/GIS/nyc_bounds.shp");
	
	
	list<building> residentials;
	map<building, float> offices;
	string imageFolder <- "../images/flat/";
	map<string,map<profile,float>> proportions_per_bd_type;
	int action_type;
	

	int file_cpt <- 1;

	
	//geometry shape <- envelope(nyc_bounds0_shape_file);
	geometry shape<-rectangle(environment_width, environment_height); // one edge is 5000(m)
	//geometry shape<-rectangle(8000, 5000);
	float step <- sqrt(shape.area) /2000.0 ;
	
	
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
	
	// Network
	int scaningUDPPort <- 5000;
	int interfaceUDPPort <- 9878;
	string url <- "localhost";
	
	init {
		list<geometry> lines;
		float cell_w <- first(cell).shape.width;
		float cell_h <- first(cell).shape.height;
		loop i from: 0 to: grid_width {
			lines << line([{i*cell_w,0}, {i*cell_w,environment_height}]);
		}
		loop i from: 0 to: grid_height {
			lines << line([{0, i*cell_h}, {environment_width,i*cell_h}]);
		}
		create road from: split_lines(lines) {
			create road with: [shape:: line(reverse(shape.points))];
		}
		do update_graphs;
		do init_buttons; 
		do load_profiles;
		block_size <- min([first(cell).shape.width,first(cell).shape.height]);
		if(udpScannerReader){
			create NetworkingAgent number: 1 {
			 type <-"scanner";	
		     do connect to: url protocol: "udp_server" port: scaningUDPPort ;
		    }
		}
		if(udpSliderReader){
			create NetworkingAgent number: 1 {
			 type <-"interface";	
		     do connect to: url protocol: "udp_server" port: interfaceUDPPort ;
		    }	   
		}
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

	
	
	reflex test_load_file_from_cityIO when: load_grid_file_from_cityIO and every(10#cycle) {
		do load_cityIO_urbam_v2(cityIOUrl);
	}
	
	reflex test_load_file when: load_grid_file and every(100#cycle){
		do load_matrix("../includes/6x6_" +file_cpt+".csv");
		file_cpt <- (file_cpt+ 1) mod 5;
	}
	
	reflex randomGridUpdate when:!udpScannerReader and !editionMode and every(1000#cycle){
		do randomGrid;
	} 
		
	
	
	action infrastructure_management {
		if (action_type = 8) {
			do manage_road;
		} else {
			do build_buildings;
		}
		
	}
	
	
	action manage_road{
		road selected_road <- first(road overlapping (circle(sqrt(shape.area)/100.0) at_location #user_location));
		if (selected_road != nil) {
			bool with_car <- "car" in selected_road.allowed_mobility;
			bool with_bike <- "bike" in selected_road.allowed_mobility;
			bool with_pedestrian <- "walk" in selected_road.allowed_mobility;
			map input_values <- user_input(["car allowed"::with_car,"bike allowed"::with_bike,"pedestrian allowed"::with_pedestrian]);
			if (with_car != input_values["car allowed"]) {
				if (with_car) {selected_road.allowed_mobility >> "car";}
				else {selected_road.allowed_mobility << "car";}
				
			}
			if (with_bike != input_values["bike allowed"]) {
				if (with_bike) {selected_road.allowed_mobility >> "bike";}
				else {selected_road.allowed_mobility << "bike";}
			}
			if (with_pedestrian != input_values["pedestrian allowed"]) {
				if (with_pedestrian) {selected_road.allowed_mobility >> "walk";}
				else {selected_road.allowed_mobility << "walk";}
			}
			point pt1 <- first(selected_road.shape.points);
			point pt2 <- last(selected_road.shape.points);
			road reverse_road <- road first_with ((first(each.shape.points) = pt2) and (last(each.shape.points) = pt1));
			if (reverse_road != nil) {
				reverse_road.allowed_mobility <-  selected_road.allowed_mobility;
			}
			do update_graphs;
		}
		
		
	}
	
	action build_buildings {
		cell selected_cell <- first(cell overlapping (circle(sqrt(shape.area)/100.0) at_location #user_location));
		if (selected_cell != nil) and (selected_cell.is_active) {
			if (action_type = 3) {ask selected_cell {do new_residential("S");}} 
			if (action_type = 4) {ask selected_cell {do new_office("S");}} 
			if (action_type = 5) {ask selected_cell {do erase_building;}} 
			if (action_type = 6) {ask selected_cell {do new_residential("M");}} 
			if (action_type = 7) {ask selected_cell {do new_office("M");}} 
			if (action_type = 9) {ask selected_cell {do new_residential("L");}} 
			if (action_type = 10) {ask selected_cell {do new_office("L");}} 
		}
		on_modification_bds <- true;
	}
	
	action createCell(int id, int x, int y){
		list<string> types <- id_to_building_type[id];
		string type <- types[0];
		string size <- types[1];
		cell current_cell <- cell[x,y];
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
	action load_matrix(string path_to_file) {
		file my_csv_file <- csv_file(path_to_file,",");
		matrix data <- matrix(my_csv_file);
		loop i from: 0 to: data.rows - 1 {
			loop j from: 0 to: data.columns - 1 {
					int id <- int(data[j, i]);
					if (id > 0) {
                     do createCell(id, j, i);
					}
					cell current_cell <- cell[j,i];
					current_cell.is_active <- id<0?false:true;
					if (id<=0){					
						ask current_cell{ do erase_building;}
					}
			}
		}
	}
	
	
	
   action randomGrid{
   	int id;
   	loop i from: 0 to: 5 {
			loop j from: 0 to: 5 {
				    if (flip(0.5)){
				        id <- 1+rnd(5);	
				    }else{
				    	id<--1;
				    }
					
					if (id > 0) {
                     do createCell(id, j, i);
					}
					cell current_cell <- cell[j,i];
					current_cell.is_active <- id<0?false:true;
					if (id<=0){					
						ask current_cell{ do erase_building;}
					}
			}
		}
   }
	
	action load_cityIO_matrix_v1(string cityIOUrl_) {
		map<string, unknown> cityMatrixData;
	    list<map<string, int>> cityMatrixCell;	
		try {
			cityMatrixData <- json_file(cityIOUrl_).contents;
		} catch {
			cityMatrixData <- json_file("../includes/cityIO_Kendall.json").contents;
			//write #current_error + "Connection to Internet lost or cityIO is offline - CityMatrix is a local version from cityIO_Kendall.json";
		}
		cityMatrixCell <- cityMatrixData["grid"];	
		loop l over: cityMatrixCell { 
      	  int id <-int(l["type"]);
      	  if(id!=-2 and id !=-1 and id!=6 ){
      	  	do createCell(id+1, l["x"], l["y"]);	
      	  } 
      	  if (id=-1){
		    cell current_cell <- cell[l["x"],l["y"]];
			ask current_cell{ do erase_building;}
		  }     
        }	
	}
	
	
	action load_cityIO_matrix_v2(string cityIOUrl_) {
		map<string, unknown> cityMatrixData;
	    list<map<string, int>> cityMatrixCell;	
		try {
			cityMatrixData <- json_file(cityIOUrl_).contents;
		} catch {
			cityMatrixData <- json_file("../includes/cityIO_gama.json").contents;
			write #current_error + "Connection to Internet lost or cityIO is offline - CityMatrix is a local version from cityIO_gama.json";
		}
		
		int nbCols <- int(cityMatrixData["header"]["spatial"]["ncols"]);
		int nbRows <- int(cityMatrixData["header"]["spatial"]["nrows"]);
		loop i from: 0 to: nbCols-1 {
			loop j from: 0 to: nbRows -1{
				int id <-int(cityMatrixData["grid"][j*nbCols+i][0]);
      	  		if(id!=-2 and id !=-1 and id!=6 ){
      	  			do createCell(id+1, i, j);	
      	  		} 
      	  		if (id=-1){
		    		cell current_cell <- cell[i,j];
					ask current_cell{ do erase_building;}
		  		}   
			}
        } 	
	}
	
		action load_cityIO_urbam_v2(string cityIOUrl_) {
		map<string, unknown> cityMatrixData;
	    list<map<string, int>> cityMatrixCell;	
		try {
			cityMatrixData <- json_file(cityIOUrl_).contents;
		} catch {
			cityMatrixData <- json_file("../includes/cityIO_gama.json").contents;
			write #current_error + "Connection to Internet lost or cityIO is offline - CityMatrix is a local version from cityIO_gama.json";
		}
		int ncols <- int(cityMatrixData["header"]["spatial"]["ncols"]);
		int nrows <- int(cityMatrixData["header"]["spatial"]["nrows"]);
		int x;
		int y;
		int id;
		loop i from:0 to: (ncols*nrows-2){ 
			if((i mod nrows) mod 2 = 1 and int(i/ncols) mod 2 = 0){   
				x<- int((i mod nrows)/2);
			    y<-int((int(i/ncols))/2);
			    id<-int(cityMatrixData["grid"][i][0]);
			    if(id!=-2 and id !=-1 and id!=6 ){
	      	  		ask world{do createCell(id+1, x, y);}	
	      	    } 
	      	    if (id=-1){
			    	cell current_cell <- cell[x,y];
				    ask current_cell{ do erase_building;}
			    }	   
			 } 		
       }	
	}
		
}


species building parent: poi {
	string size <- "S" among: ["S", "M", "L"];
	string type <- "residential" among: ["residential", "office"];
	list<people> inhabitants;
	rgb color;

	action initialize(cell the_cell, string the_type, string the_size) {
		the_cell.my_building <- self;
		type <- the_type;
		size <- the_size;
		do define_color;
		shape <- the_cell.shape;
		if (type = "residential") {residentials << self;}
		else if (type = "office") {
			offices[self] <- proba_choose_per_size[size];
		}
		bounds <- the_cell.shape + 0.5 - shape;
			
	}
	
	reflex populate when: (type = "residential"){
		int pop <- int(population_level/100 * nb_people_per_size[size]);
		if length(inhabitants) < pop{
			create people number: 1 with: [location::any_location_in(bounds)] {
				origin <- myself;
				building(origin).inhabitants << self;
				list_of_people << self;
				do reinit_destination;
				map<profile, float> prof_pro <- proportions_per_bd_type[building(origin).size];
				my_profile <- prof_pro.keys[rnd_choice(prof_pro.values)];
			}
		}
		if length(inhabitants) > pop{
			people tmp <- one_of(inhabitants);
			inhabitants >- tmp;
			ask tmp {do die;}
		}
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
		//color <- rgb(color_per_type[type], size = "S" ? 50 : (size = "M" ? 100: 255)  );
		color <- color_per_id[type+size];
	}
	aspect default {
		//if show_building {draw shape scaled_by building_scale color: color;}
		//if show_building {draw shape scaled_by 0.5 color: rgb(100,100,100);}
		if show_building {draw shape scaled_by building_scale*1.2 empty:true color: color;}
	}
}


species people parent: basic_people skills: [moving]{
	action reinit_destination {
		dest <- empty(offices) ? nil : offices.keys[rnd_choice(offices.values)];
		target <- nil;
	}
}

grid cell width: grid_width height: grid_height { // height: 16{
	building my_building;
	bool is_active <- true;
	//rgb color <- #white;
	action new_residential(string the_size) {
		if (my_building != nil and (my_building.type = "residential") and (my_building.size = the_size)) {
			return;
		} else {
			if (my_building != nil ) {ask my_building {do remove;}}
			create building returns: bds{
				do initialize(myself, "residential", the_size);
			}
		}
		
	}
	action new_office (string the_size) {
		if (my_building != nil and (my_building.type = "office") and (my_building.size = the_size)) {
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
	
	aspect default{
		//if {draw shape scaled_by (building_scale+(1-building_scale)/3) color: rgb(100,100,100) ;}
		if show_cells {draw shape scaled_by (0.6) color: rgb(100,100,100) ;}
	}

}

grid button width:3 height:4 
{
	int action_nb;
	rgb bord_col<-#black;
	aspect normal {
		if (action_nb > 2 and not (action_nb in [11])) {draw rectangle(shape.width * 0.8,shape.height * 0.8).contour + (shape.height * 0.01) color: bord_col;}
		if (action_nb = 0) {draw "Residential"  color:#black font:font("SansSerif", 16, #bold) at: location - {15,-10.0,0};}
		else if (action_nb = 1) {draw "Office"  color:#black font:font("SansSerif", 16, #bold) at: location - {12,-10.0,0};}
		else if (action_nb = 2) {draw "Tools"  color:#black font:font("SansSerif", 16, #bold) at: location - {12,-10.0,0};}
		else {
			draw image_file(images[action_nb - 3]) size:{shape.width * 0.5,shape.height * 0.5} ;
		}
	}
}

species NetworkingAgent skills:[network] {
	string type;
	string previousMess <-"";
	reflex fetch when:has_more_message() {	
		if (length(mailbox) > 0) {
			message s <- fetch_message();
			if(s.contents !=previousMess){	
			  previousMess<-s.contents;
			  if(type="scanner"){
			  	list gridlist <- string(s.contents) split_with(";");
			  	int nrows <- 12;
			  	int ncols <- 12;
			  	int x;
			  	int y;
			  	int id;
			  	loop i from:0 to: (length(gridlist)-2){ 
			    	if((i mod nrows) mod 2 = 0 and int(i/ncols) mod 2 = 0){   
			      		x<- int((i mod nrows)/2);
			      		y<-int((int(i/ncols))/2);
			      		id<-int(gridlist[i]);
			      	if(id!=-2 and id !=-1 and id!=6 ){
	      	  	    	ask world{do createCell(id+1, x, y);}	
	      	      	} 
	      	      	if (id=-1){
			        	cell current_cell <- cell[x,y];
				    	ask current_cell{ do erase_building;}
			      	}	   
			    	} 		
	          	}
			  }
			  if(type="interface"){
			  	weight_car<-float(previousMess)/5.0;
			  	write weight_car;
			  }
			}	
	    }
	}
}


experiment cityScienceScreenEditionMode type: gui autorun: true{
	init{
		editionMode<-true;
	}
	float minimum_cycle_duration <- 0.05;
	output {
		display map synchronized:true background:blackMirror ? #black :#white toolbar:false type:opengl  draw_env:false 
		camera_pos: {2160.3206,1631.7982,12043.0275} camera_look_pos: {2160.3206,1631.588,0.0151} camera_up_vector: {0.0,1.0,0.0}{
		//camera_pos: {2428.2049,2969.8873,11644.0583} camera_look_pos: {2428.2049,2969.684,-0.0081} camera_up_vector: {0.0,1.0,0.0}{
			species cell aspect:default;// refresh: on_modification_cells;
			species road ;
			species people;
			species building;// refresh: on_modification_bds;
			event mouse_down action:infrastructure_management;
			
			event["1"] action: {action_type<-9;};
			event["2"] action: {action_type<-3;};
			event["3"] action: {action_type<-6;};
			event["4"] action: {action_type<-4;};
			event["5"] action: {action_type<-7;};
			event["6"] action: {action_type<-10;};
			event["7"] action: {action_type<-5;};
			event["8"] action: {action_type<-8;}; 
			
			event["h"] action: {road_aspect<-"hide";};
			event["r"] action: {road_aspect<-"default";};
			event["s"] action: {road_aspect<-"split (5)";};
			event["c"] action: {road_aspect<-"edge color";}; 
			
			event["n"] action: {people_aspect<-"hide";};
			event["m"] action: {people_aspect<-"mode";};
			//event["p"] action: {people_aspect<-"profile";};
			event["a"] action: {people_aspect<-"dynamic_abstract";};
		
			event["w"] action: {blackMirror<-!blackMirror;};
			event["b"] action: {show_building<-!show_building;};
			 
			event["g"] action: {show_cells<-!show_cells;}; 
			
			event["o"] action: {weight_car<-weight_car-0.1;}; 
			event["p"] action: {weight_car<-weight_car+0.1;};
			
			event["u"] action: {weight_bike<-weight_bike-0.1;}; 
			event["i"] action: {weight_bike<-weight_bike+0.1;};
			
			event["t"] action: {weight_pev<-weight_pev-0.1;}; 
			event["y"] action: {weight_pev<-weight_pev+0.1;};
			
			
			graphics "mobilityMode" {
				    draw circle(world.shape.width * 0.01) color: color_per_mode["walk"] at: {world.shape.width * 0.2, world.shape.height};
					draw "walk" color: color_per_mode["walk"]  at: {world.shape.width * 0.2+world.shape.width * 0.02, world.shape.height * 1.005} font:font("Helvetica", 6 , #bold);
					
					draw circle(world.shape.width * 0.01) color: color_per_mode["bike"] at: {world.shape.width * 0.4, world.shape.height};
					draw "bike" color: color_per_mode["bike"]  at: {world.shape.width * 0.4 + world.shape.width * 0.02, world.shape.height * 1.005} font:font("Helvetica", 6 , #bold);
					
					draw circle(world.shape.width * 0.01) color: color_per_mode["car"] at: {world.shape.width * 0.6, world.shape.height};
					draw "car" color: color_per_mode["car"]  at: {world.shape.width * 0.6 + world.shape.width * 0.02, world.shape.height * 1.005} font:font("Helvetica", 6 , #bold);
					
					draw circle(world.shape.width * 0.01) color: color_per_mode["pev"] at: {world.shape.width * 0.8, world.shape.height};
					draw "pev" color: color_per_mode["pev"]  at: {world.shape.width * 0.8 + world.shape.width * 0.02, world.shape.height * 1.005} font:font("Helvetica", 6 , #bold);
			}
			
			graphics "landuse" {
					point hpos <- {world.shape.width * 1.1, world.shape.height * 1.1};
					float barH <- world.shape.width * 0.01;
					float factor <-  world.shape.width * 0.1;
					loop i from:0 to:length(color_per_id)-1{
						draw square(world.shape.width*0.02) empty:true color: color_per_id.values[i] at: {i*world.shape.width*0.175, -50};
						draw fivefoods[i] color: color_per_id.values[i] at: {i*world.shape.width*0.175+world.shape.width*0.025, -40} perspective: true font:font("Helvetica", 8 , #bold);
					}
			}
		}
				
	    //Bouton d'action
		display action_buton background:#black name:"Actions possibles" ambient_light:100 	{
			species button aspect:normal ;
			event mouse_down action:activate_act;    
		}	
	}
}

experiment cityScienceTable type: gui autorun: true{
	float minimum_cycle_duration <- 0.05;
	output {
		display map synchronized:true background:blackMirror ? #black :#white toolbar:false type:opengl  draw_env:false fullscreen:1
		camera_pos: {2160.3206,1631.7982,12043.0275} camera_look_pos: {2160.3206,1631.588,0.0151} camera_up_vector: {0.0,1.0,0.0}{
		//camera_pos: {2428.2049,2969.8873,11644.0583} camera_look_pos: {2428.2049,2969.684,-0.0081} camera_up_vector: {0.0,1.0,0.0}{
			species cell aspect:default;// refresh: on_modification_cells;
			species road ;
			species people;
			species building;// refresh: on_modification_bds;
			
			graphics "mobilityMode" {
				    draw circle(world.shape.width * 0.01) color: color_per_mode["walk"] at: {world.shape.width * 0.2, world.shape.height};
					draw "walk" color: color_per_mode["walk"]  at: {world.shape.width * 0.2+world.shape.width * 0.02, world.shape.height * 1.005} font:font("Helvetica", 6 , #bold);
					
					draw circle(world.shape.width * 0.01) color: color_per_mode["bike"] at: {world.shape.width * 0.4, world.shape.height};
					draw "bike" color: color_per_mode["bike"]  at: {world.shape.width * 0.4 + world.shape.width * 0.02, world.shape.height * 1.005} font:font("Helvetica", 6 , #bold);
					
					draw circle(world.shape.width * 0.01) color: color_per_mode["car"] at: {world.shape.width * 0.6, world.shape.height};
					draw "car" color: color_per_mode["car"]  at: {world.shape.width * 0.6 + world.shape.width * 0.02, world.shape.height * 1.005} font:font("Helvetica", 6 , #bold);
					
					draw circle(world.shape.width * 0.01) color: color_per_mode["pev"] at: {world.shape.width * 0.8, world.shape.height};
					draw "pev" color: color_per_mode["pev"]  at: {world.shape.width * 0.8 + world.shape.width * 0.02, world.shape.height * 1.005} font:font("Helvetica", 6 , #bold);
			}
			
			graphics "landuse" {
					point hpos <- {world.shape.width * 1.1, world.shape.height * 1.1};
					float barH <- world.shape.width * 0.01;
					float factor <-  world.shape.width * 0.1;
					loop i from:0 to:length(color_per_id)-1{
						draw square(world.shape.width*0.02) empty:true color: color_per_id.values[i] at: {i*world.shape.width*0.175, -50};
						draw fivefoods[i] color: color_per_id.values[i] at: {i*world.shape.width*0.175+world.shape.width*0.025, -40} perspective: true font:font("Helvetica", 8 , #bold);
					}
			}
		}		
	}
}


experiment cityScienceDemo type: gui autorun: true{
	float minimum_cycle_duration <- 0.05;
	output {
		display map synchronized:true background:blackMirror ? #black :#white toolbar:false type:opengl  draw_env:false fullscreen:1
		camera_pos: {2160.3206,1631.7982,12043.0275} camera_look_pos: {2160.3206,1631.588,0.0151} camera_up_vector: {0.0,1.0,0.0}{
			species cell aspect:default;// refresh: on_modification_cells;
			species road ;
			species people;
			species building;// refresh: on_modification_bds;
			
			graphics "mobilityMode" {
				    draw circle(world.shape.width * 0.01) color: color_per_mode["walk"] at: {world.shape.width * 0.2, world.shape.height};
					draw "Walk" color: color_per_mode["walk"]  at: {world.shape.width * 0.2+world.shape.width * 0.02, world.shape.height * 1.005} font:font("Helvetica", 6 , #bold);
					
					draw circle(world.shape.width * 0.01) color: color_per_mode["bike"] at: {world.shape.width * 0.4, world.shape.height};
					draw "Bike" color: color_per_mode["bike"]  at: {world.shape.width * 0.4 + world.shape.width * 0.02, world.shape.height * 1.005} font:font("Helvetica", 6 , #bold);
					
					draw circle(world.shape.width * 0.01) color: color_per_mode["car"] at: {world.shape.width * 0.6, world.shape.height};
					draw "Car" color: color_per_mode["car"]  at: {world.shape.width * 0.6 + world.shape.width * 0.02, world.shape.height * 1.005} font:font("Helvetica", 6 , #bold);
					
					draw circle(world.shape.width * 0.01) color: color_per_mode["pev"] at: {world.shape.width * 0.8, world.shape.height};
					draw "Pev" color: color_per_mode["pev"]  at: {world.shape.width * 0.8 + world.shape.width * 0.02, world.shape.height * 1.005} font:font("Helvetica", 6 , #bold);
			} 
			
			graphics "landuse" {
					point hpos <- {world.shape.width * 1.1, world.shape.height * 1.1};
					float barH <- world.shape.width * 0.01;
					float factor <-  world.shape.width * 0.1;
					loop i from:0 to:length(color_per_id)-1{
						draw square(world.shape.width*0.02) empty:true color: color_per_id.values[i] at: {i*world.shape.width*0.175, -120};
						draw fivefoods[i] color: color_per_id.values[i] at: {i*world.shape.width*0.175+world.shape.width*0.025, -95} perspective: true font:font("Helvetica", 7 , #bold);
					}
			}
		}		
	}
}