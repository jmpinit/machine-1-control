import java.util.*;
import java.awt.event.ActionListener;
import java.awt.event.ActionEvent;

import processing.serial.*;
import processing.awt.PSurfaceAWT;

import hypermedia.net.*;

Vector<Tuple<PVector, PVector>> plottedLines;

Plotter plotter;
Thread plotterThread;

final LayerFrame layerFrame = new LayerFrame();
PImage combinedMask;
Vector<Tuple<String, PImage>> namedImages;

int lastMouseX = 0;
int lastMouseY = 0;

boolean spraying = false;

boolean haveDrawn = false;
boolean leftMask = false;

void setup() {
  size(900, 900);

  namedImages = new Vector<Tuple<String, PImage>>();

  String[] serialPortPaths = Serial.list();
  List<String> possibleArduinoPortsList = ArduinoSelector.filterPorts(serialPortPaths);
  String[] possibleArduinoPorts = new String[possibleArduinoPortsList.size()];
  possibleArduinoPorts = possibleArduinoPortsList.toArray(possibleArduinoPorts);

  if (possibleArduinoPorts.length == 0) {
    println("No Arduinos found. Simulating only.");

    plotter = new SimulatedPlotter(Plotter.Tool.AIRBRUSH, 1000, 1000);

    (new Thread(new Runnable() {
      public void run() {
        try {
          Thread.sleep(3000);
        } catch (InterruptedException e) {}

        plotterThread = new Thread(plotter);
        plotterThread.start();
      }
    })).start();
  } else {
    plotter = new Plotter(Plotter.Tool.AIRBRUSH, 1000, 1000);

    final PApplet that = this;
    ArduinoSelector arduinoSelector = new ArduinoSelector(possibleArduinoPorts, new ArduinoSelector.SelectionListener() {
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
  }

  plottedLines = new Vector<Tuple<PVector, PVector>>();

  registerMethod("dispose", this);

  PSurfaceAWT awtSurface = (PSurfaceAWT)surface;
  PSurfaceAWT.SmoothCanvas smoothCanvas = (PSurfaceAWT.SmoothCanvas)awtSurface.getNative();

  MaskDrawGUI gui = new MaskDrawGUI(smoothCanvas.getFrame());
  gui.addListener(new MaskDrawGUI.Listener() {
    public void imageImported(String name, PImage image) {
      image.loadPixels();

      // Threshold image
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          int c = color((brightness(image.get(x, y)) < 127) ? 0 : 255);
          image.set(x, y, c);
        }
      }

      image.updatePixels();

      namedImages.add(new Tuple<String, PImage>(name, image));
      layerFrame.addLayer(name);

      combinedMask = recalculateMask();
      println("Added image \"" + name + "\"");
    }
  });

  layerFrame.addListener(new LayerFrame.Listener () {
    public void layerAdded(String name) {}

    public void layerEnabled(String name) {
      combinedMask = recalculateMask();
      println(name, "enabled");
    }

    public void layerDisabled(String name) {
      combinedMask = recalculateMask();
      println(name, "disabled");
    }
  });

  combinedMask = recalculateMask();
}

void draw() {
  background(0);

  if (combinedMask != null) {
    image(combinedMask, 0, 0);
  }

  paintOnMask();

  stroke(255);
  synchronized (plottedLines) {
    for (Tuple<PVector, PVector> line : plottedLines) {
      PVector start = line.x;
      PVector end = line.y;

      stroke(255, 0, 0);
      line(start.x, start.y, end.x, end.y);
    }
  }
}

Bounds imagesBounds(Vector<PImage> images) {
  float maxWidth = 0;
  float maxHeight = 0;

  for (PImage image : images) {
    if (image.width > maxWidth) {
      maxWidth = image.width;
    }

    if (image.height > maxHeight) {
      maxHeight = image.height;
    }
  }

  return new Bounds(width, height);
}

PImage recalculateMask() {
  if (namedImages.size() == 0) {
    return null;
  }

  Vector<PImage> images = new Vector<PImage>();
  for (Tuple<String, PImage> namedImage : namedImages) {
    images.add(namedImage.y);
  }

  Bounds bounds = imagesBounds(images);
  PGraphics mask = createGraphics((int)bounds.width, (int)bounds.height);

  mask.beginDraw();

  // OR all the images together onto one mask
  for (Tuple<String, PImage> namedImage : namedImages) {
    String name = namedImage.x;
    PImage image = namedImage.y;

    if (layerFrame.isEnabled(name)) {
      mask.image(image, 0, 0);
    }
  }

  mask.endDraw();

  return mask.get();
}

void paintOnMask() {
  if (combinedMask == null) {
    return;
  }

  PVector pointer = new PVector(mouseX, mouseY);

  if (pointer.x >= 0 && pointer.y >= 0 && pointer.x < width && pointer.y < height) {
    float imageX = pointer.x;
    float imageY = pointer.y;

    if (onMask((int)imageX, (int)imageY, combinedMask)) {
      if (leftMask) {
        // Mouse has entered the mask
        PVector entryPt = lastPointOnMask((int)imageX, (int)imageY, lastMouseX, lastMouseY, combinedMask);
        moveTo(entryPt.x, entryPt.y);
        plotter.spray(true);
        spraying = true;
        moveTo(imageX, imageY);
        plottedLines.add(new Tuple<PVector, PVector>(new PVector(entryPt.x, entryPt.y), new PVector(imageX, imageY)));
        leftMask = false;
      }

      if (onMask(lastMouseX, lastMouseY, (int)imageX, (int)imageY, combinedMask)) {
        moveTo(imageX, imageY);
        plottedLines.add(new Tuple<PVector, PVector>(new PVector(lastMouseX, lastMouseY), new PVector(imageX, imageY)));
      }
    } else {
      if (leftMask == false) {
        // Last position was on the mask
        PVector exitPt = lastPointOnMask(lastMouseX, lastMouseY, (int)imageX, (int)imageY, combinedMask);
        moveTo(exitPt.x, exitPt.y);
        plotter.spray(false);
        spraying = false;

        plottedLines.add(new Tuple<PVector, PVector>(new PVector(lastMouseX, lastMouseY), new PVector(exitPt.x, exitPt.y)));

        leftMask = true;
      }
    }

    lastMouseX = (int)imageX;
    lastMouseY = (int)imageY;
  }
}

void moveTo(float x, float y) {
  float plotterX = map(x, 0, width, 0, plotter.getWidthInMM());
  float plotterY = map(y, 0, height, 0, plotter.getHeightInMM());

  plotter.moveTo(plotterX, plotterY, 0);
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
  // delta of exact value and rounded value of the dependent variable
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