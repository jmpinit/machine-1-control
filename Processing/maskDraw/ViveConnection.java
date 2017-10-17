import processing.core.PApplet;
import processing.core.PVector;
import hypermedia.net.UDP;

public class ViveConnection {
  private final float BOUNDS_MIN_X = -40;
  private final float BOUNDS_MAX_X = 90;

  private final float BOUNDS_MIN_Y = -110;
  private final float BOUNDS_MAX_Y = 70;

  private final float BOUNDS_MIN_Z = -150;
  private final float BOUNDS_MAX_Z = 68;

  private final float SCALE = 100;

  private UDP socket;
  private float x, y, z;
  private float rx, ry, rz;
  private boolean triggerPressed, padPressed, gripPressed;

  public void connect(String host, int port) {
    socket = new UDP(this, port, host);
    socket.listen(true);
  }

  public void receive(byte[] data, String HOST_IP, int PORT_RX) {
    String message = new String(data);
    String parts[] = message.split(";");

    long ticks = Long.parseLong(parts[0]);
    x = (float)Double.parseDouble(parts[1]) * SCALE;
    y = (float)Double.parseDouble(parts[2]) * SCALE;
    z = (float)Double.parseDouble(parts[3]) * SCALE;

    rx = (float)(Double.parseDouble(parts[4]) / 360.0f * 2 * Math.PI);
    ry = (float)(Double.parseDouble(parts[5]) / 360.0f * 2 * Math.PI);
    rz = (float)(Double.parseDouble(parts[6]) / 360.0f * 2 * Math.PI);

    triggerPressed = Integer.parseInt(parts[7]) > 0;
    padPressed = Integer.parseInt(parts[8]) > 0;
    gripPressed = Integer.parseInt(parts[9]) > 0;
    
    //System.out.println(x + ", " + y + ", " + z);
  }

  public float posX() { return x; }
  public float posY() { return y; }
  public float posZ() { return z; }

  public float rotationX() { return rx; }
  public float rotationY() { return ry; }
  public float rotationZ() { return rz; }

  public boolean triggerPressed() { return triggerPressed; }
  public boolean padPressed() { return padPressed; }
  public boolean gripPressed() { return gripPressed; }

  public PVector getNormalizedLocation() {
    // Swap Vive's Y and Z axes to make them match plotter coordinates
    float normX = PApplet.map((float)posX(), BOUNDS_MIN_X, BOUNDS_MAX_X, 1, 0);
    float normY = PApplet.map((float)posZ(), BOUNDS_MIN_Y, BOUNDS_MAX_Y, 0, 1);
    float normZ = PApplet.map((float)posY(), BOUNDS_MIN_Z, BOUNDS_MAX_Z, 0, 1);

    return new PVector(normX, normY, normZ);
  }
}