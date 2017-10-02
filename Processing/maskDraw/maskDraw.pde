import java.util.*;
import processing.serial.*;

class Tuple<X, Y> {
  public final X x;
  public final Y y;

  public Tuple(X x, Y y) {
    this.x = x;
    this.y = y;
  }
}

Vector<Tuple<PVector, PVector>> lines;

Plotter plotter;
Thread plotterThread;

PImage mask;

int lastMouseX = 0;
int lastMouseY = 0;

float lastPlotterX = 0;
float lastPlotterY = 0;
boolean spraying = false;

boolean haveDrawn = false;
boolean leftMask = false;

void setup() {
  size(800, 800);
  //frameRate(10);

  final PApplet that = this;
  ArduinoSelector arduinoSelector = new ArduinoSelector(Serial.list(), new ArduinoSelector.SelectionListener() {
    public void selected(String port) {
      final Serial arduinoPort = new Serial(that, port, 57600);

      plotter.addMessageListener(new Plotter.MessageListener() {
        public void onMessage(int[] message) {
          char cmd = (char)message[0];

          int a = (message[2] << 8) | message[1];
          int b = (message[4] << 8) | message[3];
          int c = (message[6] << 8) | message[5];

          println("Hey, plotter has a message:", cmd, a, b, c);
          for (int i = 0; i < message.length; i++) {
            arduinoPort.write(message[i]);
          }
        }
      });

      (new Thread(new Runnable() {
        public void run() {
          try {
            Thread.sleep(3000);
          } catch (InterruptedException e) {}

          plotterThread = new Thread(plotter);
          plotterThread.start();
        }
      })).start();
    }
  });

  String currentImageName = loadStrings("config.txt")[0];
  mask = loadImage(currentImageName);

  lines = new Vector<Tuple<PVector, PVector>>();

  plotter = new Plotter(Plotter.Tool.AIRBRUSH, 1000, 800);

  registerMethod("dispose", this);
}

String buffer = "";
void serialEvent(Serial port) {
  int c = port.read();
  buffer += (char)c;

  if (buffer.charAt(buffer.length() - 1) == '\n') {
    if (buffer.equals("d\n")) {
      plotter.receiveMessage('d');
    } else {
      print(buffer);
    }

    buffer = "";
  }
}

void dispose() {
  plotter.moveTo(0, 0);
  plotter.stop();

  try {
    plotterThread.join();
  } catch (InterruptedException e) {}

  println("dispose called");
}

enum Tool {
  SOLID,
  DASH,
}
Tool activeTool = Tool.DASH;

float dashSize = 10;
float dashAcc = 0;
boolean dashActive = false;

void moveTo(float x, float y) {
  float plotterX = map(x, 0, width, 0, plotter.getWidthInMM());
  float plotterY = map(y, 0, height, 0, plotter.getHeightInMM());

  if (spraying) {
    if (activeTool == Tool.DASH) {
      while (true) {
        float lineLength = dist(lastPlotterX, lastPlotterY, plotterX, plotterY);

        float lenToNext = dashSize - dashAcc % dashSize;

        if (lenToNext > lineLength) {
          // Line fits inside dash, nothing special to do
          plotter.moveTo(plotterX, plotterY);
          dashAcc += lineLength;
          lastPlotterX = plotterX;
          lastPlotterY = plotterY;
          break;
        } else {
          // There will be at least one transition
          float angle = atan2(plotterY - lastPlotterY, plotterX - lastPlotterX);

          float nx = lastPlotterX + lenToNext * cos(angle);
          float ny = lastPlotterY + lenToNext * sin(angle);

          plotter.moveTo(nx, ny, 0);
          lastPlotterX = nx;
          lastPlotterY = ny;

          dashAcc += lenToNext;
          lenToNext = dashSize - dashAcc % dashSize;

          if (lenToNext < 0) {
            throw new RuntimeException();
          }

          dashActive = !dashActive;
          plotter.spray(dashActive);
        }
      }
    } else {
      plotter.moveTo(plotterX, plotterY, 0);

      lastPlotterX = plotterX;
      lastPlotterY = plotterY;
    }
  } else {
    plotter.moveTo(plotterX, plotterY, 0);

    lastPlotterX = plotterX;
    lastPlotterY = plotterY;
  }
}

/*void moveTo(float x, float y) {
  int plotterX = (int)map(x, 0, width, 0, plotter.getWidthInMM());
  int plotterY = (int)map(y, 0, height, 0, plotter.getHeightInMM());

  if (spraying) {
    float lineLength = dist(lastPlotterX, lastPlotterY, plotterX, plotterY);
    float angle = atan2(plotterY - lastPlotterY, plotterX - lastPlotterX);

    for (float d = 0; d < lineLength - 1;) {
      float remainingDistance = dist(lastPlotterX, lastPlotterY, plotterX, plotterY);
      float segmentLength = min(30, remainingDistance);//random(remainingDistance / 4, remainingDistance);

      int nx = (int)(lastPlotterX + segmentLength * cos(angle));
      int ny = (int)(lastPlotterY + segmentLength * sin(angle));

      plotter.moveTo(nx, ny, random(0, 3));
      d += segmentLength;

      lastPlotterX = nx;
      lastPlotterY = ny;
    }
  } else {
    plotter.moveTo(plotterX, plotterY, 0);

    lastPlotterX = plotterX;
    lastPlotterY = plotterY;
  }
}*/

void draw() {
  background(0);
  image(mask, 0, 0);

  if (mouseX >= 0 && mouseY >= 0 && mouseX < width && mouseY < height) {
    int x = mouseX;
    int y = mouseY;

    if (onMask(mouseX, mouseY, mask)) {
      if (leftMask) {
        // Mouse has entered the mask
        PVector entryPt = lastPointOnMask(x, y, lastMouseX, lastMouseY, mask);
        moveTo(entryPt.x, entryPt.y);
        plotter.spray(true);
        spraying = true;
        moveTo(x, y);
        lines.add(new Tuple<PVector, PVector>(new PVector(entryPt.x, entryPt.y), new PVector(x, y)));
        leftMask = false;
      }

      if (onMask(lastMouseX, lastMouseY, x, y, mask)) {
        moveTo(x, y);
        lines.add(new Tuple<PVector, PVector>(new PVector(lastMouseX, lastMouseY), new PVector(x, y)));
      }
    } else {
      if (leftMask == false) {
        // Last position was on the mask
        PVector exitPt = lastPointOnMask(lastMouseX, lastMouseY, x, y, mask);
        moveTo(exitPt.x, exitPt.y);
        plotter.spray(false);
        spraying = false;

        lines.add(new Tuple<PVector, PVector>(new PVector(lastMouseX, lastMouseY), new PVector(exitPt.x, exitPt.y)));

        leftMask = true;
      }
    }

    lastMouseX = x;
    lastMouseY = y;
  }

  stroke(255);
  synchronized (lines) {
    for (Tuple<PVector, PVector> line : lines) {
      PVector start = line.x;
      PVector end = line.y;

      stroke(255, 0, 0);
      line(start.x, start.y, end.x, end.y);
    }
  }
}

boolean onMask(int x, int y, PImage mask) {
  return brightness(mask.get(x, y)) > 128;
}

boolean onMask(int x0, int y0, int x1, int y1, PImage mask) {
  // delta of exact value and rounded value of the dependant variable
  int d = 0;

  int dy = abs(y1 - y0);
  int dx = abs(x1 - x0);

  int dy2 = (dy << 1); // slope scaling factors to avoid floating
  int dx2 = (dx << 1); // point

  int ix = x0 < x1 ? 1 : -1; // increment direction
  int iy = y0 < y1 ? 1 : -1;

  if (dy <= dx) {
      for (;;) {
          if (brightness(mask.get(x0, y0)) < 128) {
            return false;
          }

          if (x0 == x1)
              break;
          x0 += ix;
          d += dy2;
          if (d > dx) {
              y0 += iy;
              d -= dx2;
          }
      }
  } else {
      for (;;) {
          if (brightness(mask.get(x0, y0)) < 128) {
            return false;
          }

          if (y0 == y1)
              break;
          y0 += iy;
          d += dx2;
          if (d > dy) {
              x0 += ix;
              d -= dy2;
          }
      }
  }

  return true;
}

PVector lastPointOnMask(int x0, int y0, int x1, int y1, PImage mask) {
  // delta of exact value and rounded value of the dependant variable
  int d = 0;

  int dy = abs(y1 - y0);
  int dx = abs(x1 - x0);

  int dy2 = (dy << 1); // slope scaling factors to avoid floating
  int dx2 = (dx << 1); // point

  int ix = x0 < x1 ? 1 : -1; // increment direction
  int iy = y0 < y1 ? 1 : -1;

  int lastX = x0;
  int lastY = y0;

  if (dy <= dx) {
      for (;;) {
          if (brightness(mask.get(x0, y0)) < 128) {
            return new PVector(lastX, lastY);
          }
          lastX = x0;
          lastY = y0;

          if (x0 == x1)
              break;
          x0 += ix;
          d += dy2;
          if (d > dx) {
              y0 += iy;
              d -= dx2;
          }
      }
  } else {
      for (;;) {
          if (brightness(mask.get(x0, y0)) < 128) {
            return new PVector(lastX, lastY);
          }
          lastX = x0;
          lastY = y0;

          if (y0 == y1)
              break;
          y0 += iy;
          d += dx2;
          if (d > dy) {
              x0 += ix;
              d -= dy2;
          }
      }
  }

  return new PVector(x1, y1);
}

void keyPressed() {
  if (key == 'h') {
    plotter.moveTo(0, 0, 0);
  } else if (key == 'p') {
    plotter.moveTo(200, 800);
  }
}