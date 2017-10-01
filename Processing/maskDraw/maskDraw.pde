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

int lastX = 0;
int lastY = 0;
boolean haveDrawn = false;
boolean leftMask = false;

void setup() {
  size(800, 800);
  frameRate(10);

  final PApplet that = this;
  ArduinoSelector arduinoSelector = new ArduinoSelector(Serial.list(), new ArduinoSelector.SelectionListener() {
    public void selected(String port) {
      final Serial arduinoPort = new Serial(that, port, 57600);

      plotter.addMessageListener(new Plotter.MessageListener() {
        public void onMessage(int[] message) {
          println("Hey, plotter has a message:", (char)message[0], message[1], message[2], message[3]);
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

void serialEvent(Serial port) {
  int c = port.read();
  plotter.receiveMessage(c);
  print((char)c);
}

void dispose() {
  plotter.moveTo(0, 0);
  plotter.stop();

  try {
    plotterThread.join();
  } catch (InterruptedException e) {}

  println("dispose called");
}

void draw() {
  background(0);
  image(mask, 0, 0);

  if (mouseX >= 0 && mouseY >= 0 && mouseX < width && mouseY < height) {
    if (onMask(mouseX, mouseY, mask)) {
      int x = mouseX;
      int y = mouseY;

      if (leftMask) {
        PVector last = lastPointOnMask(mouseX, mouseY, lastX, lastY, mask);
        lastX = (int)last.x;
        lastY = (int)last.y;
        leftMask = false;
      }

      if (onMask(lastX, lastY, x, y, mask)) {
        plotter.moveTo(map(lastX, 0, width, 0, plotter.getWidthInMM()), map(lastY, 0, height, 0, plotter.getHeightInMM()));
        plotter.spray(true);
        plotter.moveTo(map(x, 0, width, 0, plotter.getWidthInMM()), map(y, 0, height, 0, plotter.getHeightInMM()));
        plotter.spray(false);
      }

      lastX = x;
      lastY = y;
    } else {
      if (leftMask == false) {
        // Last position was on the mask
        PVector last = lastPointOnMask(lastX, lastY, mouseX, mouseY, mask);
        plotter.moveTo(map(lastX, 0, width, 0, plotter.getWidthInMM()), map(lastY, 0, height, 0, plotter.getHeightInMM()));
        plotter.spray(true);
        plotter.moveTo(map(last.x, 0, width, 0, plotter.getWidthInMM()), map(last.y, 0, height, 0, plotter.getHeightInMM()));
        plotter.spray(false);

        leftMask = true;
      }
    }
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
    plotter.moveTo(0, 0);
  } else if (key == 'p') {
    plotter.moveTo(200, 800);
  }
}
