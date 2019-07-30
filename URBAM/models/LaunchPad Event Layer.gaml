/**
* Name: Launch Pad Event Feature
* Author: Arnaud Grignard 
* Description: Model which shows how to use the event layer to trigger an action with a LaunchPad Novation (This model only work with the launchpad plugins extension available in GAMA 1.7 since January 2018)
* Tags: tangible interface, gui, launchpad
 */
model event_layer_model

global skills:[launchpadskill]
{
	map<int,string> buttontypeColorMap <-[1::"red",2::"orange",3::"brown",4::"yellow",5::"lightyellow",6::"green",7::"darkgreen",8::"black"];
	map<string,int> function_id_map <-["UP"::buttontypeColorMap.keys[0],"DOWN"::buttontypeColorMap.keys[1],"LEFT"::buttontypeColorMap.keys[2],"RIGHT"::buttontypeColorMap.keys[3],"SESSION"::buttontypeColorMap.keys[4],"USER_1"::buttontypeColorMap.keys[5],"USER_2"::buttontypeColorMap.keys[6],"MIXER"::buttontypeColorMap.keys[7]];
	map<string,string> function_color_map <-["UP"::buttontypeColorMap.values[0],"DOWN"::buttontypeColorMap.values[1],"LEFT"::buttontypeColorMap.values[2],"RIGHT"::buttontypeColorMap.values[3],"SESSION"::buttontypeColorMap.values[4],"USER_1"::buttontypeColorMap.values[5],"USER_2"::buttontypeColorMap.values[6],"MIXER"::buttontypeColorMap.values[7]];
	string cityIOurl <-"https://cityio.media.mit.edu/api/table/virtual_table"; 
	string VIRTUAL_LOCAL_DATA <- "./../includes/virtual_table.json";
	map<string, unknown> inputMatrixData;
    map<string, unknown> outputMatrixData;
	init{
	  do resetPad;
	  do setButtonLight colors:buttontypeColorMap.values;
	  try {
			inputMatrixData <- json_file(cityIOurl).contents;
		}
		catch {
			write #current_error + " Impossible to read from cityIO  - Connection to Internet lost or cityIO is offline - inputMatrixData is a local version from cityIO_Kendall.json";
		}	
	}
	
	action updateGrid
	{   
		if(function_color_map.keys contains buttonPressed and buttonPressed != "MIXER"){
		    ask launchpadGrid[ int(padPressed.y *8 + padPressed.x)]{
		    	type<-function_id_map[buttonPressed];
		    	color <- rgb(function_color_map[buttonPressed]);
		    }
		    do setPadLight color:function_color_map[buttonPressed];
		}
		if(buttonPressed = "MIXER"){
			ask launchpadGrid[ int(padPressed.y *8 + padPressed.x)]{
				color <- #white;
			}
		}			
		if(buttonPressed="ARM"){
			do resetPad;
			do setButtonLight colors:buttontypeColorMap.values;	
			ask launchpadGrid{
				type<-function_id_map[buttonPressed];
				color<-#white;
			}
		}
		do updateDisplay;
		do pushGrid(inputMatrixData);
	}
	
	
	action pushGrid(map<string, unknown> _matrixData){
	  outputMatrixData <- _matrixData;
	  map(outputMatrixData["header"])["name"]<-"Launchpad";
	  map(outputMatrixData["header"]["owner"])["institute"]<-"Gama Platform";
	  map(outputMatrixData["header"]["owner"])["name"]<-"Arnaud Grignard Launchpad Test";
	  map(outputMatrixData["header"]["spatial"])["longitude"]<-105.84;
	  map(outputMatrixData["header"]["spatial"])["latitude"]<-21.02;
	  map(outputMatrixData["header"]["spatial"])["ncols"]<-8;
	  map(outputMatrixData["header"]["spatial"])["nrows"]<-8;
	  map(outputMatrixData["header"]["spatial"])["physical_longitude"]<-105.84;
	  map(outputMatrixData["header"]["spatial"])["physical_latitude"]<-21.02;
	  list<list<int>> cellList;
	  

	  loop i from: 0 to: 7 {
			loop j from: 0 to: 7{
				list tmpList;
				launchpadGrid cell <- launchpadGrid grid_at { j, i };
				tmpList<<cell.type;
				tmpList<<0;//rotation
				cellList<<tmpList;
			}
      }
      outputMatrixData["grid"]<-cellList;
	  
	  try{
	    save(json_file("https://cityio.media.mit.edu/api/table/update/launchpad", outputMatrixData));		
	  }catch{
	  	  write #current_error + " Impossible to write to cityIO - Connection to Internet lost or cityIO is offline";	
	  } 
	}
	
	reflex updateGrid when: (cycle mod 100 = 0){
		  do pushGrid(inputMatrixData);	
 	}	
}

grid launchpadGrid width: 8 height: 8{
	int type;
}

experiment Displays type: gui
{
	output
	{
		display View_change_color 
		{
			grid launchpadGrid lines: #black;
			event "pad_down" type: "launchpad" action: updateGrid;
		}
	}
}