
class knob 
{
  float radius;
  float xpos; 
  float ypos ; 
  float angle, angle_new;
  float cvalue;
  int   id;
  PGraphics g;
  float dpos;
  boolean dirty = true;
  int next;


  knob(float x, float y, float r, float a, int name) {
    xpos = x;
    ypos = y;
    radius = r;
    angle = a;
    angle_new = a;
    id = name;
    dpos = 0;
    cvalue = 0;
    g = createGraphics(200, 30, P2D);
    //g.smooth();
    //g.fill(255);
    g.textFont(font0);
    //g.textFont(font1);
  }

  void zero() {
    angle = -HALF_PI;
    dpos = 0;
    dirty = true;
  }

  float getcvalue() {
    return(cvalue);
  }

  float getdpos() {
    return(dpos);
  }

  void incdpos(float delta) {
    dpos += delta;
    cvalue = dpos*motor_gain[id];
    dirty = true;
    knob_snd(id, (long)dpos);
  }

  void setdpos(float newpos) {
    dpos = newpos;
    cvalue = dpos*motor_gain[id];
    dirty = true;

    knob_snd(id, (long)dpos);
  }

  void rotate(float dth) {
    float th;

    if (true) {

      switch(mode) {

      case 0:  // normal
        dpos += round(dth * mstep[vel][id]);
        cvalue = dpos*motor_gain[id];
        dirty = true;
        knob_snd(id, (long)dpos);


        break;

      case 1:  // rotate

        switch(id) {
        case Y:
        case A:
          dpos += round(dth * mstep[vel][id]);
          cvalue = dpos*motor_gain[id];
          dirty = true;
          knob_snd(id, (long)dpos);

          break;

        case Z:

          th = knobs[A].getcvalue();

          dpos += dth * mstep[vel][id] * cos(radians(-th));
          knob_snd(id, (long)dpos);
          knobs[motoridx[X]].incdpos((dth * mstep[vel][id] * motor_gain[Z]/motor_gain[X] * sin(radians(-th))));

          dirty = true;
          break;

        case X:
          th = knobs[A].getcvalue();

          dpos += dth * mstep[vel][id] * cos(radians(-th));
          knob_snd(id, (long)dpos);
          knobs[motoridx[Z]].incdpos((dth * mstep[vel][id] * motor_gain[X]/motor_gain[Z] * sin(radians(th))));

          dirty = true;
          break;
        }

        break;
      }
    }
  }

  void makedirty() {
    dirty = true;
  }

  float dist(float x, float y) {

    float dist;
    dist = (float)(sqrt((xpos-x)*(xpos-x)+(ypos-y)*(ypos-y))) / radius;

    return(dist);
  }

  void display() {

    if (mode != 2) {

      if (mousePressed && dist(mouseX, mouseY)<1) {
        this.rotate(gain*(mouseX-xpos)/radius);
      };

      if (dirty) {

        color tor = color(255,100,100);
        color frombg = color(100,100,100); 
        color tob = color(100,100,255);
        noStroke();
        for (float r = 1; r>=0.05; r -= 0.05) {
          fill(lerpColor(frombg,tor,r));
          arc(xpos, ypos, 2*radius*r, 2*radius*r, -HALF_PI, HALF_PI, PIE);
          fill(lerpColor(frombg,tob,r));
          arc(xpos, ypos, 2*radius*r, 2*radius*r, HALF_PI, 3*PI/2, PIE);
        }
        stroke(0);

        g.beginDraw();
        g.background(0);
        g.fill(255);
        g.textSize(16);
        g.textAlign(CENTER, CENTER);
        //g.textFont(font1);
        cvalue = dpos*motor_gain[id];
        if (id!=3)
          g.text(axes[id] + nfp(cvalue, 4, 1) + " um", 100, 15);
        else
          g.text(axes[id] + nfp(cvalue, 2, 2) + " deg", 100, 15);
        g.endDraw();
        image(g, xpos-100, 25/2);

        dirty = false;
      }
    } else {

      fill(255, 100, 100);
      arc(xpos, ypos, 2*radius, 2*radius, -HALF_PI, HALF_PI, PIE);
      fill(100, 100, 255);
      arc(xpos, ypos, 2*radius, 2*radius, HALF_PI, 3*PI/2, PIE);        

      float dist = (float)(sqrt((xpos-mouseX)*(xpos-mouseX)+(ypos-mouseY)*(ypos-mouseY)));

      if (!dirty && mousePressed && dist<radius) {
        if (mouseX-xpos>0) 
          speed_snd(id, 1);
        else 
        speed_snd(id, -1);
        dirty = true;
      }

      if (dirty && !mousePressed) {
        speed_snd(id, 0);
        dirty = false;
      }
    }
  }
}