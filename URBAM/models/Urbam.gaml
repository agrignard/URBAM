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
	float weight_car <- 0.4;
	float weight_walk <- 0.4;
	float weight_bike <- 0.2;
	list<building> residentials;
	list<building> offices;
	
	map<string,graph> graph_per_mode;
	file my_csv_file <- csv_file("../includes/nyc_grid.csv",",");
	
	init {
		list<geometry> lines;
		ask cell {
			lines << shape.contour;
		}
		geometry global_line <- union(lines);
		create road from: split_lines(global_line);
		graph_per_mode["pedestrian"] <- as_edge_graph(road);
		graph_per_mode["walk"] <- as_edge_graph(road);
		graph_per_mode["bike"] <-  as_edge_graph(road);
		//do initFromFile;
	}
	
	action initFromFile{
      matrix data <- matrix(my_csv_file);
		loop i from: 1 to: data.rows -1{
			loop j from: 0 to: data.columns -1{
				if(data[j,i] != -1){
					if(data[j,i] = 0){
					  ask cell[j,i]{do new_residential;}	
					}else{
					 ask cell[j,i]{do new_office;}	
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
	
	action initialize(cell the_cell, string the_type) {
		the_cell.my_building <- self;
		type <- the_type;
		size <- one_of(["S","M", "L"]);
		do define_color;
		shape <- the_cell.shape scaled_by 0.7;
		if (type = "residential") {residentials << self;}
		else if (type = "office") {offices << self;}
	}
	action remove {
		ask inhabitants {
			do die;
		}
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
	rgb color <- rnd_color(255);
	aspect default {
		draw shape color: color;
	}
}
species people skills: [moving]{
	string mobility_mode <- "walk"; 
	building origin;
	building dest;
	bool to_destination <- true;
	point target;
	geometry bounds;
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
		do wander bounds: bounds;
	}
	aspect default {
		draw triangle(1.0) color: color_per_mode[mobility_mode] rotate:heading +90;
	}
}
grid cell width: 8 height: 8 {
	building my_building;
	rgb color <- #lightgray;
	action new_residential {
		if (my_building != nil) {ask my_building {do remove;}}
		create building returns: bds{
			do initialize(myself, "residential");
		}
		create people number: 10 {
			origin <- first(bds);
			dest <- one_of(offices);
			origin.inhabitants << self;
			bounds <- myself.shape - origin;
			location <- any_location_in(bounds);
			
		}
	}
	action new_office {
		if (my_building != nil) {ask my_building {do remove;}}
		create building returns: bds{
			do initialize(myself, "office");
		}
		ask people {
			dest <- one_of(offices);
		}
	}
	
	user_command to_residential action: new_residential;
	user_command to_office action: new_office;
}

experiment city type: gui autorun: true{
	float minimum_cycle_duration <- 0.05;
	output {
		display map synchronized:true{
			grid cell lines: #white;
			species building;
			//species road;
			species people;
		}
	}
}
