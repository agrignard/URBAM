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
}

species people {
	string moblity_mode <- "walk"; 
	aspect default {
		draw triangle(1.0) color: color_per_mode[moblity_mode];
	}
}
grid cell width: 20 height: 20 {
	string type <- "empty";
	rgb color <- color_per_type[type];
	user_command to_residential {
		type <- "residential";
		color <- color_per_type[type];
	}
}

experiment city type: gui {
	output {
		display map {
			grid cell lines: #white;
			species people;
		}
	}
}
