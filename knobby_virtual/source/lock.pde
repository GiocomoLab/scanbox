
class lock 
{
  int   state;
  float xpos; 
  float ypos ; 
  boolean dirty;

  lock(float x, float y) {
    xpos = x;
    ypos = y;
    state = 1;
    dirty = true;
  }
  
  int getstate() {
    return(state);
  }
  

  float dist(float x, float y) {
    float dist = (float)(sqrt((xpos-x)*(xpos-x)+(ypos-y)*(ypos-y)));
    return dist;
  }

  void display() {
    
    if (!dirty && mousePressed && dist(mouseX, mouseY)<35/2) {
      state = 1-state;
      dirty = true;
    } 
    
    if (!mousePressed && dirty) {
      if (state==0) fill(color(0, 65, 0)); 
      else fill(color(0, 180, 0));
      stroke(255);
      ellipse(xpos, ypos, 80/2, 80/2);
      stroke(0);
      dirty = false;
    }
    
  }
}