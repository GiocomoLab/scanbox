
class selector 
{
  String caption;
  float xpos; 
  float ypos ; 
  PGraphics g;
  int value;
  boolean dirty = true;
  color bg = color(0, 0, 255);
  boolean active;

  selector(float x, float y, String c, int val, boolean a) {
    xpos = x;
    ypos = y;
    caption = c;
    value = val;
    active = a;
    if (!active) bg = color(0, 0, 255);
    else bg = color(255, 100, 100);

    g = createGraphics(200/2, 50/2, P2D);
    g.smooth();
    g.textFont(createFont("Arial", 12, true));
  }

  boolean isactive() {
    return active;
  }

  void setactive() {
    bg = color(255, 100, 100);
    dirty = true;
    active = true;
  }

  void deactivate() {
    bg = color(0, 0, 255);
    dirty = true;
    active = false;
  }

  float dist(float x, float y) {

    float dist = (float)(sqrt((xpos+100/2-x)*(xpos+100/2-x)+(ypos+25/2-y)*(ypos+25/2-y)));
    return dist;
  }

  void set_background(color c) {
    bg = c;
    dirty = true;
  }

  void display() {

    if (!mousePressed && dirty) {
      g.beginDraw();
      g.background(bg);
      g.fill(255);
      g.textSize(28/2);
      g.textAlign(CENTER, CENTER);
      g.text(caption, 100/2, 25/2);
      g.endDraw();
      image(g, xpos, ypos);
      dirty = false;
    }

    if (!dirty && mousePressed && dist(mouseX, mouseY)<35/2) {
      cmd = value;
      button_snd(caption);
      dirty = true;
    }
  }
}