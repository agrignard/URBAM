/***
* Name: Urbam
* Author: Arno, Pat et Tri
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Urbam


global{
	//PARAMETERS
	
	float weight_car parameter: 'weight car' category: "Mobility" step: 0.1 min:0.1 max:1.0 <- 0.75 ;
	float weight_bike parameter: 'weight bike' category: "Mobility" step: 0.1 min:0.1 max:1.0 <- 0.5 ;
	float weight_pev  step: 0.1 min: 0.0 max: 1.0 parameter: "weight pev" category: "Mobility" <- 0.1;
		
	string road_aspect parameter: 'Roads aspect:' category: 'Road Aspect' <-"split (5)" among:["default", "default (car)", "hide","road type","edge color","split (3)", "split (5)"];
	float spacing parameter: 'Spacing ' category: 'Road Aspect' <- 0.75 min:0.0 max: 1.5;
	float line_width parameter: 'Line width' category: 'Road Aspect' <- 0.65 min:0.0 max: 3.0;
	bool dynamical_width parameter: 'Dynamical width' category: 'Road Aspect' <- true;
	
	float building_scale parameter: 'Building scale:' category: 'Building Aspect' <- 0.65 min: 0.2 max: 1.0; 
	bool show_cells parameter: 'Show cells:' category: 'Aspect' <- false;
	bool show_building parameter: 'Show Building:' category: 'Aspect' <- true;
	
	bool blackMirror parameter: 'Dark Room' category: 'Aspect' <- true;
	
	
	string people_aspect parameter: 'People aspect:' category: 'People Aspect' <-"mode" among:["mode", "profile","dynamic_abstract","dynamic_abstract (car)","hide"];
	
	int global_people_size <-50;
	
	list<basic_people> list_of_people;
	
	
	float computed_line_width;
	float road_width;
	float block_size;
	
	bool on_modification_cells <- false update: show_cells != show_cells_prev;
	
	bool show_cells_prev <- show_cells update: show_cells ;
	bool on_modification_bds <- false update: false;
	
	
	//ORIGINAL map<string,int> max_traffic_per_mode <- ["car"::90, "bike"::10, "walk"::50];
	
	map<string,int> max_traffic_per_mode <- ["car"::50, "bike"::50, "walk"::50];
	map<string,int> mode_order <- ["car"::0, "bike"::1, "walk"::2]; // order from 0 to n write only the modes that have to be drawn
	map<string,rgb> color_per_mode <- ["car"::rgb(52,152,219), "bike"::rgb(192,57,43), "walk"::rgb(161,196,90), "pev"::#magenta];
	//map<string,rgb> color_per_mode <- ["car"::rgb(255,0,0), "bike"::rgb(0,255,0), "walk"::rgb(0,0,255), "pev"::#magenta];
	map<string,geometry> shape_per_mode <- ["car"::circle(global_people_size*0.225), "bike"::circle(global_people_size*0.21), "walk"::circle(global_people_size*0.2), "pev"::circle(global_people_size*0.21)];
	
	map<string,point> offsets <- ["car"::{0,0}, "bike"::{0,0}, "walk"::{0,0}];
	map<string,rgb> color_per_profile <- ["young poor"::#deepskyblue, "young rich"::#darkturquoise, "adult poor"::#orangered , "adult rich"::#coral,"old poor"::#darkslategrey,"old rich"::#lightseagreen];
	map<string,list<rgb>> colormap_per_mode <- ["car"::[rgb(107,213,225),rgb(255,217,142),rgb(255,182,119),rgb(255,131,100),rgb(192,57,43)], "bike"::[rgb(107,213,225),rgb(255,217,142),rgb(255,182,119),rgb(255,131,100),rgb(192,57,43)], "walk"::[rgb(107,213,225),rgb(255,217,142),rgb(255,182,119),rgb(255,131,100),rgb(192,57,43)]];
	map<string,rgb> color_per_type <- ["residential"::#gray, "office"::#orange];
	map<string,rgb> color_per_id <- ["residentialS"::#blue,"residentialM"::#white,"residentialL"::#cyan,"officeS"::#yellow,"officeM"::#red,"officeL"::#green];
	map<string,float> nb_people_per_size <- ["S"::10.0, "M"::50.0, "L"::100.0];
	map<string,float> proba_choose_per_size <- ["S"::0.1, "M"::0.5, "L"::1.0];
	map<int, list<string>> id_to_building_type <- [1::["residential","S"],2::["residential","M"],3::["residential","L"],4::["office","S"],5::["office","M"],6::["office","L"]];
	list fivefoods<-["Residential","Retail","Hotel","Office","Industrial","Park"];
		


	float weight_car_prev <- weight_car;
	float weight_bike_prev <- weight_bike;
	float weight_pev_prev <- weight_pev;
	
	string profile_file <- "../includes/profiles.csv"; 
	map<string,map<profile,float>> proportions_per_bd_type;
	
	map<string,graph> graph_per_mode;
	
	float road_capacity <- 10.0;
	bool traffic_jam <- true parameter: true;
	
	
	map<string,list<float>> speed_per_mobility <- ["car"::[20.0,40.0], "bike"::[5.0,15.0], "walk"::[3.0,7.0], "pev"::[15.0,30.0]];
	
	
	action load_profiles {
		create profile from: csv_file(profile_file,";", true) with: [proportionS::float(get("proportionS")),proportionM::float(get("proportionM")),proportionL::float(get("proportionL")),
			name::string(get("typo")), max_dist_walk::float(get("max_dist_walk")),max_dist_bike::float(get("max_dist_bike")),max_dist_pev::float(get("max_dist_pev"))
		];
		ask profile {
			map<profile, float> prof_pro1 <- proportions_per_bd_type["S"];
			prof_pro1[self] <- proportionS; proportions_per_bd_type["S"] <- prof_pro1;
			map<profile, float> prof_pro2 <- proportions_per_bd_type["M"];
			prof_pro2[self] <- proportionM; proportions_per_bd_type["M"] <- prof_pro2;
			map<profile, float> prof_pro3 <- proportions_per_bd_type["L"];
			prof_pro3[self] <- proportionL; proportions_per_bd_type["L"] <- prof_pro3;
		}
	}
	
	
	action update_graphs {
		loop mode over: ["walk", "car", "bike"] {
			graph_per_mode[mode] <- directed(as_edge_graph(road where (mode in each.allowed_mobility)));
		}
	}
	
	
	reflex update_mobility  {
		if(weight_car_prev != weight_car) or (weight_bike_prev != weight_bike) or (weight_pev_prev != weight_pev) {
			ask list_of_people {
				know_pev <- flip(weight_pev);
				has_car <- flip(weight_car);
				has_bike <- flip(weight_bike);
				
				do choose_mobility;
				do mobility;
			}
		}
		weight_car_prev <- weight_car;
		weight_bike_prev <- weight_bike;
		weight_pev_prev <-weight_pev;
		
	}
	
		
	reflex update_graph when: every(3 #cycle) {
		map<road,float> weights <- traffic_jam ? road as_map (each::(each.shape.perimeter)) : road as_map (each::(each.shape.perimeter * (min([10,1/exp(-each.nb_people/road_capacity)]))));
		graph_per_mode["car"] <- graph_per_mode["car"] with_weights weights;
	}
	

	reflex compute_traffic_density{
		ask road {traffic_density <- ["car"::[0::0,1::0], "bike"::[0::0,1::0], "walk"::[0::0,1::0], "pev"::[0::0,1::0]];}

		ask list_of_people{
			if current_path != nil and current_path.edges != nil{
				ask list<road>(current_path.edges){
					traffic_density[myself.mobility_mode][myself.heading_index]  <- traffic_density[myself.mobility_mode][myself.heading_index] + 1;
				}
			}
		}
	}
	
	reflex precalculate_display_variables{
		road_width <- block_size * 2/3 * (1-building_scale);
		switch road_aspect {
			match  "split (3)" {
				computed_line_width <- line_width * road_width/6;
			}
			match  "split (5)" {
				computed_line_width <- line_width * road_width/10;
			}
			default{
				computed_line_width <- 0.5*line_width*road_width;
			}
		}
		
		loop t over: mode_order.keys{
			if road_aspect = "split (3)" {offsets[t] <- {0.5*road_width*spacing*(mode_order[t]-1),0.5*road_width*spacing*(mode_order[t]-1)};}
			if road_aspect = "split (5)" {offsets[t] <- {0.5*road_width*spacing*(mode_order[t]+0.5)/(length(mode_order)-0.5),0.5*road_width*spacing*(mode_order[t]+0.5)/(length(mode_order)-0.5)};}
		}		
	}
		

	

		
}


species road {
	int nb_people;
	map<string,map<int,int>> traffic_density <- ["car"::[0::0,1::0], "bike"::[0::0,1::0], "walk"::[0::0,1::0], "pev"::[0::0,1::0]];
	rgb color <- rnd_color(255);
	list<string> allowed_mobility <- ["walk","bike","car"];

	init {
	}
	
	int total_traffic{
		return sum(traffic_density.keys collect(sum(traffic_density[each])));
	}
	
	
	int total_traffic_per_mode(string m){
		return sum(traffic_density[m]);
	}
	
	
	rgb color_map(rgb c, float scale){
		return rgb(255+scale * (c.red - 255),255+scale * (c.green - 255),255+scale * (c.blue - 255));
	}

	aspect default {
		switch road_aspect {
			match "default" {
				if total_traffic() > 0 {
					float scale <- min([1,total_traffic() / max_traffic_per_mode["car"]]);
					if dynamical_width{
						draw shape + computed_line_width * scale color: color_per_mode["car"];	
					}else{
						draw shape + computed_line_width color: color_map(color_per_mode["car"],scale);	
					}
				}	
			}
			match "default (car)" {
				if total_traffic_per_mode('car') > 0 {
					float scale <- min([1,total_traffic_per_mode('car') / max_traffic_per_mode["car"]]);
					if dynamical_width{
						draw shape + computed_line_width * scale color: color_per_mode["car"];	
					}else{
						draw shape + computed_line_width color: color_map(color_per_mode["car"],scale);	
					}
				}	
			}
			match "road type" {
				if ("car" in allowed_mobility) {
					draw shape + computed_line_width color:color_per_mode["car"];
				}
				if ("bike" in allowed_mobility) {
					draw shape + 0.5*computed_line_width color:color_per_mode["bike"];
				}
				if ("walk" in allowed_mobility) {
					draw shape + 0.2*computed_line_width color:color_per_mode["walk"];
				}
			}
			match "edge color"{		
				int traffic <-total_traffic() ; 
				if traffic > 0 {
					float scale <- min([1,traffic / 100])^2;
					draw shape + computed_line_width color: colormap_per_mode["car"][int(4*scale)];
				}	
			}
			match "split (3)"{
				loop t over: mode_order.keys{
					float scale <- min([1,total_traffic_per_mode(t) / max_traffic_per_mode[t]]);		
					if scale > 0 {
						if dynamical_width{
							draw shape + computed_line_width * scale color: color_per_mode[t] at: self.location+offsets[t];	
						}else{
							draw shape + computed_line_width color: color_map(color_per_mode[t],scale) at: self.location+offsets[t];	
						}
					}
				}
			}	
			match "split (5)"{
				loop t over: mode_order.keys{
					float scale <- min([1,traffic_density[t][0] / max_traffic_per_mode[t]]);	
					if dynamical_width{
						if scale > 0 {draw shape + computed_line_width * scale color: color_per_mode[t] at: self.location+offsets[t];}
						scale <- min([1,traffic_density[t][1] / max_traffic_per_mode[t]]);	
						if scale > 0 {draw shape + computed_line_width * scale color: color_per_mode[t] at: self.location-offsets[t];}
					}else{
						if scale > 0 {draw shape + computed_line_width color: color_map(color_per_mode[t],scale) at: self.location+offsets[t];}
						scale <- min([1,traffic_density[t][1] / max_traffic_per_mode[t]]);	
						if scale > 0 {draw shape + computed_line_width color: color_map(color_per_mode[t],scale) at: self.location-offsets[t];}
					}
				}
			}		
		}	
	}
}

species poi {
	geometry bounds;
}

species profile {
	float proportionS;
	float proportionM;
	float proportionL;
	float max_dist_walk;
	float max_dist_bike;
	float max_dist_pev;
}
species basic_people skills: [moving]{

	int heading_index <- 0;
	string mobility_mode <- "walk"; 
	float display_size <-sqrt(world.shape.area)* 0.01;
	poi origin;
	poi dest;
	bool to_destination <- true;
	point target;
	profile my_profile;
	bool know_pev <- false;
	bool has_car <- flip(weight_car);
	bool has_bike <- flip(weight_bike);
	action choose_mobility {
		if (origin != nil and dest != nil and my_profile != nil) {
			float dist <- manhattan_distance(origin.location, dest.location);
			if (dist <= my_profile.max_dist_walk ) {
					mobility_mode <- "walk";
			} else if (has_bike and dist <= my_profile.max_dist_bike ) {
					mobility_mode <- "bike";
			} else if (know_pev and (dist <= my_profile.max_dist_pev )) {
					mobility_mode <- "pev";
			} else if has_car {
					mobility_mode <- "car";
			} else {
					mobility_mode <- "walk";
			}
		speed <- rnd(speed_per_mobility[mobility_mode][0],speed_per_mobility[mobility_mode][1]) #km/#h;
		}
	}
	
	float manhattan_distance (point p1, point p2) {
		return abs(p1.x - p2.x) + abs(p1.y - p2.y);
	}
	reflex update_heading_index{
		if (mod(heading+90,360) < 135) or (mod(heading+90,360) > 315){
						heading_index <- 0;
					} else{
						heading_index <- 1;
					}
	}
	action reinit_destination ;
	
	action mobility {
		do unregister;
		do goto target: target on: graph_per_mode[(mobility_mode = "pev") ? "bike" : mobility_mode] recompute_path: false ;
		do register;
	}
	action update_target {
		if (to_destination) {target <- any_location_in(dest);}//centroid(dest);}
		else {target <- any_location_in(origin);}//centroid(origin);}
		do choose_mobility;
		do mobility;
	}
	
	action register {
		if ((mobility_mode = "car") and current_edge != nil) {
			road(current_edge).nb_people <- road(current_edge).nb_people + 1;
		}
	}
	action unregister {
		if ((mobility_mode = "car") and current_edge != nil) {
			road(current_edge).nb_people <- road(current_edge).nb_people - 1;
		}
	}

	reflex move when: dest != nil{
		if (target = nil) {
			do update_target;
		}
		do mobility;
		if (target = location) {
			target <- nil;
			to_destination <- not to_destination;
			do update_target;
		}
	}
	
	
	reflex wander when: dest = nil and origin != nil {
		do wander bounds: origin.bounds;
	}

	
	aspect default{
		point offset <- {0,0};
		if self.current_edge != nil {
			if road_aspect = "split (3)"{
				offset <- offsets[mobility_mode];
			}
			if road_aspect = "split (5)"{
				offset <- offsets[mobility_mode]*(heading_index > 0 ? (-1): 1);
			}			
				
		}
		switch people_aspect {
		   match "mode" {	
				if (target != nil or dest = nil) {
					if(mobility_mode ="car"){
					  draw copy(shape_per_mode[mobility_mode])  color: color_per_mode[mobility_mode] border:color_per_mode[mobility_mode] rotate:heading +90 at: location+offset;
					}else{
					  draw copy(shape_per_mode[mobility_mode])  color: color_per_mode[mobility_mode] rotate:heading +90 at: location+offset;	
					}
				}	
			}	
			match "profile" {
				if (target != nil or dest = nil) {
					if(mobility_mode ="car"){
					  draw copy(shape_per_mode[mobility_mode])  empty:true border:color_per_profile[my_profile.name] rotate:heading +90 at: location+offset;
					}else{
					  draw copy(shape_per_mode[mobility_mode])  color: color_per_profile[my_profile.name] rotate:heading +90 at: location+offset;	
					}
				}
			}
			match "dynamic_abstract"{		
				float scale <- min([1,road(current_edge).total_traffic() / 100])^2;
				if (target != nil or dest = nil) {draw square(display_size) color: colormap_per_mode["car"][int(4*scale)] at: location+offset;}
			}		
			match "dynamic_abstract (car)"{		
				float scale <- min([1,road(current_edge).total_traffic_per_mode('car') / 100])^2;
				if (target != nil or dest = nil) {draw square(display_size) color: colormap_per_mode["car"][int(4*scale)] at: location+offset;}
			}		
		}
		
	}
}
