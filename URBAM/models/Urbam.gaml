/***
* Name: Urbam
* Author: Arno
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Urbam


global {
	map<string,rgb> color_per_mode <- ["car"::#red, "bike"::#blue, "walk"::#green];
	map<string,rgb> color_per_type <- ["residential"::#gray, "office"::#orange,"empty"::#lightgray];
	float weight_car <- 0.4;
	float weight_walk <- 0.4;
	float weight_bike <- 0.2;
	list<cell> residentials;
	list<cell> offices;
	
	
}

species people {
	string moblity_mode <- "walk"; 
	cell origine;
	cell destination;
	aspect default {
		draw triangle(1.0) color: color_per_mode[moblity_mode];
	}
}
grid cell width: 8 height: 8 {
	string type <- "empty";
	rgb color <- color_per_type[type];
	action new_residential {
		residentials << self;
		type <- "residential";
		color <- color_per_type[type];
		create people number: 10 {
			origine <- myself;
			location <- any_location_in(myself);
			destination <- one_of(offices);
		}
	}
	action new_office {
		type <- "office";
		color <- color_per_type[type];
		offices << self;
	}
	
	user_command to_residential action: new_residential;
	user_command to_office action: new_office;
}

experiment city type: gui {
	output {
		display map {
			grid cell lines: #white;
			species people;
		}
	}
}
