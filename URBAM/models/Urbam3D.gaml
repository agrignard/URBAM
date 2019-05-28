/**
* Name: 3D Mobility
* Author:  Arnaud Grignard
* Description: A 3D Matrix representing building where people can move between level.
* Tags: color, 3d
*/

model bubblesort3D

global {

//Number of cubes by faces of the whole big cube
int nb_cells<-10;
int max_floors<-30;
geometry shape <- box(nb_cells,nb_cells,max_floors) ;

graph<cells,edge_agent> mazeGraph;


init {
	//We create nb_cells^3 cubes and we define their color depending on their position in XYZ
	loop i from:0 to:nb_cells-1{
		loop j from:0 to: nb_cells-1{
			create building{
				location <-{i mod nb_cells,j mod nb_cells};
				floors<-1+rnd(max_floors);
			    loop k from:0 to:floors-1{ 	
			    create cells{
				  location <-{i mod nb_cells,j mod nb_cells, k};
				  myself.myCells<<self;
				  create people number:1{
				  	location <-{i mod nb_cells -0.5 + rnd(150)/100.0,j mod nb_cells -0.5 + rnd(150)/100.0, k + rnd(100)/100.0};
				  	//location <-{i mod nb_cells,j mod nb_cells, k};
				  }
			    }	
			    }
			}
				
	    }
	}
	ask people{
		myTarget<-any_location_in(one_of(cells));
		//myTarget<-any_location_in(one_of(cells where (each.location.z = self.location.z)));
		//myTarget<-{myTarget.x -0.5 + rnd(150)/100.0,myTarget.y -0.5 + rnd(150)/100.0,myTarget.z + rnd(100)/100.0};
	}
	loop i from:0 to:5{
	  graph tmp_mazeGraph <- as_distance_graph((cells where (each.location.z = i)), ["distance"::1.0,"species"::edge_agent]);		
	  /*mazeGraph <- as_distance_graph((cells where (each.location.x = i)), ["distance"::1.0,"species"::edge_agent]);
	  mazeGraph <- as_distance_graph((cells where (each.location.y = i)), ["distance"::1.0,"species"::edge_agent]);
	  mazeGraph <- as_distance_graph((cells where (each.location.z = i)), ["distance"::1.0,"species"::edge_agent]);	*/
	}
	mazeGraph <-as_edge_graph(edge_agent);
	
	/*ask building{
      mazeGraph <- as_distance_graph(myCells, ["distance"::2.0,"species"::edge_agent]);
	}*/
	
}

species building{
	rgb color<- rgb(225,225,225);
	int floors;
	list<cells> myCells;
	
	aspect default{
      draw box(0.5,0.5,floors) color:color border:color at:location;
	}
}

species cells{
	rgb color<- rgb(225,225,225);
	list<cells> neigbhours update: cells at_distance (2.0);
	
	aspect default {
		draw box(0.45,0.45,0.125) color:color border:#black at:location empty:false;
	}
	
	aspect floor {
		draw square(0.45) color:color border:#black at:location empty:false;
	}	
}


species people skills: [moving3D]{ 
	point myTarget;
	reflex goto{
	  	do goto target:myTarget on: mazeGraph speed:0.01 recompute_path:false;
	  	//do wander  on: mazeGraph speed:0.01 ;
	  	//do wander speed:0.01;
	}	
	aspect base{
		draw sphere(0.025) color:rgb(20,20,20);
	}	
}

species edge_agent schedules:[]{
	aspect base {
		draw shape color: rgb(125,125,125);
	}
}

}

experiment Display type: gui {
	output {
		display View1 type:opengl background:rgb(25,25,25) draw_env:false{		
			species people aspect:base;
			species edge_agent aspect:base;
			species cells transparency:0.7;
			species building transparency:0.7;
			
		}
	}
}