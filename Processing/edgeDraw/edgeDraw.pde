import java.util.*;
import java.awt.event.ActionListener;
import java.awt.event.ActionEvent;

import processing.serial.*;
import processing.awt.PSurfaceAWT;
import processing.video.*;

import blobDetection.*;

final boolean SIMULATE = false;

// Set these to the real-world dimensions of the machine's work space
final int MACHINE_WIDTH_IN_MM = 1000;
final int MACHINE_HEIGHT_IN_MM = 1000;

// Measured for Machine1
final float MM_PER_X_STEP = 0.04604f;
final float MM_PER_Y_STEP = 0.05048f;
final float MM_PER_Z_STEP = 0.0037f;

Vector<Tuple<PVector, PVector>> plottedLines;
Vector<LinearSegment> edgesLastFrame;

Plotter plotter;
Thread plotterThread;

int lastMouseX = 0;
int lastMouseY = 0;

boolean spraying = false;

boolean haveDrawn = false;
boolean leftMask = false;

Capture video;
PImage lastFrame, edgeFrame;

BlobDetection blobDetection;

void setup() {
  size(800, 800);

  if (SIMULATE) {
    plotter = new SimulatedPlotter(Plotter.Tool.AIRBRUSH, MM_PER_X_STEP, MM_PER_Y_STEP, MM_PER_Z_STEP, MACHINE_WIDTH_IN_MM, MACHINE_HEIGHT_IN_MM);
    println("Simulating...");
  } else {
    // Try finding serial port connection
    String[] serialPortPaths = Serial.list();
    List<String> possibleArduinoPortsList = ArduinoSelector.filterPorts(serialPortPaths);
    String[] possibleArduinoPorts = new String[possibleArduinoPortsList.size()];
    possibleArduinoPorts = possibleArduinoPortsList.toArray(possibleArduinoPorts);

    if (possibleArduinoPorts.length == 0) {
      plotter = new SimulatedPlotter(Plotter.Tool.AIRBRUSH, MM_PER_X_STEP, MM_PER_Y_STEP, MM_PER_Z_STEP, MACHINE_WIDTH_IN_MM, MACHINE_HEIGHT_IN_MM);
      println("No Arduinos found. Simulating only.");
    } else {
      plotter = new Plotter(Plotter.Tool.AIRBRUSH, MM_PER_X_STEP, MM_PER_Y_STEP, MM_PER_Z_STEP, MACHINE_WIDTH_IN_MM, MACHINE_HEIGHT_IN_MM);
      println("Connecting to robot's Arduino.");

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
        }
      });
    }
  }

  (new Thread(new Runnable() {
    public void run() {
      try {
        Thread.sleep(3000);
      } catch (InterruptedException e) {}

      plotterThread = new Thread(plotter);
      plotterThread.start();
    }
  })).start();

  plottedLines = new Vector<Tuple<PVector, PVector>>();

  PSurfaceAWT awtSurface = (PSurfaceAWT)surface;
  PSurfaceAWT.SmoothCanvas smoothCanvas = (PSurfaceAWT.SmoothCanvas)awtSurface.getNative();

  video = new Capture(this, width, height);
  video.start();
  
  blobDetection = new BlobDetection(video.width, video.height);
  blobDetection.setPosDiscrimination(false);
}

void draw() {
  background(0);

  if (video.available()) {
    video.read();
    video.loadPixels();
    lastFrame = video;
  }

  if (edgeFrame != null) {
    // This is the frame we are drawing the edges for
    image(edgeFrame, 0, 0);
  }

  if (lastFrame != null) {
    // Show a little preview in the lower right corner
    int threshold = (int)map(mouseY, 0, height, 0, 255);
    lastFrame.filter(THRESHOLD, threshold / 255.0f);
    for (int i = 0; i < 5; i++) {
      lastFrame.filter(ERODE);
    }
    image(lastFrame, 3 * width / 4, 3 * height / 4, width / 4, height / 4);

    edgesLastFrame = imageToEdges(lastFrame.copy(), threshold);

    strokeWeight(1);
    stroke(0, 0, 255);
    for (LinearSegment edge : edgesLastFrame) {
      PVector start = edge.getPoint(0);
      PVector end = edge.getPoint(1);

      // Scale the coordinates to fit in the preview box
      float sx1 = map(start.x, 0, width, 3 * width / 4, width);
      float sy1 = map(start.y, 0, height, 3 * height / 4, height);
      float sx2 = map(end.x, 0, width, 3 * width / 4, width);
      float sy2 = map(end.y, 0, height, 3 * height / 4, height);

      line(sx1, sy1, sx2, sy2);
    }
  }

  strokeWeight(1);
  stroke(255, 0, 0);
  synchronized (plottedLines) {
    for (Tuple<PVector, PVector> line : plottedLines) {
      PVector start = line.x;
      PVector end = line.y;

      line(start.x, start.y, end.x, end.y);
    }
  }

  List<Plotter.Waypoint> plotterPath = plotter.getPath();
  Plotter.Waypoint lastPlotterPt = plotterPath.get(0);

  synchronized (plotterPath) {
    for (Plotter.Waypoint point : plotterPath) {
      PVector lastPosition = lastPlotterPt.position;

      float y1 = lastPosition.x / plotter.getWidthInSteps() * width;
      float x1 = lastPosition.y / plotter.getHeightInSteps() * height;
      float y2 = point.position.x / plotter.getWidthInSteps() * width;
      float x2 = point.position.y / plotter.getHeightInSteps() * height;

      if (point.spraying) {
        strokeWeight(3);
        stroke(0, 255, 0);
      } else {
        strokeWeight(1);
        stroke(255, 0, 0, 64);
      }

      line(x1, y1, x2, y2);
      lastPlotterPt = point;
    }
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
      print("Arduino:", buffer);
    }

    buffer = "";
  }
}

// Maps screen coordinates into machine coordinates such that a point at the
// edge of the screen will be at the edge of the machine's canvas
void moveTo(float x, float y) {
  float plotterX = map(x, 0, width, 0, plotter.getWidthInMM());
  float plotterY = map(y, 0, height, 0, plotter.getHeightInMM());

  plotter.moveTo(plotterY, plotterX, 0);
}

void keyPressed() {
  if (key == ' ') {
    if (lastFrame == null) {
      return;
    }

    Vector<SegmentedSegment> allSegments = sortEdgesIntoSegments(edgesLastFrame);

    // Simplify the edges by removing very short segments
    // and resampling the curves with the same point density throughout
    Vector<LinearSegment> simplifiedEdges = new Vector<LinearSegment>();
    for (SegmentedSegment segment : allSegments) {
      if (segment.length() < 5) {
        continue;
      }

      float slice = 1.0f / (segment.length() / 10.0f);

      for (float i = slice; i < 1; i += slice) {
        simplifiedEdges.add(new LinearSegment(segment.getPoint(i - slice), segment.getPoint(i)));
      }
    }

    println("Will draw", simplifiedEdges.size(), " edges");

    for (LinearSegment edge : simplifiedEdges) {
      PVector start = edge.getPoint(0);
      PVector end = edge.getPoint(1);

      moveTo(start.x, start.y);
      plotter.spray(true);
      moveTo(end.x, end.y);
      plotter.spray(false);
    }
  }
}

Vector<LinearSegment> imageToEdges(PImage image, int threshold) {
  blobDetection.setThreshold(map(threshold, 0, 255, 0, 1));
  blobDetection.computeBlobs(image.pixels);

  // Get the edges in whatever order the blob detection algorithm gives them
  
  Vector<LinearSegment> edges = new Vector<LinearSegment>();

  for (int n = 0; n < blobDetection.getBlobNb(); n++) {
    Blob blob = blobDetection.getBlob(n);
    
    if (blob != null) {
      for (int m = 0; m < blob.getEdgeNb(); m++) {
        EdgeVertex vertA = blob.getEdgeVertexA(m);
        EdgeVertex vertB = blob.getEdgeVertexB(m);
        
        if (vertA != null && vertB != null) {
          edges.add(new LinearSegment(vertA.x * image.width, vertA.y * image.height, vertB.x * image.width, vertB.y * image.height));
        }
      }
    }
  }

  return edges;
}

Vector<SegmentedSegment> sortEdgesIntoSegments(Vector<LinearSegment> edges) {
  // Sort the edges so they line up end to end

  Vector<SegmentedSegment> sortedEdges = new Vector<SegmentedSegment>();

  while (edges.size() != 0) {
    SegmentedSegment segmentInProgress = new SegmentedSegment();

    LinearSegment first = edges.get(0);
    edges.remove(first);
    segmentInProgress.add(first);

    for (Iterator<LinearSegment> edgeIter = edges.iterator(); edgeIter.hasNext();) {
      LinearSegment second = edgeIter.next();

      if (SegmentedSegment.near(first.getPoint(1), second.getPoint(0), 5)) {
        edgeIter.remove();
        segmentInProgress.add(new LinearSegment(first.getPoint(1), second.getPoint(1)));
        first = second;
      }
    }

    SegmentedSegment finishedSegment = segmentInProgress;
    sortedEdges.add(finishedSegment);
  }

  return sortedEdges;
}
