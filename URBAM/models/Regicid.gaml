/***
* Name: Regicid REGIonal CIty District
* Author: Arno
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Regicid

/* Insert your model definition here */

import "common model.gaml"
global{
	int nbCellsWidth<-10;
	int nbCellsHeight<-10;
	float macroCellWidth<-10#km;
	float macroCellHeight<-10#km;
	bool neighbors_connection <- false;
	int global_people_size <-20;
	cells currentMacro;
	cells currentMeso;
	
	bool creating_connection <- false;
	
	macroCell currentMacro_tmp;
	mesoCell currentMeso_tmp;
	float prop_returning <- 0.1;
	map<string, float> prop_macro_to_move_to <- ["City"::0.05, "Village"::0.02, "Park"::0.02,"Lake"::0.01];
	map<string, float> prop_meso_to_move_to <- ["Residential"::0.01, "Commercial"::0.05, "Industrial"::0.02, "Educational"::0.02, "Park"::0.02,"Lake"::0.01];
	
	list<string> macroCellsTypes <- ["City", "Village", "Park","Lake"];
	map<string, rgb> macroCellsColors <- ["City"::#gamaorange, "Village"::#gamared, "Park"::#green,"Lake"::#blue];
	
	list<string> mesoCellsTypes <- ["Residential", "Commercial", "Industrial", "Educational", "Park","Lake"];
	map<string, rgb> mesoCellsColors <- ["Residential"::#gamared, "Commercial"::#gamablue, "Industrial"::#gamaorange, "Educational"::#white, "Park"::#green,"Lake"::#blue];
	map<string, rgb> mesoCellsInhabitantsCoeff <- ["Residential"::0.3, "Commercial"::0.1, "Industrial"::0.1, "Educational"::#white, "Park"::#green,"Lake"::#blue];
	
	list<string> microCellsTypes <- ["Residential", "Commercial", "Industrial", "Educational", "Park","Lake"];
	map<string, rgb> microCellsColors <- ["Residential"::#gamared, "Commercial"::#gamablue, "Industrial"::#gamaorange, "Educational"::#white, "Park"::#green,"Lake"::#blue];
	
	map<string, list<int>> macroCellsProportions <- ["City"::[30,30,30,10,10,5], "Village"::[10,7,5,5,50,10], "Park"::[3,3,0,0,85,10],"Lake"::[5,0,0,0,5,100]];
	map<string, list<int>> mesoCellsProportions <- ["Residential"::[70,5,0,5,20,5], "Commercial"::[10,80,0,5,20,0], "Industrial"::[5,5,90,0,0,0], "Educational"::[10,10,0,70,25,0], "Park"::[10,5,0,0,70,20],"Lake"::[5,5,0,0,5,80]];
	map<string, float> densityPeoplePerType <-["Residential"::2000.0, "Commercial"::400.0, "Industrial"::200.0, "Educational"::1000.0, "Park"::200.0,"Lake"::0.0];
	
	
	float building_scale parameter: 'cell scale:' category: 'cell Aspect' <- 0.8 min: 0.2 max: 1.0; 
	
	// for the RNG
	float a <- 25214903917.0;
	float c <- 11.0;
	float m <- 2^48;
	geometry shape <-rectangle(nbCellsWidth*macroCellWidth, nbCellsHeight*macroCellHeight);
	file imageRaster <- file('./../images/Kent_Sketches.png');
	float step <- macroCellWidth/nbCellsWidth /2000.0 ;
	
	init{
		//do createRandomGrid;
		do load_macro_grid("./../includes/Macro_Grid_10_10.csv");
		do load_profiles;
		do init_nb_habitants;
		if (neighbors_connection) {
			float dist <- sqrt((macroCellWidth) ^2 + (macroCellHeight)^2)  * 1.1;
			ask macroCell {
				connectedCells <- macroCell at_distance dist;
			}
			
		}
		
	}
	
	int compute_total_number(list<cells> ces) {
		return (ces sum_of each.nbInhabitants) + ces sum_of (sum(each.visitors.values)) ;
	}
	
	/*reflex debug {
		write "total macro: " + compute_total_number(macroCell as list) + " total meso:" + compute_total_number(mesoCell as list) + 
		" theorique meso: " + (currentMeso = nil ? 0 : compute_total_number([currentMeso])) + " nb people: " + length(people) ;
		
	}*/
	action init_nb_habitants {
		int nb_cells <- nbCellsHeight * nbCellsWidth;
		map<string,int> nb_type_macro;
		
		loop t over: macroCellsProportions.keys {
			list<int> prop <- macroCellsProportions[t];
			int tot <- sum(prop);
			int nb <- 0;
			loop i from: 0 to: length(mesoCellsTypes) - 1{
				nb <- nb + compute_nb_meso_habitants(mesoCellsTypes[i]) * prop[i];
			}
			nb <- int(nb / tot * nb_cells);
			nb_type_macro[t] <- nb;
		}
		ask macroCell {
			nbInhabitants <- nb_type_macro[type];
		}
		
	}
	action load_macro_grid(string path_to_file) {
		file my_csv_file <- csv_file(path_to_file,",");
		matrix data <- matrix(my_csv_file);
		loop i from: 0 to: data.rows - 1 {
			loop j from: 0 to: data.columns - 1 {
				create macroCell{
					width<-macroCellWidth;
					height<-macroCellHeight;
					location<-{width*i+width/2,height*j+height/2};
					seed <- float(rnd(1000000));
					type <- string(data[i, j]);
				}
			}
		}	
	}
	
	
	action createRandomGrid {
		loop i from: 0 to: nbCellsWidth-1{
			loop j from:0 to:nbCellsHeight-1{
				create macroCell{
					width<-macroCellWidth;
					height<-macroCellHeight;
					location<-{width*i+width/2,height*j+height/2};
					seed <- float(rnd(1000000));
					type <- one_of(macroCellsTypes);
				}
			}
		}
	}
	
	reflex updateMacroMeso {
		if (currentMacro_tmp != nil and currentMacro != currentMacro_tmp) {
			ask currentMacro_tmp{
				do generateMeso;
			}
			currentMeso_tmp <- nil;
			currentMeso <- nil;
		}
		if (currentMeso_tmp != nil and currentMeso != currentMeso_tmp) {
			ask currentMeso_tmp{
				do generateMicro;
			}
		}
	}
	
	action create_connection_macro {
		ask (macroCell closest_to #user_location) {
			creating_connection <- true;
			origin_creation<- true;
		}
	}
	
	action create_connection_meso {
		ask (mesoCell closest_to #user_location) {
			creating_connection <- true;
			origin_creation<- true;
		}
	}  
	action activateMacro {
		if (creating_connection) {
			macroCell dest <- (macroCell closest_to  #user_location);
			macroCell ori <- macroCell first_with each.origin_creation;
			if (dest != ori) {
				create macroConnection with: [shape::line([ori, dest])];
				dest.connectedCells << ori;
				ori.connectedCells << dest;
			} 
			creating_connection <- false;
			ori.origin_creation <- false;
			if (currentMacro != nil) {
				ask macroCell(currentMacro) {
					do generate_meso_connexions;
				}
			}
			
		} else {
			currentMacro_tmp <- (macroCell closest_to  #user_location);
		}
	}	
	action activateMeso {
		if (creating_connection) {
			mesoCell dest <- (mesoCell closest_to  #user_location);
			mesoCell ori <- mesoCell first_with each.origin_creation;
			if (dest != ori) {
				ask macroCell(currentMacro) {
					buildMesoConnexions<< pair(ori.location::dest.location);
					do generate_meso_connexions;
				}
				
			} 
			creating_connection <- false;
			ori.origin_creation <- false;
			
		} else {
			currentMeso_tmp <- (mesoCell closest_to #user_location);
		}
	}	
	
	action clean_people_road {
		ask people {do die;}
		ask road {do die;}
		
	}
	
	int nb_per_types(string ty, float w, float h) {
		return round(w/#km * h/#km * densityPeoplePerType[ty]);
	}
	
	int compute_nb_meso_habitants(string t) {
		int nb_cells <- nbCellsHeight * nbCellsWidth;
		list<int> prop <- mesoCellsProportions[t];
		int tot <- sum(prop);
		
		int nb <- 0;
		loop tt over: densityPeoplePerType.keys {
			nb <- nb + int(world.nb_per_types(tt, macroCellWidth/nbCellsWidth/nbCellsWidth, macroCellHeight / nbCellsHeight / nbCellsHeight) * nb_cells * prop[microCellsTypes index_of tt]/ tot);
		}	
		return nb;
	}
}

species cells parent: poi{
	int level;
	int index;
	string type; 
	float seed;
	float width;
	float height;
	int nbInhabitants;
	map<cells, int> visitors;
	cells currentSelectedCell;
	changeLog log;
	cells parentCell;
	map<list<int>,string> changeLog2 <- [];
	bool origin_creation <- false;
	rgb color <- rnd_color(255);
	int nb_cycles_returning;
	int nb_cycles_moving;
	list<cells> connectedCells;
	
	//for RNG
	float value;

	reflex peopleMoving when: (level < 2) and every(nb_cycles_moving #cycle) and not empty(connectedCells) {
		map<string, float> prop_to_move_to <- level = 0 ?prop_macro_to_move_to :prop_meso_to_move_to;
		ask connectedCells{
			int nb <- int(nbInhabitants * prop_to_move_to[type] );
			visitors[myself] <- visitors[myself] + nb  ;
			myself.nbInhabitants <- myself.nbInhabitants - nb;
		}
		if (level = 0 and currentMacro != nil) {
			ask macroCell(currentMacro) {
				do distribute_visitors; 
			}
		}
	}
	
	reflex peopleComingBack when: (level < 2) and every(nb_cycles_returning #cycle){
		loop v over: visitors.keys where (each.level = level) {
			int nb <- int(visitors[v] * prop_returning);
			visitors[v] <- visitors[v] - nb;
			v.nbInhabitants <- v.nbInhabitants + nb;
			if (level = 1 and not empty(people) and nb > 0) {
				ask nb among (people where (each.visitor_ori = v)) {
					do die;
				}
			}
		}
		if (level = 0 and currentMacro != nil) {
			ask macroCell(currentMacro) {
				do distribute_visitors; 
			}
		}
	}
	
	int rand(int n){
		value <- a*value+c;
		value <- value - floor(value/m)*m;
		return floor(value/m * n);
	}
	
	action reset_RNG{
		value <- seed;
	}

	action populateParentChangeLog{
		if parentCell != nil{
			if parentCell.log = nil{
				create changeLog{
					myself.parentCell.log <- self;
				}
			}
			add log at: index to: parentCell.log.childrenLogs; 
			ask parentCell {
				do populateParentChangeLog;
			}
		}
	}
	
	action addToLog(string s){
		if log = nil{
			create changeLog{
				myself.log <- self;
			}
		}
		add s at: index to: log.mainLog;
		do populateParentChangeLog;
		

	}
	
	
	action clean{
		if log != nil and length(log.mainLog) = 0 and length(log.childrenLogs) = 0 {
			ask log {
				do die;
			}
		}
		do die;
	}
	
	aspect macro{
		if (self = currentMacro) {
			draw rectangle(width,height) color:#magenta;
			draw rectangle(width * 0.8,height * 0.8) color: macroCellsColors[type] depth: 1;
		} else {
			draw rectangle(width,height) color: macroCellsColors[type] border:macroCellsColors[type]+25;
		}
		if (origin_creation) {
			draw triangle(width * 0.5) color: #pink border: #black depth: 1.5;
		}
		
		
	}
	
	aspect meso{
		float w <- building_scale * width;
		float h <- building_scale * height;
		
		if (self = currentMeso) {
			draw rectangle(w,h) color:#magenta;
			draw rectangle(w* 0.8,h* 0.8) color:mesoCellsColors[type] depth: 1;
		} else {
			draw rectangle(w,h) color:mesoCellsColors[type];
		}
		if (origin_creation) {
			draw triangle(w * 0.5) color: #pink border: #black depth: 1.5;
		}
	}
	
	aspect micro{
		draw rectangle(width * building_scale,height * building_scale) color: microCellsColors[type];
		
	}
	
	aspect macroTable{
		draw rectangle(width,height) depth:nbInhabitants /1 color:macroCellsColors[type] border:macroCellsColors[type]+25;
		float d <- nbInhabitants/1.0;
		loop v over: visitors.keys {
			float nb <- visitors[v]*1.0;
			draw box(width* 0.8,height * 0.8,nb) at: location + {0,0,d} color:v.color border:#black;
			d <- d + nb;
		}
		
	}
	
	aspect mesoTable{
		draw rectangle(width*nbCellsWidth * building_scale,height*nbCellsHeight* building_scale) depth:nbInhabitants * 10.0 color:mesoCellsColors[type] border:mesoCellsColors[type]+25 at:{world.shape.width*2+(location.x-currentMacro.location.x)*nbCellsWidth,world.shape.height/2+(location.y-currentMacro.location.y)*nbCellsHeight};
		int d <- nbInhabitants * 10;
		list<cells> vs <-  visitors.keys sort_by each.level;
		loop v over: vs {
			float sc <- v.level = 0 ? 0.8 : 0.5;
			int nb <- visitors[v] * 10;
			draw box(width*nbCellsWidth * building_scale * sc,height*nbCellsHeight* building_scale *sc,nb) at:{world.shape.width*2+(location.x-currentMacro.location.x)*nbCellsWidth,world.shape.height/2+(location.y-currentMacro.location.y)*nbCellsHeight,d} color:v.color border:#black;
			d <- d + nb;
		}
	}

	aspect microTable{
		draw rectangle(width*nbCellsWidth*nbCellsWidth*building_scale,height*nbCellsHeight*nbCellsHeight* building_scale) depth:nbInhabitants color:microCellsColors[type] border:microCellsColors[type]-25 at:{world.shape.width*3.5+(location.x-currentMeso.location.x)*nbCellsWidth*nbCellsWidth,world.shape.height/2+(location.y-currentMeso.location.y)*nbCellsHeight*nbCellsHeight};
	}
	
}

species connection{
	string type;
	cells source;
	cells destination;
	rgb color <- #black;
	float coeff <- 1.0;
	aspect default {
		draw shape + (line_width * coeff) color: color ;
	}
}

species macroConnection parent: connection{
	float coeff <- 1.0 #km;
}

species mesoConnection parent: connection{
	float coeff <- 0.1 #km;
	rgb color <- #red;
	macroConnection myMacroConnection;
}


species macroCell parent: cells{
	int level <- 0;
	user_command "generate Meso"action: generateMeso;
	user_command "save State"action: saveState;
	user_command "City"action: modifyToCity;
	user_command "Village"action: modifyToVillage;
	user_command "Park"action: modifyToPark;
	user_command "Lake"action: modifyToLake;
	int index -> int(self) - int(first(macroCell));
	list<pair<point,point>> buildMesoConnexions;
	
	int nb_cycles_returning <- 20;
	int nb_cycles_moving <- 200;
	
	
	
	action generateMeso{
		ask world{do clean_people_road;}
		currentMacro<-self;
		
		ask mesoCell{
			do clean;
		}
		ask microCell{
			do clean;
		}
		do reset_RNG;
		loop i from: 0 to: nbCellsWidth-1{
			loop j from:0 to:nbCellsHeight-1{
				create mesoCell{
					width<-myself.width/nbCellsWidth;
					height<-myself.height/nbCellsHeight;
					location<-{myself.location.x-myself.width/2+width*i+width/2,myself.location.y-myself.height/2+height*j+height/2};
					type <- myself.affectMesoCellType();
					parentCell <- myself;
					seed <- float(myself.rand(1000000));
				}
			}
		}
		do applyChanges;
		do init_nb_habitants_meso;
		do generate_meso_connexions;
		
	}
	action distribute_visitors {
		map<mesoCell,float> propCells;
		float sumProp;
		ask mesoCell {
			float prop <- prop_meso_to_move_to[type];
			sumProp <- sumProp + prop;
			propCells[self] <- prop;
		}
		ask propCells.keys {
			propCells[self] <- propCells[self]/sumProp;
			map<cells, int> visitors_tmp;
			loop v over: visitors.keys {
				if (v.level != 0) {
					visitors_tmp[v] <-  visitors[v];
				}
			}
			visitors <- visitors_tmp;
	
		}
		loop ori over: visitors.keys {
			int nbV <- visitors[ori];
			loop ce over:propCells.keys {
				int n <- round(propCells[ce] * nbV);
				if (n > 0) {
					ce.visitors[ori] <- ce.visitors[ori] + n;
				}
				
			}	
		}
		
	}
	
	action compute_nb_meso_habitants {
		ask mesoCell {
			nbInhabitants <- world.compute_nb_meso_habitants(type);
		}
	}
	action init_nb_habitants_meso {
		do compute_nb_meso_habitants;
		do distribute_visitors;
		
	}
	
	action generate_meso_connexions {
		ask mesoConnection {
			do die;
		}
		geometry s <- rectangle(width,height);
		list<macroConnection> mcs <- macroConnection overlapping s;
		
		if(not empty(mcs) or not empty(buildMesoConnexions)) {
			graph g <- generate_basic_graph(s);
			if (not empty(mcs)) {
				list<geometry> lines <- [];
				map<geometry, macroConnection> linkToMacro;
				loop mc over: mcs {
					list<geometry> ls <- generate_lines(mc, s, g);
					loop l over: ls {
						linkToMacro[l] <- mc;
					}
					lines <- lines + ls;
				}
				lines <- remove_duplicates(lines);
				create mesoConnection from: lines {
					myMacroConnection <- linkToMacro[shape];
				}
			}
			loop p over: buildMesoConnexions {
				path the_path <- g path_between(p.key, p.value);
				if (the_path != nil ) {
					create mesoConnection from: the_path.edges ;
				}
			}
			do connect_meso_cells;
			
		} 
	}
	
	action connect_meso_cells {
		ask mesoCell {
			connectedCells <- [];
		}
		float dist <- sqrt((macroCellWidth/nbCellsWidth) ^2 + (macroCellHeight/nbCellsHeight)^2)  * 1.1;
			
		if (neighbors_connection) {
			float dist <- sqrt((macroCellWidth/nbCellsWidth) ^2 + (macroCellHeight/nbCellsHeight)^2)  * 1.1;
			ask mesoCell {
				connectedCells <- mesoCell at_distance dist;
			}
			
		}
		graph the_graph <- as_edge_graph(mesoConnection);
		map<point,list<mesoCell>> connections;
		dist <- dist / 2.0;
		loop v over: the_graph.vertices {
			connections[v.location] <- mesoCell where (each distance_to v < dist);
		} 
		list<list> connected_components <- connected_components_of(the_graph, false);
		loop cc over: connected_components {
			list<mesoCell> ms <- remove_duplicates(cc accumulate connections[geometry(each).location]);
			ask ms {
				connectedCells <- copy(neighbors_connection ? remove_duplicates(ms + connectedCells): ms );
				connectedCells >> self;
			}
		}
	}
	
	graph generate_basic_graph (geometry bounds_g){
		list<geometry> lines;
		float w <- width/nbCellsWidth;
		float h <- height/nbCellsHeight;
		float min_x <- bounds_g.points min_of each.x;
		float min_y <- bounds_g.points min_of each.y;
		loop i from: 0 to: nbCellsWidth {
				lines << line([{i*w+ min_x,min_y}, {i*w+min_x,height+min_y}]);
			}
		loop i from: 0 to: nbCellsHeight {
			lines << line([{min_x, i*h+min_y}, {width+ min_x,i*h+min_y}]);
		}
		lines <- split_lines(lines);
		graph g <- as_edge_graph(lines);
		return g;
		
	}
	
	
	list<geometry> generate_lines(macroConnection mc, geometry bounds_g, graph g) {
		geometry ov <- mc inter bounds_g;
		point origin <- first(ov.points);
		point dest <- last(ov.points);
		path p <- g path_between(origin, dest);
		if (p != nil ) {
			return p.edges;
		}
		return [];
	}
	
	action applyChanges{
		if log != nil{
			loop k over: log.mainLog.keys{
				mesoCell cell <- first(mesoCell where (int(each)-int(first(mesoCell))= k));
				cell.type <- log.mainLog[k];
			}
			loop k over: log.childrenLogs.keys{
				mesoCell cell <- first(mesoCell where (int(each)-int(first(mesoCell))= k));
				cell.log <- log.childrenLogs[k];
			}
		}
	}
	
	string affectMesoCellType {
		int total <- sum(macroCellsProportions[type]);
		int ind <- rand(total);
		int cumul <- macroCellsProportions[type][0];
		int currentType <- 0;
		loop  while: (ind >= cumul) {
			currentType <- currentType + 1;
			cumul <- cumul + macroCellsProportions[type][currentType]; 
		}
		return mesoCellsTypes[currentType];
	}
	
	
	action saveState{
		list<int> newProportions <- [];
		loop mesoType over: mesoCellsTypes{
			newProportions << (mesoCell count (each.type = mesoType));
		}
		put newProportions at: currentMacro.type in: macroCellsProportions;
	}
	
	action modifyToCity{
		type<-macroCellsTypes[0];
		do generateMeso;
	}
	action modifyToVillage{
		type<-macroCellsTypes[1];
		do generateMeso;
	}
	action modifyToPark{
		type<-macroCellsTypes[2];
		do generateMeso;
	}
	action modifyToLake{
		type<-macroCellsTypes[3];
		do generateMeso;
	}
	
	
	user_command create_connection {
		creating_connection <- true;
		origin_creation<- true;
		
	}
}

species mesoCell parent:cells{
	int level <- 1;
	int index -> int(self) - int(first(mesoCell));
	
	user_command "generate Micro"action: generateMicro;
	user_command "save Macro State"action: saveMacroState;
	user_command "Residential"action: modifyToResidential;
	user_command "Commercial"action: modifyToCommercial;
	user_command "Industrial"action: modifyToIndustrial;
	user_command "Educational"action: modifyToEducational;
	user_command "Park"action: modifyToPark;
	user_command "Lake"action: modifyToLake;
	
	user_command "Local Residential"action: localModifyToResidential;
	user_command "Local Commercial"action: localModifyToCommercial;
	user_command "Local Industrial"action: localModifyToIndustrial;
	user_command "Local Educational"action: localModifyToEducational;
	user_command "Local Park"action: localModifyToPark;
	user_command "Local Lake"action: localModifyToLake;

		
	int nb_cycles_returning <- 5;
	int nb_cycles_moving <- 50;
	
	macroCell parentCell;
	
	
	
	action generateMicro {
		block_size <- min([width/nbCellsWidth,height/nbCellsHeight]);
		ask world{do clean_people_road;}
		currentMeso<-self;
		ask microCell{
			do clean;
		}
		do reset_RNG;
		loop i from: 0 to: nbCellsWidth-1{
			loop j from:0 to:nbCellsHeight-1{
				create microCell{
					width<-myself.width/nbCellsWidth;
					height<-myself.height/nbCellsHeight;
					location<-{myself.location.x-myself.width/2+width*i+width/2,myself.location.y-myself.height/2+height*j+height/2};
					type <- myself.affectMicroCellType();
					parentCell <- myself;	
					seed <- float(myself.rand(1000000));
					
				}
			}
		}
		do generate_road;
		do applyChanges;
		mesoCell the_meso_cell <- self;
		ask microCell {
			nbInhabitants <- world.nb_per_types(type,width,height);
			create people number: nbInhabitants with: [location::location]{
				origin <- myself;
				visitor_ori <- the_meso_cell;
				color <- visitor_ori.color;
				list_of_people << self;
				do reinit_destination;
				map<profile, float> prof_pro <- proportions_per_bd_type[one_of(proportions_per_bd_type.keys)];
				my_profile <- prof_pro.keys[rnd_choice(prof_pro.values)];
			}
		}
		
		loop ori over: visitors.keys {
			int nbV <- visitors[ori];
			loop times: nbV {
				create people  {
					origin <- one_of(microCell);
					location<- origin.location;
					list_of_people << self;
					visitor_level <- ori.level;
					visitor_ori <- ori;
					color <- visitor_ori.color;
					list_of_people << self;
					do reinit_destination;
					map<profile, float> prof_pro <- proportions_per_bd_type[one_of(proportions_per_bd_type.keys)];
					my_profile <- prof_pro.keys[rnd_choice(prof_pro.values)];
				}
			}
		}
		
		
		
	}

	
	
	
	action generate_road {
		geometry s <- rectangle(width,height);
		list<geometry> lines;
		float w <- width/nbCellsWidth;
		float h <- height/nbCellsHeight;
		float min_x <- s.points min_of each.x;
		float min_y <- s.points min_of each.y;
		loop i from: 0 to: nbCellsWidth {
				lines << line([{i*w+ min_x,min_y}, {i*w+min_x,height+min_y}]);
			}
		loop i from: 0 to: nbCellsHeight {
			lines << line([{min_x, i*h+min_y}, {width+ min_x,i*h+min_y}]);
		}
		create road from: split_lines(lines) {
			create road with: [shape:: line(reverse(shape.points))];
		}
		ask world {do update_graphs;}
		
		
	}
	action applyChanges{
		if log != nil{
			loop k over: log.mainLog.keys{
				microCell cell <- first(microCell where (int(each)-int(first(microCell))= k));
				cell.type <- log.mainLog[k];
			}
		}
	}
	
	action saveMacroState{
		ask parentCell{
			do saveState;
		}
	}
	action saveState{
		list<int> newProportions <- [];
		loop microType over: microCellsTypes{
			newProportions << (microCell count (each.type = microType));
		}
		put newProportions at: currentMeso.type in: mesoCellsProportions;
	}
	action modifyToResidential{
		type<-mesoCellsTypes[0];
		do generateMicro;
	}
	action modifyToCommercial{
		type<-mesoCellsTypes[1];
		do generateMicro;
	}
	action modifyToIndustrial{
		type<-mesoCellsTypes[2];
		do generateMicro;
	}
	action modifyToEducational{
		type<-mesoCellsTypes[3];
		do generateMicro;
	}
	action modifyToPark{
		type<-mesoCellsTypes[4];
		do generateMicro;
	}
	action modifyToLake{
		type<-mesoCellsTypes[5];
		do generateMicro;
	}
	
	action localModifyToResidential{
		type<-mesoCellsTypes[0];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToCommercial{
		type<-mesoCellsTypes[1];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToIndustrial{
		type<-mesoCellsTypes[2];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToEducational{
		type<-mesoCellsTypes[3];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToPark{
		type<-mesoCellsTypes[4];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToLake{
		type<-mesoCellsTypes[5];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	
	string affectMicroCellType {
		int total <- sum(mesoCellsProportions[type]);
		int ind <- rand(total);
		int cumul <- mesoCellsProportions[type][0];
		int currentType <- 0;
		loop  while: (ind >= cumul) {
			currentType <- currentType + 1;
			cumul <- cumul + mesoCellsProportions[type][currentType]; 
		}
		return microCellsTypes[currentType];
	}
}

species microCell parent:cells{
	int level <- 2;
	int index -> int(self) - int(first(microCell));
	
	user_command "save Meso State"action: saveMesoState;
	user_command "Residential"action: modifyToResidential;
	user_command "Commercial"action: modifyToCommercial;
	user_command "Industrial"action: modifyToIndustrial;
	user_command "Educational"action: modifyToEducational;
	user_command "Park"action: modifyToPark;
	user_command "Lake"action: modifyToLake;
	
	user_command "Local Residential"action: localModifyToResidential;
	user_command "Local Commercial"action: localModifyToCommercial;
	user_command "Local Industrial"action: localModifyToIndustrial;
	user_command "Local Educational"action: localModifyToEducational;
	user_command "Local Park"action: localModifyToPark;
	user_command "Local Lake"action: localModifyToLake;
	
	mesoCell parentCell;
	
	action initialize {
		bounds <- rectangle(width,height) ;
	}
	action saveMesoState{
		ask parentCell{
			do saveState;
		}
	}
	action modifyToResidential{
		type<-microCellsTypes[0];
	}
	action modifyToCommercial{
		type<-microCellsTypes[1];
	}
	action modifyToIndustrial{
		type<-microCellsTypes[2];
	}
	action modifyToEducational{
		type<-microCellsTypes[3];
	}
	action modifyToPark{
		type<-microCellsTypes[4];
	}
	action modifyToLake{
		type<-microCellsTypes[5];
	}
	
	action localModifyToResidential{
		type<-microCellsTypes[0];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToCommercial{
		type<-microCellsTypes[1];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToIndustrial{
		type<-microCellsTypes[2];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToEducational{
		type<-microCellsTypes[3];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToPark{
		type<-microCellsTypes[4];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	action localModifyToLake{
		type<-microCellsTypes[5];
		ask parentCell {
			do addToLog(myself.type);
		}
	}
	
}

species changeLog{
	map<int, string> mainLog <- [];
	map<int, changeLog> childrenLogs <- [];
//	cells c;
}



species people parent: basic_people skills: [moving]{
	int visitor_level <- -1;
	cells visitor_ori;
	action reinit_destination {
		dest <-one_of(microCell);
		target <- nil;
	}
	
	
}
experiment REGICID autorun: true{
	float minimum_cycle_duration <- 0.05;
	output{

		layout vertical([horizontal([0::3863,horizontal([1::5000,2::5000])::6137])::3362,3::6638])  ;
		//editors: false toolbars: false tabs: false parameters: false consoles: false navigator: false controls: false tray: false;
		

		display macro  type:opengl draw_env:false camera_interaction:false{
			species macroCell aspect:macro;
			species macroConnection;
			event mouse_down action: activateMacro; 
			event "r" action: create_connection_macro; 
			
				
		}
		display meso type:opengl draw_env:false  camera_interaction:false camera_pos:  currentMacro = nil ?  {world.location.x, world.location.y, world.shape.width/(nbCellsWidth*0.8)} : {currentMacro.location.x, currentMacro.location.y, world.shape.width/(nbCellsWidth*0.8)} camera_look_pos:  currentMacro = nil ? world.location :{currentMacro.location.x, currentMacro.location.y, 0} camera_up_vector: {0.0, 1.0, 0.0}{
			species mesoCell aspect:meso;
			species mesoConnection;
			event mouse_down action: activateMeso; 	
			event "r" action: create_connection_meso; 		
		}

		display micro type:opengl synchronized: true draw_env:false z_near: world.shape.width / 1000  camera_interaction:false camera_pos: currentMeso = nil ? {world.location.x, world.location.y, world.shape.width/((nbCellsWidth*0.8)*(nbCellsWidth*0.8))} : {currentMeso.location.x, currentMeso.location.y, world.shape.width/((nbCellsWidth*0.8)*(nbCellsWidth*0.8))} camera_look_pos:  currentMeso = nil ? world.location : {currentMeso.location.x, currentMeso.location.y, 0} camera_up_vector: {0.0, 1.0, 0.0}{
			species microCell aspect:micro;
			species road ;
			species people;	 
			
		}
		
		display table type:opengl background:#white draw_env:true  camera_pos: {1848.6801 * 100,2083.7744 * 100,2369.1066 * 150} camera_look_pos: {1848.6801 * 100,547.195 * 100,3.0723 * 150} camera_up_vector: {0.0,0.8387,0.5447}
		{
			species macroCell aspect:macroTable;
			species mesoCell aspect:mesoTable;
			species microCell aspect:microTable;
			graphics 'table'{
				draw box(nbCellsWidth*macroCellWidth,nbCellsHeight*macroCellHeight,world.shape.width*0.25) color:#black at:{world.shape.width/2,world.shape.height/2,-world.shape.width*0.26} empty:true;
				draw box(nbCellsWidth*macroCellWidth,nbCellsHeight*macroCellHeight,world.shape.width*0.25) color:#black at:{world.shape.width*2,world.shape.height/2,-world.shape.width*0.26} empty:true;
				draw box(nbCellsWidth*macroCellWidth,nbCellsHeight*macroCellHeight,world.shape.width*0.25) color:#black at:{world.shape.width*3.5,world.shape.height/2,-world.shape.width*0.26} empty:true;
			}
			graphics "text" {
				draw rectangle(525#px,525#px) rotated_by (89,{1,0,0}) color:#black  at: {world.shape.width*2, -world.shape.width*0.11,world.shape.width} ;
				draw rectangle(500#px,500#px) rotated_by (89,{1,0,0}) texture:[imageRaster.path] at: {world.shape.width*2, -world.shape.width*0.1,world.shape.width};
			} 
		}
	}
	
}