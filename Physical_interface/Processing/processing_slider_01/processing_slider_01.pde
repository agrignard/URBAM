
/* /////////////////////////////////////
  April, 2019
  Gabriela Bila
  Reading serial port from Arduino at Processing
*/ /////////////////////////////////////


//conect to Arduino
import processing.serial.*;
Serial myPort; 
String val; // variable that is passed from processing to arduino

void settings() {
  
}


void setup() {
  // Set the COM Port
  String portName = Serial.list()[3]; ///*** change the port and CLOSE arduino serial monitor
  myPort = new Serial(this, portName, 74880); 
}

void draw() { 
  getValue();
}
