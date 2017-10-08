import java.util.*;
import processing.serial.*;
import hypermedia.net.*;

class Tuple<X, Y> {
  public final X x;
  public final Y y;

  public Tuple(X x, Y y) {
    this.x = x;
    this.y = y;
  }
}

ViveConnection vive;
int PORT_RX = 8051;
String HOST_IP = "127.0.0.1";

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

enum AppMode {
  SETUP,
  PAINT,
};

AppMode mode = AppMode.SETUP;
SetupState setup;

void setup() {
  size(900, 900);
  //frameRate(10);

  vive = new ViveConnection();
  vive.connect(HOST_IP, PORT_RX);

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
  mask.resize((int)(mask.width * 1.8), (int)(mask.height * 1.8));

  lines = new Vector<Tuple<PVector, PVector>>();

  plotter = new Plotter(Plotter.Tool.AIRBRUSH, 1000, 1000);
  setup = new SetupState(plotter);

  registerMethod("dispose", this);
}

void draw() {
  background(0);

  // Draw machine bounds
  Bounds screenBounds = setup.getScreenBounds(width, height);

  // Draw mask image
  image(mask, screenBounds.left, screenBounds.top);

  stroke(255);
  noFill();
  rect(screenBounds.left, screenBounds.top, screenBounds.width, screenBounds.height);

  if (mode == AppMode.SETUP) {
    noStroke();
    fill(0, 255, 0);
    PVector pos = setup.currentPosition();
    ellipse(pos.x, pos.y, 10, 10);
  } else if (mode == AppMode.PAINT) {
    paintOnMask();

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
}

void paintOnMask() {
  Bounds machineBounds = setup.getBounds();
  PVector viveLoc = getNormalizedLocation();

  if (viveLoc.x >= 0 && viveLoc.y >= 0 && viveLoc.x < width && viveLoc.y < height) {
    float x = viveLoc.x;
    float y = viveLoc.y;

    Bounds screenBounds = setup.getScreenBounds(width, height);

    float imageX = x * screenBounds.width;
    float imageY = y * screenBounds.height;

    fill(255, 0, 0);
    noStroke();
    ellipse(screenBounds.left + x * screenBounds.width, screenBounds.top + y * screenBounds.height, 8, 8);

    if (onMask((int)imageX, (int)imageY, mask)) {
      if (leftMask) {
        // Mouse has entered the mask
        PVector entryPt = lastPointOnMask((int)imageX, (int)imageY, lastMouseX, lastMouseY, mask);
        moveTo(entryPt.x, entryPt.y);
        plotter.spray(true);
        spraying = true;
        moveTo(imageX, imageY);
        lines.add(new Tuple<PVector, PVector>(new PVector(entryPt.x, entryPt.y), new PVector(imageX, imageY)));
        leftMask = false;
      }

      if (onMask(lastMouseX, lastMouseY, (int)imageX, (int)imageY, mask)) {
        moveTo(imageX, imageY);
        lines.add(new Tuple<PVector, PVector>(new PVector(lastMouseX, lastMouseY), new PVector(imageX, imageY)));
      }
    } else {
      if (leftMask == false) {
        // Last position was on the mask
        PVector exitPt = lastPointOnMask(lastMouseX, lastMouseY, (int)imageX, (int)imageY, mask);
        moveTo(exitPt.x, exitPt.y);
        plotter.spray(false);
        spraying = false;

        lines.add(new Tuple<PVector, PVector>(new PVector(lastMouseX, lastMouseY), new PVector(exitPt.x, exitPt.y)));

        leftMask = true;
      }
    }

    lastMouseX = (int)imageX;
    lastMouseY = (int)imageY;
  }
}

enum Tool {
  SOLID,
  DASH,
}
Tool activeTool = Tool.SOLID;

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

PVector getNormalizedLocation() {
  float minX = -40;//-81;
  float maxX = 90;

  float minY = -110;
  float maxY = 70;

  float minZ = -150;
  float maxZ = 68;

  float normX = map((float)vive.posX(), minX, maxX, 1, 0);
  float normZ = map((float)vive.posY(), minZ, maxZ, 0, 1);
  float normY = map((float)vive.posZ(), minY, maxY, 0, 1);

  //println(vive.posX(), vive.posZ());

  return new PVector(normX, normY, normZ);
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
  if (mode == AppMode.SETUP) {
    if (key == CODED) {
      switch (keyCode) {
        case UP:
          setup.jogUp();
          break;
        case LEFT:
          setup.jogLeft();
          break;
        case DOWN:
          setup.jogDown();
          break;
        case RIGHT:
          setup.jogRight();
          break;
      }
    } else {
      switch (key) {
        case 'w':
          setup.jogUp();
          break;
        case 'a':
          setup.jogLeft();
          break;
        case 's':
          setup.jogDown();
          break;
        case 'd':
          setup.jogRight();
          break;
        case ' ':
          setup.setLowerRight();
          break;
        case ENTER:
          mode = AppMode.PAINT;
          break;
      }
    }
  } else if (mode == AppMode.PAINT) {
  }

  if (key == 'h') {
    plotter.moveTo(0, 0, 0);
  } else if (key == 'p') {
    plotter.moveTo(200, 800);
  }
}
