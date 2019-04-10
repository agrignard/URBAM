import processing.serial.*;

import cc.arduino.*;

Arduino arduino;

//float floatVal;

void getValue() {
  
  if (myPort.available() > 0) {
    
    val = myPort.readStringUntil('\n');
    //println(myPort.read());
    //println(myPort.readStringUntil('\n'));
    println(val);

    
    //if (val != null){
    //floatVal = Float.parseFloat(val.trim());  
    //println(floatVal);
    //} 
  }
}
