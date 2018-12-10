/**
* Name: 3D Mobility
* Author:  Arnaud Grignard
* Description: A 3D Matrix representing building where people can move between level.
* Tags: color, 3d
*/

model bubblesort3D

global {

//Number of cubes by faces of the whole big cube
int nb_cells<-6;

geometry shape <- cube(nb_cells) ;

graph<cells,cells> mazeGraph;


init {
	//We create nb_cells^3 cubes and we define their color depending on their position in XYZ
	loop i from:0 to:nb_cells-1{
		loop j from:0 to: nb_cells-1{
			create building{
				location <-{i mod nb_cells,j mod nb_cells};
				int floors<-1+rnd(5);
			    loop k from:0 to:floors-1{ 	
			    create cells{
				  location <-{i mod nb_cells,j mod nb_cells, k};
				  create people number:10{
				  	//location <-{i mod nb_cells -0.5 + rnd(150)/100.0,j mod nb_cells -0.5 + rnd(150)/100.0, k + rnd(100)/100.0};
				  	location <-{i mod nb_cells,j mod nb_cells, k};
				  }
			    }	
			    }
			}
				
	    }
	}
	ask people{
		myTarget<-any_location_in(one_of(cells));
		//myTarget<-{myTarget.x -0.5 + rnd(150)/100.0,myTarget.y -0.5 + rnd(150)/100.0,myTarget.z + rnd(100)/100.0};
	}
	loop i from:0 to:5{
	mazeGraph <- as_distance_graph((cells where (each.location.z = i)), ["distance"::2.0,"species"::edge_agent]);	
	}
	
}

species building{
	int nbCells;
}

species cells{
	rgb color<- rgb(225,225,225);
	list<cells> neigbhours update: cells at_distance (2.0);
	
	aspect default {
		draw box(0.5,0.5,0.125) color:color border:color at:location empty:false;
	}	
}


species people skills: [moving3D]{ 
	point myTarget;
	reflex goto{
	  	do goto target:myTarget on: mazeGraph speed:0.01;
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
		display View1 type:opengl background:#white{		
			species people aspect:base;
			species edge_agent aspect:base;
			species cells transparency:0.7;
			
		}
	}
}